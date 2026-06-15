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

  Future<List<StampCardModel>> loadStampCards() async {
    final snapshot = await firestoreService
        .collection(FirebasePaths.merchantStampCards(merchantId))
        .get();
    final cards = snapshot.docs
        .map((doc) => StampCardModel.fromMap({'id': doc.id, ...doc.data()}))
        .toList();
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
        .get();
    final items = snapshot.docs
        .map((doc) => MerchantItemData.fromMap({'id': doc.id, ...doc.data()}))
        .where((item) => !item.isArchived && !item.isPrivate)
        .toList();
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }

  Future<String> saveCard(StampCardModel card) async {
    final stampCardId = card.id.isNotEmpty
        ? card.id
        : firestoreService
            .collection(FirebasePaths.merchantStampCards(merchantId))
            .doc()
            .id;
    final isNew = card.id.isEmpty;
    final prepared = card.copyWith(
      id: stampCardId,
      merchantId: merchantId,
      isActive: card.status == StampCardStatus.active,
      isArchived: card.status == StampCardStatus.archived,
    );
    final data = prepared.toMap()
      ..['updatedAt'] = FieldValue.serverTimestamp();
    if (isNew) data['createdAt'] = FieldValue.serverTimestamp();

    await firestoreService.setDocument(
      FirebasePaths.merchantStampCard(merchantId, stampCardId),
      data,
    );
    return stampCardId;
  }

  Future<String> publishCard(StampCardModel card) async {
    final stampCardId = card.id.isNotEmpty
        ? card.id
        : firestoreService
            .collection(FirebasePaths.merchantStampCards(merchantId))
            .doc()
            .id;
    final isNew = card.id.isEmpty;
    final prepared = card.copyWith(
      id: stampCardId,
      merchantId: merchantId,
      status: StampCardStatus.active,
      isActive: true,
      isArchived: false,
    );
    final cardData = prepared.toMap()
      ..['updatedAt'] = FieldValue.serverTimestamp()
      ..['publishedAt'] = FieldValue.serverTimestamp()
      ..['activatedAt'] = FieldValue.serverTimestamp();
    if (isNew) cardData['createdAt'] = FieldValue.serverTimestamp();

    await firestoreService.setDocument(
      FirebasePaths.merchantStampCard(merchantId, stampCardId),
      cardData,
      merge: true,
    );
    return stampCardId;
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

  Future<void> deleteDraftCard(String stampCardId) {
    return firestoreService
        .document(FirebasePaths.merchantStampCard(merchantId, stampCardId))
        .delete();
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
