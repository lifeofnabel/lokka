class PointsProgressModel {
  const PointsProgressModel({
    required this.merchantId,
    required this.currentPoints,
    required this.lifetimePoints,
    required this.status,
    this.systemId,
    this.resetDay,
    this.lastResetAt,
    this.updatedAt,
  });

  final String merchantId;
  final int currentPoints;
  final int lifetimePoints;
  final String status;
  final String? systemId;
  final int? resetDay;
  final DateTime? lastResetAt;
  final DateTime? updatedAt;

  factory PointsProgressModel.fromMap(Map<String, dynamic> map) {
    return PointsProgressModel(
      merchantId: map['merchantId'] as String? ?? '',
      currentPoints: map['currentPoints'] as int? ?? 0,
      lifetimePoints: map['lifetimePoints'] as int? ?? 0,
      status: map['status'] as String? ?? 'active',
      systemId: map['systemId'] as String?,
      resetDay: map['resetDay'] as int?,
      lastResetAt: _tsToDate(map['lastResetAt']),
      updatedAt: _tsToDate(map['updatedAt']),
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
