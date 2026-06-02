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
      ..['updatedAt'] = FieldValue.serverTimestamp()
      ..['creditCostPerWeek'] = 2;
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
    var wasAlreadyActive = false;
    if (card.id.isNotEmpty) {
      final existing = await loadStampCard(stampCardId);
      wasAlreadyActive = existing?.status == StampCardStatus.active && existing?.isActive == true;
    }
    final prepared = card.copyWith(
      id: stampCardId,
      merchantId: merchantId,
      status: StampCardStatus.active,
      isActive: true,
      isArchived: false,
      creditCostPerWeek: 2,
    );
    final cardData = prepared.toMap()
      ..['updatedAt'] = FieldValue.serverTimestamp()
      ..['publishedAt'] = FieldValue.serverTimestamp()
      ..['activatedAt'] = FieldValue.serverTimestamp();
    if (isNew) cardData['createdAt'] = FieldValue.serverTimestamp();

    final batch = firestoreService.batch();
    batch.set(
      firestoreService.document(
        FirebasePaths.merchantStampCard(merchantId, stampCardId),
      ),
      cardData,
      SetOptions(merge: true),
    );

    if (!wasAlreadyActive) {
      final eventId = firestoreService
          .collection(FirebasePaths.billingEvents)
          .doc()
          .id;
      final periodStart = DateTime.now();
      final periodEnd = periodStart.add(const Duration(days: 7));
      batch.set(
        firestoreService.document(FirebasePaths.billingEvent(eventId)),
        {
          'eventId': eventId,
          'merchantId': merchantId,
          'featureType': 'stamps',
          'actionType': 'stampCardActivated',
          'targetId': stampCardId,
          'creditAmount': 2,
          'billingType': 'weekly',
          'status': 'committed',
          'periodStart': Timestamp.fromDate(periodStart),
          'periodEnd': Timestamp.fromDate(periodEnd),
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
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
