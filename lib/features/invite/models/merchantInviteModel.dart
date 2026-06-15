import 'package:cloud_firestore/cloud_firestore.dart';

class MerchantInviteModel {
  const MerchantInviteModel({
    required this.inviteId,
    required this.merchantId,
    required this.merchantName,
    required this.type,
    required this.inviteCode,
    required this.inviteUrl,
    required this.openedCount,
    required this.usedCount,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  final String inviteId;
  final String merchantId;
  final String merchantName;
  final String type;
  final String inviteCode;
  final String inviteUrl;
  final int openedCount;
  final int usedCount;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory MerchantInviteModel.fromMap(Map<String, dynamic> map) {
    return MerchantInviteModel(
      inviteId: map['inviteId'] as String? ?? '',
      merchantId: map['merchantId'] as String? ?? '',
      merchantName: map['merchantName'] as String? ?? '',
      type: map['type'] as String? ?? '',
      inviteCode: map['inviteCode'] as String? ?? '',
      inviteUrl: map['inviteUrl'] as String? ?? '',
      openedCount: (map['openedCount'] as num?)?.toInt() ?? 0,
      usedCount: (map['usedCount'] as num?)?.toInt() ?? 0,
      isActive: map['isActive'] as bool? ?? true,
      createdAt: _date(map['createdAt']),
      updatedAt: _date(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'inviteId': inviteId,
      'merchantId': merchantId,
      'merchantName': merchantName,
      'type': type,
      'inviteCode': inviteCode,
      'inviteUrl': inviteUrl,
      'openedCount': openedCount,
      'usedCount': usedCount,
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  return DateTime.tryParse(value.toString());
}
