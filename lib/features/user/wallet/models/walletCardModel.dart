class WalletCardModel {
  const WalletCardModel({
    required this.merchantId,
    required this.merchantName,
    required this.merchantLogoUrl,
    this.merchantCoverUrl = '',
    required this.merchantCity,
    required this.merchantShopType,
    this.merchantOrigin = '',
    required this.walletCode,
    required this.walletNumber,
    required this.prefix,
    required this.status,
    required this.hasStampCards,
    required this.hasPoints,
    required this.hasCoupons,
    this.addedStampCardIds = const [],
    this.joinedAt,
    this.lastActivityAt,
  });

  final String merchantId;
  final String merchantName;
  final String merchantLogoUrl;

  /// Cover image — used as the credit-card background (heavily darkened).
  final String merchantCoverUrl;
  final String merchantCity;
  final String merchantShopType;

  /// Origin / cuisine (e.g. "Italienisch") — the "Herkunft" half of the
  /// "Kategorie · Herkunft" line on the credit-card. Empty when unknown.
  final String merchantOrigin;
  final String walletCode;
  final String walletNumber;
  final String prefix;
  final String status;
  final bool hasStampCards;
  final bool hasPoints;
  final bool hasCoupons;

  /// IDs of the stamp cards the user explicitly added to their wallet (only
  /// these are shown in the wallet — adding happens on the merchant page).
  final List<String> addedStampCardIds;
  final DateTime? joinedAt;
  final DateTime? lastActivityAt;

  factory WalletCardModel.fromMap(Map<String, dynamic> map) {
    return WalletCardModel(
      merchantId: map['merchantId'] as String? ?? '',
      merchantName: map['merchantName'] as String? ?? '',
      merchantLogoUrl: map['merchantLogoUrl'] as String? ?? '',
      merchantCoverUrl: map['merchantCoverUrl'] as String? ?? '',
      merchantCity:
          map['merchantCity'] as String? ?? map['merchantArea'] as String? ?? '',
      merchantShopType: map['merchantShopType'] as String? ?? '',
      merchantOrigin: map['merchantOrigin'] as String? ?? '',
      walletCode: map['walletCode'] as String? ?? '',
      walletNumber: map['walletNumber'] as String? ?? '',
      prefix: map['prefix'] as String? ?? '',
      status: map['status'] as String? ?? 'active',
      hasStampCards: map['hasStampCards'] as bool? ?? false,
      hasPoints: map['hasPoints'] as bool? ?? false,
      hasCoupons: map['hasCoupons'] as bool? ?? false,
      addedStampCardIds: (map['addedStampCardIds'] as List?)
              ?.map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const [],
      joinedAt: _tsToDate(map['joinedAt']),
      lastActivityAt: _tsToDate(map['lastActivityAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'merchantId': merchantId,
      'merchantName': merchantName,
      'merchantLogoUrl': merchantLogoUrl,
      'merchantCoverUrl': merchantCoverUrl,
      'merchantCity': merchantCity,
      'merchantShopType': merchantShopType,
      'merchantOrigin': merchantOrigin,
      'walletCode': walletCode,
      'walletNumber': walletNumber,
      'prefix': prefix,
      'status': status,
      'hasStampCards': hasStampCards,
      'hasPoints': hasPoints,
      'hasCoupons': hasCoupons,
      'addedStampCardIds': addedStampCardIds,
      'joinedAt': joinedAt?.toIso8601String(),
      'lastActivityAt': lastActivityAt?.toIso8601String(),
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
