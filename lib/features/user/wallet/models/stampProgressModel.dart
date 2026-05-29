class StampProgressModel {
  const StampProgressModel({
    required this.stampCardId,
    required this.merchantId,
    required this.currentStamps,
    required this.stampsRequired,
    required this.status,
    this.lastStampAt,
    this.completedAt,
    this.claimedAt,
  });

  final String stampCardId;
  final String merchantId;
  final int currentStamps;
  final int stampsRequired;
  final String status;
  final DateTime? lastStampAt;
  final DateTime? completedAt;
  final DateTime? claimedAt;

  factory StampProgressModel.fromMap(Map<String, dynamic> map) {
    return StampProgressModel(
      stampCardId: map['stampCardId'] as String? ?? '',
      merchantId: map['merchantId'] as String? ?? '',
      currentStamps: map['currentStamps'] as int? ?? 0,
      stampsRequired: map['stampsRequired'] as int? ?? 10,
      status: map['status'] as String? ?? 'active',
      lastStampAt: _tsToDate(map['lastStampAt']),
      completedAt: _tsToDate(map['completedAt']),
      claimedAt: _tsToDate(map['claimedAt']),
    );
  }

  bool get isCompleted => currentStamps >= stampsRequired;
  bool get isClaimed => claimedAt != null;
  double get progress =>
      stampsRequired > 0 ? (currentStamps / stampsRequired).clamp(0.0, 1.0) : 0;
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
