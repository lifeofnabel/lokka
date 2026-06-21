import 'package:flutter/foundation.dart';

import '../../../../core/services/uploadService.dart';
import '../models/couponModel.dart';
import '../services/merchantCouponsService.dart';

class MerchantCouponsProvider extends ChangeNotifier {
  MerchantCouponsProvider({
    required this.service,
    required this.uploadService,
  });

  final MerchantCouponsService service;
  final UploadService uploadService;

  bool isLoading = true;
  bool isSaving = false;
  String? error;
  List<CouponModel> coupons = [];
  CouponModel? editingCoupon;

  String get merchantId => service.merchantId;

  Future<void> load({String? editId}) async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();
      coupons = await service.loadCoupons();
      if (editId != null && editId.isNotEmpty) {
        editingCoupon = _find(editId) ?? await service.loadCoupon(editId);
      }
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> saveCoupon(CouponModel coupon) async {
    return _saving(() => service.saveCoupon(coupon));
  }

  Future<String?> publishCoupon(CouponModel coupon) async {
    final id = await _saving(() => service.publishCoupon(coupon));
    if (id != null) {
      // Lokal patchen statt der Liste – vermeidet einen vollen Collection-Reload.
      _patchCoupon(
        id,
        (current) => current.copyWith(
          status: CouponStatus.active,
          isActive: true,
          isArchived: false,
        ),
      );
    }
    return id;
  }

  Future<void> pauseCoupon(String couponId) async {
    await _savingVoid(() => service.pauseCoupon(couponId));
    if (error == null) {
      _patchCoupon(
        couponId,
        (current) => current.copyWith(
          status: CouponStatus.paused,
          isActive: false,
        ),
      );
    }
  }

  Future<void> archiveCoupon(String couponId) async {
    await _savingVoid(() => service.archiveCoupon(couponId));
    if (error == null) {
      _patchCoupon(
        couponId,
        (current) => current.copyWith(
          status: CouponStatus.archived,
          isActive: false,
          isArchived: true,
        ),
      );
    }
  }

  Future<void> deleteDraftCoupon(String couponId) async {
    await _savingVoid(() => service.deleteDraftCoupon(couponId));
    if (error == null) {
      coupons = coupons.where((coupon) => coupon.id != couponId).toList();
      notifyListeners();
    }
  }

  Future<String?> uploadImage() async {
    try {
      isSaving = true;
      error = null;
      notifyListeners();
      final media = await uploadService.pickAndUploadOptimizedImage(
        type: UploadImageType.coupon,
      );
      return media?.secureUrl ?? media?.url;
    } catch (e) {
      error = e.toString();
      return null;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  List<String> generateCodes({
    required String prefix,
    required int count,
    List<String> existing = const [],
  }) {
    return service.generateCodes(prefix: prefix, count: count, existing: existing);
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  Future<String?> _saving(Future<String> Function() action) async {
    try {
      isSaving = true;
      error = null;
      notifyListeners();
      return await action();
    } catch (e) {
      error = e.toString();
      return null;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> _savingVoid(Future<void> Function() action) async {
    try {
      isSaving = true;
      error = null;
      notifyListeners();
      await action();
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  CouponModel? _find(String id) {
    for (final coupon in coupons) {
      if (coupon.id == id) return coupon;
    }
    return null;
  }

  /// Ersetzt den betroffenen Coupon lokal (per [update]) und benachrichtigt die
  /// Listener – ohne die gesamte Collection erneut zu laden.
  void _patchCoupon(String id, CouponModel Function(CouponModel current) update) {
    var changed = false;
    coupons = coupons.map((coupon) {
      if (coupon.id != id) return coupon;
      changed = true;
      return update(coupon);
    }).toList();
    if (changed) notifyListeners();
  }
}
