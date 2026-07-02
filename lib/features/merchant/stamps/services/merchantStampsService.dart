import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firebasePaths.dart';
import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../catalog/models/merchantItemData.dart';
import '../models/stampCardModel.dart';

class MerchantStampsService {
  const MerchantStampsService({
    required this.authService,
    required this.firestoreService,
  });

  final AuthService authService;
  final FirestoreService firestoreService;

  String get merchantId {
    final uid = authService.currentUser?.uid;
    if (uid == null) {
      throw StateError('auth.error.signInAgain');
    }
    return uid;
  }

  /// Obergrenze für Listen-Reads – schützt vor unbeschränkten Collection-Reads,
  /// falls ein Merchant sehr viele Karten/Artikel anlegt.
  static const int _maxCards = 100;
  static const int _maxItems = 200;

  Future<List<StampCardModel>> loadStampCards() async {
    final snapshot = await firestoreService
        .collection(FirebasePaths.merchantStampCards(merchantId))
        .orderBy('updatedAt', descending: true)
        .limit(_maxCards)
        .get();
    final cards = snapshot.docs
        .map((doc) => StampCardModel.fromMap({'id': doc.id, ...doc.data()}))
        .toList();
    // Statusgruppierung clientseitig (orderBy bestimmt nur die Vorsortierung).
    cards.sort(_sortCards);
    return cards;
  }

  Future<StampCardModel?> loadStampCard(String stampCardId) async {
    final data = await firestoreService.readDocument(
      FirebasePaths.merchantStampCard(merchantId, stampCardId),
    );
    if (data == null) return null;
    return StampCardModel.fromMap({'id': stampCardId, ...data});
  }

  Future<List<MerchantItemData>> loadItems() async {
    final snapshot = await firestoreService
        .collection(FirebasePaths.merchantItems(merchantId))
        .limit(_maxItems)
        .get();
    final items = snapshot.docs
        .map((doc) => MerchantItemData.fromMap({'id': doc.id, ...doc.data()}))
        .where((item) => !item.isArchived && !item.isPrivate)
        .toList();
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }

  /// Löst die Dokument-ID auf (vorhandene ID oder frisch generierte) und meldet,
  /// ob es sich um einen Neuanlage-Pfad handelt. Gemeinsam von saveCard/publishCard.
  ({String id, bool isNew}) _resolveId(StampCardModel card) {
    if (card.id.isNotEmpty) return (id: card.id, isNew: false);
    final id = firestoreService
        .collection(FirebasePaths.merchantStampCards(merchantId))
        .doc()
        .id;
    return (id: id, isNew: true);
  }

  Future<String> saveCard(StampCardModel card) async {
    final resolved = _resolveId(card);
    final prepared = card.copyWith(
      id: resolved.id,
      merchantId: merchantId,
      isActive: card.status == StampCardStatus.active,
      isArchived: card.status == StampCardStatus.archived,
    );
    final data = prepared.toMap()
      ..['updatedAt'] = FieldValue.serverTimestamp();
    if (resolved.isNew) data['createdAt'] = FieldValue.serverTimestamp();

    await firestoreService.setDocument(
      FirebasePaths.merchantStampCard(merchantId, resolved.id),
      data,
    );
    return resolved.id;
  }

  Future<String> publishCard(StampCardModel card) async {
    final resolved = _resolveId(card);
    final prepared = card.copyWith(
      id: resolved.id,
      merchantId: merchantId,
      status: StampCardStatus.active,
      isActive: true,
      isArchived: false,
    );
    final cardData = prepared.toMap()
      ..['updatedAt'] = FieldValue.serverTimestamp()
      ..['activatedAt'] = FieldValue.serverTimestamp();
    // Ursprünglichen Veröffentlichungszeitpunkt erhalten: publishedAt nur bei der
    // ersten Veröffentlichung setzen (Neuanlage oder noch nie veröffentlicht).
    if (resolved.isNew || card.publishedAt == null) {
      cardData['publishedAt'] = FieldValue.serverTimestamp();
    }
    if (resolved.isNew) cardData['createdAt'] = FieldValue.serverTimestamp();

    // Full-Replace (kein merge) – konsistent mit saveCard; toMap() schreibt das
    // vollständige Dokument, dadurch keine veralteten Geister-Felder.
    await firestoreService.setDocument(
      FirebasePaths.merchantStampCard(merchantId, resolved.id),
      cardData,
    );
    return resolved.id;
  }

  Future<void> pauseCard(String stampCardId) {
    return firestoreService.setDocument(
      FirebasePaths.merchantStampCard(merchantId, stampCardId),
      {
        'status': StampCardStatus.paused,
        'isActive': false,
        'pausedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> archiveCard(String stampCardId) {
    return firestoreService.setDocument(
      FirebasePaths.merchantStampCard(merchantId, stampCardId),
      {
        'status': StampCardStatus.archived,
        'isActive': false,
        'isArchived': true,
        'archivedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  /// Persists the prepared share-link token on the card (merge). The merchant
  /// owns the card doc, so this is a plain client write — no Cloud Function.
  Future<void> setStaticToken(String stampCardId, String token) {
    return firestoreService.setDocument(
      FirebasePaths.merchantStampCard(merchantId, stampCardId),
      {'staticToken': token, 'updatedAt': FieldValue.serverTimestamp()},
      merge: true,
    );
  }

  /// Sets both merchant-facing limits in one targeted merge write: the
  /// cooldown between two stamps for the same customer, and the optional cap
  /// on how many distinct customers may ever hold the card. Never a full
  /// replace, so `distributedCount`, the stick binding and every other field
  /// stay untouched — `maxDistribution: null` clears the cap (unlimited).
  Future<void> setLimits(
    String stampCardId, {
    required Map<String, dynamic> claimLimits,
    required int? maxDistribution,
  }) {
    return firestoreService.setDocument(
      FirebasePaths.merchantStampCard(merchantId, stampCardId),
      {
        'claimLimits': claimLimits,
        'maxDistribution': maxDistribution,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      merge: true,
    );
  }

  Future<void> deleteDraftCard(String stampCardId) {
    return firestoreService
        .document(FirebasePaths.merchantStampCard(merchantId, stampCardId))
        .delete();
  }

  /// Clones an existing card as a fresh DRAFT (new id, "(Kopie)" title, no stick
  /// binding, reset timestamps) so a campaign/season variant is one tap away.
  /// Draft status means the clone does not count against the active cap until
  /// the merchant publishes it.
  Future<String> duplicateCard(StampCardModel source) {
    final copy = source.copyWith(
      id: '',
      title: '${source.title} (Kopie)',
      status: StampCardStatus.draft,
      isActive: false,
      isArchived: false,
      boundStickId: '',
      createdAt: null,
      updatedAt: null,
      publishedAt: null,
      activatedAt: null,
      pausedAt: null,
      archivedAt: null,
    );
    return saveCard(copy);
  }

  int _sortCards(StampCardModel a, StampCardModel b) {
    final statusOrder = _statusRank(a.status).compareTo(_statusRank(b.status));
    if (statusOrder != 0) return statusOrder;
    return (b.updatedAt ?? b.createdAt ?? DateTime(0))
        .compareTo(a.updatedAt ?? a.createdAt ?? DateTime(0));
  }

  int _statusRank(String status) {
    return switch (status) {
      StampCardStatus.active => 0,
      StampCardStatus.draft => 1,
      StampCardStatus.paused => 2,
      StampCardStatus.archived => 3,
      _ => 4,
    };
  }
}
