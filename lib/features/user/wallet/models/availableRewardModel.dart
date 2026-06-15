import 'package:cloud_firestore/cloud_firestore.dart';

class AvailableRewardModel {
  const AvailableRewardModel({
    required this.rewardId,
    required this.merchantId,
    required this.merchantName,
    required this.merchantLogoUrl,
    required this.title,
    required this.description,
    required this.rewardType,
    required this.status,
    this.pointsCost,
    this.claimedAt,
    this.expiresAt,
    this.createdAt,
  });

  final String rewardId;
  final String merchantId;
  final String merchantName;
  final String merchantLogoUrl;
  final String title;
  final String description;
  final String rewardType; // 'points' | 'stamp'
  final String status; // 'available' | 'claimed' | 'expired'
  final int? pointsCost;
  final DateTime? claimedAt;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  bool get isAvailable => status == 'available';
  bool get isClaimed => status == 'claimed';

  static DateTime? _date(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  factory AvailableRewardModel.fromMap(Map<String, dynamic> map) =>
      AvailableRewardModel(
        rewardId: map['rewardId'] as String? ?? '',
        merchantId: map['merchantId'] as String? ?? '',
        merchantName: map['merchantName'] as String? ?? '',
        merchantLogoUrl: map['merchantLogoUrl'] as String? ?? '',
        title: map['title'] as String? ?? '',
        description: map['description'] as String? ?? '',
        rewardType: map['rewardType'] as String? ?? 'stamp',
        status: map['status'] as String? ?? 'available',
        pointsCost: map['pointsCost'] as int?,
        claimedAt: _date(map['claimedAt']),
        expiresAt: _date(map['expiresAt']),
        createdAt: _date(map['createdAt']),
      );
}
