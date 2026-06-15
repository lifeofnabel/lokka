import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firebasePaths.dart';
import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../catalog/models/merchantItemData.dart';
import '../models/pointsSystemModel.dart';

class MerchantPointsService {
  const MerchantPointsService({
    required this.authService,
    required this.firestoreService,
  });

  final AuthService authService;
  final FirestoreService firestoreService;

  String get merchantId {
    final uid = authService.currentUser?.uid;
    if (uid == null) throw StateError('auth.error.signInAgain');
    return uid;
  }

  Future<List<PointsSystemModel>> loadSystems() async {
    final snapshot = await firestoreService
        .collection(FirebasePaths.merchantPointsSystems(merchantId))
        .get();
    final systems = snapshot.docs
        .map((doc) => PointsSystemModel.fromMap({'id': doc.id, ...doc.data()}))
        .toList();
    systems.sort((a, b) => _sortStatus(a.status).compareTo(_sortStatus(b.status)));
    return systems;
  }

  Future<PointsSystemModel?> loadSystem(String systemId) async {
    final data = await firestoreService.readDocument(
      FirebasePaths.merchantPointsSystem(merchantId, systemId),
    );
    if (data == null) return null;
    return PointsSystemModel.fromMap({'id': systemId, ...data});
  }

  Future<List<PointsRewardModel>> loadRewards() async {
    final snapshot = await firestoreService
        .collection(FirebasePaths.merchantPointsRewards(merchantId))
        .get();
    final rewards = snapshot.docs
        .map((doc) => PointsRewardModel.fromMap({'id': doc.id, ...doc.data()}))
        .toList();
    rewards.sort((a, b) {
      final status = _sortStatus(a.status).compareTo(_sortStatus(b.status));
      if (status != 0) return status;
      return a.requiredPoints.compareTo(b.requiredPoints);
    });
    return rewards;
  }

  Future<PointsRewardModel?> loadReward(String rewardId) async {
    final data = await firestoreService.readDocument(
      FirebasePaths.merchantPointsReward(merchantId, rewardId),
    );
    if (data == null) return null;
    return PointsRewardModel.fromMap({'id': rewardId, ...data});
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

  Future<String> saveSystem(PointsSystemModel system) async {
    final systemId = system.id.isNotEmpty
        ? system.id
        : firestoreService
            .collection(FirebasePaths.merchantPointsSystems(merchantId))
            .doc()
            .id;
    final isNew = system.id.isEmpty;
    final prepared = system.copyWith(
      id: systemId,
      merchantId: merchantId,
      isActive: system.status == PointsStatus.active,
      isArchived: system.status == PointsStatus.archived,
      existingParticipantsCanContinue: true,
    );
    final data = prepared.toMap()..['updatedAt'] = FieldValue.serverTimestamp();
    if (isNew) data['createdAt'] = FieldValue.serverTimestamp();
    await firestoreService.setDocument(
      FirebasePaths.merchantPointsSystem(merchantId, systemId),
      data,
    );
    return systemId;
  }

  Future<String> publishSystem(PointsSystemModel system) async {
    final systemId = system.id.isNotEmpty
        ? system.id
        : firestoreService
            .collection(FirebasePaths.merchantPointsSystems(merchantId))
            .doc()
            .id;
    final currentSystems = await loadSystems();
    final batch = firestoreService.batch();

    for (final old in currentSystems) {
      if (old.id == systemId || !old.isLive) continue;
      batch.set(
        firestoreService.document(
          FirebasePaths.merchantPointsSystem(merchantId, old.id),
        ),
        {
          'status': PointsStatus.paused,
          'isActive': false,
          'existingParticipantsCanContinue': true,
          'pausedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    final prepared = system.copyWith(
      id: systemId,
      merchantId: merchantId,
      status: PointsStatus.active,
      isActive: true,
      isArchived: false,
      existingParticipantsCanContinue: true,
    );
    final data = prepared.toMap()
      ..['publishedAt'] = FieldValue.serverTimestamp()
      ..['activatedAt'] = FieldValue.serverTimestamp()
      ..['updatedAt'] = FieldValue.serverTimestamp();
    if (system.id.isEmpty) data['createdAt'] = FieldValue.serverTimestamp();
    batch.set(
      firestoreService.document(
        FirebasePaths.merchantPointsSystem(merchantId, systemId),
      ),
      data,
      SetOptions(merge: true),
    );

    await batch.commit();
    return systemId;
  }

  Future<String> saveReward(PointsRewardModel reward) async {
    final rewardId = reward.id.isNotEmpty
        ? reward.id
        : firestoreService
            .collection(FirebasePaths.merchantPointsRewards(merchantId))
            .doc()
            .id;
    final isNew = reward.id.isEmpty;
    final prepared = reward.copyWith(
      id: rewardId,
      merchantId: merchantId,
      isActive: reward.status == PointsStatus.active,
      isArchived: reward.status == PointsStatus.archived,
    );
    final data = prepared.toMap()..['updatedAt'] = FieldValue.serverTimestamp();
    if (isNew) data['createdAt'] = FieldValue.serverTimestamp();
    await firestoreService.setDocument(
      FirebasePaths.merchantPointsReward(merchantId, rewardId),
      data,
    );
    return rewardId;
  }

  Future<String> publishReward(PointsRewardModel reward) async {
    final rewardId = reward.id.isNotEmpty
        ? reward.id
        : firestoreService
            .collection(FirebasePaths.merchantPointsRewards(merchantId))
            .doc()
            .id;
    final prepared = reward.copyWith(
      id: rewardId,
      merchantId: merchantId,
      status: PointsStatus.active,
      isActive: true,
      isArchived: false,
    );
    final batch = firestoreService.batch();
    final data = prepared.toMap()
      ..['publishedAt'] = FieldValue.serverTimestamp()
      ..['activatedAt'] = FieldValue.serverTimestamp()
      ..['updatedAt'] = FieldValue.serverTimestamp();
    if (reward.id.isEmpty) data['createdAt'] = FieldValue.serverTimestamp();
    batch.set(
      firestoreService.document(
        FirebasePaths.merchantPointsReward(merchantId, rewardId),
      ),
      data,
      SetOptions(merge: true),
    );
    await batch.commit();
    return rewardId;
  }

  Future<void> pauseSystem(String systemId) {
    return firestoreService.setDocument(
      FirebasePaths.merchantPointsSystem(merchantId, systemId),
      {
        'status': PointsStatus.paused,
        'isActive': false,
        'existingParticipantsCanContinue': true,
        'pausedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> archiveSystem(String systemId) {
    return firestoreService.setDocument(
      FirebasePaths.merchantPointsSystem(merchantId, systemId),
      {
        'status': PointsStatus.archived,
        'isActive': false,
        'isArchived': true,
        'archivedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> deleteDraftSystem(String systemId) {
    return firestoreService
        .document(FirebasePaths.merchantPointsSystem(merchantId, systemId))
        .delete();
  }

  Future<void> pauseReward(String rewardId) {
    return firestoreService.setDocument(
      FirebasePaths.merchantPointsReward(merchantId, rewardId),
      {
        'status': PointsStatus.paused,
        'isActive': false,
        'pausedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> archiveReward(String rewardId) {
    return firestoreService.setDocument(
      FirebasePaths.merchantPointsReward(merchantId, rewardId),
      {
        'status': PointsStatus.archived,
        'isActive': false,
        'isArchived': true,
        'archivedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> deleteDraftReward(String rewardId) {
    return firestoreService
        .document(FirebasePaths.merchantPointsReward(merchantId, rewardId))
        .delete();
  }

  int _sortStatus(String status) {
    return switch (status) {
      PointsStatus.active => 0,
      PointsStatus.draft => 1,
      PointsStatus.paused => 2,
      PointsStatus.archived => 3,
      _ => 4,
    };
  }
}
