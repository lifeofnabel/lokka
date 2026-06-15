class TableAreaData {
  const TableAreaData({
    required this.areaId,
    required this.name,
    required this.sortOrder,
    required this.isActive,
  });

  final String areaId;
  final String name;
  final int sortOrder;
  final bool isActive;

  factory TableAreaData.fromMap(Map<String, dynamic> map) {
    return TableAreaData(
      areaId: map['areaId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: map['isActive'] as bool? ?? true,
    );
  }
}

class TableData {
  const TableData({
    required this.tableId,
    required this.areaId,
    required this.areaName,
    required this.label,
    required this.seats,
    required this.qrUrl,
    required this.isActive,
  });

  final String tableId;
  final String areaId;
  final String areaName;
  final String label;
  final int? seats;
  final String qrUrl;
  final bool isActive;

  factory TableData.fromMap(Map<String, dynamic> map) {
    return TableData(
      tableId: map['tableId'] as String? ?? '',
      areaId: map['areaId'] as String? ?? '',
      areaName: map['areaName'] as String? ?? '',
      label: map['label'] as String? ?? '',
      seats: (map['seats'] as num?)?.toInt(),
      qrUrl: map['qrUrl'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? true,
    );
  }
}
