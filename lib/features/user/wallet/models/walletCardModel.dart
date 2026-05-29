class WalletCardModel {
  const WalletCardModel({
    required this.merchantId,
    required this.merchantName,
    required this.merchantLogoUrl,
    required this.merchantArea,
    required this.merchantShopType,
    required this.walletCode,
    required this.walletNumber,
    required this.prefix,
    required this.status,
    required this.hasStampCards,
    required this.hasPoints,
    required this.hasCoupons,
    this.joinedAt,
    this.lastActivityAt,
  });

  final String merchantId;
  final String merchantName;
  final String merchantLogoUrl;
  final String merchantArea;
  final String merchantShopType;
  final String walletCode;
  final String walletNumber;
  final String prefix;
  final String status;
  final bool hasStampCards;
  final bool hasPoints;
  final bool hasCoupons;
  final DateTime? joinedAt;
  final DateTime? lastActivityAt;

  factory WalletCardModel.fromMap(Map<String, dynamic> map) {
    return WalletCardModel(
      merchantId: map['merchantId'] as String? ?? '',
      merchantName: map['merchantName'] as String? ?? '',
      merchantLogoUrl: map['merchantLogoUrl'] as String? ?? '',
      merchantArea: map['merchantArea'] as String? ?? '',
      merchantShopType: map['merchantShopType'] as String? ?? '',
      walletCode: map['walletCode'] as String? ?? '',
      walletNumber: map['walletNumber'] as String? ?? '',
      prefix: map['prefix'] as String? ?? '',
      status: map['status'] as String? ?? 'active',
      hasStampCards: map['hasStampCards'] as bool? ?? false,
      hasPoints: map['hasPoints'] as bool? ?? false,
      hasCoupons: map['hasCoupons'] as bool? ?? false,
      joinedAt: _tsToDate(map['joinedAt']),
      lastActivityAt: _tsToDate(map['lastActivityAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'merchantId': merchantId,
      'merchantName': merchantName,
      'merchantLogoUrl': merchantLogoUrl,
      'merchantArea': merchantArea,
      'merchantShopType': merchantShopType,
      'walletCode': walletCode,
      'walletNumber': walletNumber,
      'prefix': prefix,
      'status': status,
      'hasStampCards': hasStampCards,
      'hasPoints': hasPoints,
      'hasCoupons': hasCoupons,
      'joinedAt': joinedAt,
      'lastActivityAt': lastActivityAt,
    };
  }
}

DateTime? _tsToDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  try {
    return (v as dynamic).toDate() as DateTime;
  } catch (_) {
    return DateTime.tryParse(v.toString());
  }
}
