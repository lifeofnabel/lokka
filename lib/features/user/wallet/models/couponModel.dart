import 'package:cloud_firestore/cloud_firestore.dart';

class CouponModel {
  const CouponModel({
    required this.couponId,
    required this.merchantId,
    required this.merchantName,
    required this.merchantLogoUrl,
    required this.title,
    required this.description,
    required this.discountType,
    this.discountValue,
    required this.status,
    this.expiresAt,
    this.usedAt,
    this.createdAt,
  });

  final String couponId;
  final String merchantId;
  final String merchantName;
  final String merchantLogoUrl;
  final String title;
  final String description;
  final String discountType; // 'percent' | 'fixed' | 'free'
  final double? discountValue;
  final String status; // 'active' | 'used' | 'expired'
  final DateTime? expiresAt;
  final DateTime? usedAt;
  final DateTime? createdAt;

  bool get isActive => status == 'active';
  bool get isUsed => status == 'used';

  static DateTime? _date(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  factory CouponModel.fromMap(Map<String, dynamic> map) => CouponModel(
        couponId: map['couponId'] as String? ?? '',
        merchantId: map['merchantId'] as String? ?? '',
        merchantName: map['merchantName'] as String? ?? '',
        merchantLogoUrl: map['merchantLogoUrl'] as String? ?? '',
        title: map['title'] as String? ?? '',
        description: map['description'] as String? ?? '',
        discountType: map['discountType'] as String? ?? 'fixed',
        discountValue: (map['discountValue'] as num?)?.toDouble(),
        status: map['status'] as String? ?? 'active',
        expiresAt: _date(map['expiresAt']),
        usedAt: _date(map['usedAt']),
        createdAt: _date(map['createdAt']),
      );
}
