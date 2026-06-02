import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firebasePaths.dart';
import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../models/couponModel.dart';

class MerchantCouponsService {
  const MerchantCouponsService({
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

  Future<List<CouponModel>> loadCoupons() async {
    final snapshot = await firestoreService
        .collection(FirebasePaths.merchantCoupons(merchantId))
        .get();
    final coupons = snapshot.docs
        .map((doc) => CouponModel.fromMap({'id': doc.id, ...doc.data()}))
        .toList();
    coupons.sort(_sortCoupons);
    return coupons;
  }

  Future<CouponModel?> loadCoupon(String couponId) async {
    final data = await firestoreService.readDocument(
      FirebasePaths.merchantCoupon(merchantId, couponId),
    );
    if (data == null) return null;
    return CouponModel.fromMap({'id': couponId, ...data});
  }

  Future<String> saveCoupon(CouponModel coupon) async {
    final couponId = coupon.id.isNotEmpty
        ? coupon.id
        : firestoreService
            .collection(FirebasePaths.merchantCoupons(merchantId))
            .doc()
            .id;
    final isNew = coupon.id.isEmpty;
    final prepared = coupon.copyWith(
      id: couponId,
      merchantId: merchantId,
      isActive: coupon.status == CouponStatus.active,
      isArchived: coupon.status == CouponStatus.archived,
      creditCostPerWeek: 1,
    );
    final data = prepared.toMap()
      ..['updatedAt'] = FieldValue.serverTimestamp()
      ..['creditCostPerWeek'] = 1;
    if (isNew) data['createdAt'] = FieldValue.serverTimestamp();
    await firestoreService.setDocument(
      FirebasePaths.merchantCoupon(merchantId, couponId),
      data,
    );
    return couponId;
  }

  Future<String> publishCoupon(CouponModel coupon) async {
    final couponId = coupon.id.isNotEmpty
        ? coupon.id
        : firestoreService
            .collection(FirebasePaths.merchantCoupons(merchantId))
            .doc()
            .id;
    final existing = coupon.id.isEmpty ? null : await loadCoupon(couponId);
    final wasAlreadyActive =
        existing?.status == CouponStatus.active && existing?.isActive == true;
    final prepared = coupon.copyWith(
      id: couponId,
      merchantId: merchantId,
      status: CouponStatus.active,
      isActive: true,
      isArchived: false,
      creditCostPerWeek: 1,
    );
    final data = prepared.toMap()
      ..['updatedAt'] = FieldValue.serverTimestamp()
      ..['publishedAt'] = FieldValue.serverTimestamp()
      ..['activatedAt'] = FieldValue.serverTimestamp();
    if (coupon.id.isEmpty) data['createdAt'] = FieldValue.serverTimestamp();

    final batch = firestoreService.batch();
    batch.set(
      firestoreService.document(
        FirebasePaths.merchantCoupon(merchantId, couponId),
      ),
      data,
      SetOptions(merge: true),
    );
    if (!wasAlreadyActive) {
      final eventId = firestoreService.collection(FirebasePaths.billingEvents).doc().id;
      final periodStart = DateTime.now();
      final periodEnd = periodStart.add(const Duration(days: 7));
      batch.set(
        firestoreService.document(FirebasePaths.billingEvent(eventId)),
        {
          'eventId': eventId,
          'merchantId': merchantId,
          'featureType': 'coupons',
          'actionType': 'couponActivated',
          'targetId': couponId,
          'creditAmount': 1,
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
    return couponId;
  }

  Future<void> pauseCoupon(String couponId) {
    return firestoreService.setDocument(
      FirebasePaths.merchantCoupon(merchantId, couponId),
      {
        'status': CouponStatus.paused,
        'isActive': false,
        'pausedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> archiveCoupon(String couponId) {
    return firestoreService.setDocument(
      FirebasePaths.merchantCoupon(merchantId, couponId),
      {
        'status': CouponStatus.archived,
        'isActive': false,
        'isArchived': true,
        'archivedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> deleteDraftCoupon(String couponId) {
    return firestoreService
        .document(FirebasePaths.merchantCoupon(merchantId, couponId))
        .delete();
  }

  List<String> generateCodes({
    required String prefix,
    required int count,
    List<String> existing = const [],
  }) {
    var cleanPrefix = prefix
        .trim()
        .toUpperCase()
        .replaceAll(RegExp('[^A-Z0-9]'), '');
    if (cleanPrefix.isEmpty) cleanPrefix = 'LK';
    if (cleanPrefix.length < 2) cleanPrefix = cleanPrefix.padRight(2, 'L');
    if (cleanPrefix.length > 6) cleanPrefix = cleanPrefix.substring(0, 6);
    final random = Random.secure();
    final targetCount = count.clamp(1, 100).toInt();
    final codes = {...existing.where((code) => code.trim().isNotEmpty)};
    while (codes.length < targetCount) {
      final number = List.generate(5, (_) => random.nextInt(10)).join();
      codes.add('$cleanPrefix-$number');
    }
    return codes.take(targetCount).toList();
  }

  int _sortCoupons(CouponModel a, CouponModel b) {
    final status = _statusRank(a.status).compareTo(_statusRank(b.status));
    if (status != 0) return status;
    return (b.updatedAt ?? b.createdAt ?? DateTime(0))
        .compareTo(a.updatedAt ?? a.createdAt ?? DateTime(0));
  }

  int _statusRank(String status) {
    return switch (status) {
      CouponStatus.active => 0,
      CouponStatus.draft => 1,
      CouponStatus.paused => 2,
      CouponStatus.archived => 3,
      _ => 4,
    };
  }
}
