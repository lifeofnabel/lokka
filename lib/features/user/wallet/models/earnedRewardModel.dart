/// A reward the customer has earned from a completed stamp card. Written
/// server-side (Cloud Function `claimReward`) into users/{uid}/earnedRewards.
/// Status `earned` → not yet used; `redeemed` → marked used by the merchant.
/// Removing a stamp NEVER deletes one of these (edge case #5).
class EarnedRewardModel {
  const EarnedRewardModel({
    required this.id,
    required this.merchantId,
    required this.cardId,
    required this.cardTitle,
    required this.label,
    required this.type,
    required this.status,
    required this.atStamp,
    this.earnedAt,
  });

  final String id;
  final String merchantId;
  final String cardId;
  final String cardTitle;
  final String label;
  final String type;
  final String status;
  final int atStamp;
  final DateTime? earnedAt;

  bool get isEarned => status == 'earned';
  bool get isRedeemed => status == 'redeemed';

  factory EarnedRewardModel.fromMap(Map<String, dynamic> map) {
    return EarnedRewardModel(
      id: (map['id'] ?? '').toString(),
      merchantId: (map['merchantId'] ?? '').toString(),
      cardId: (map['cardId'] ?? '').toString(),
      cardTitle: (map['cardTitle'] ?? '').toString(),
      label: (map['label'] ?? '').toString(),
      type: (map['type'] ?? 'custom').toString(),
      status: (map['status'] ?? 'earned').toString(),
      atStamp: (map['atStamp'] as num?)?.toInt() ?? 0,
      earnedAt: _tsToDate(map['earnedAt']),
    );
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
