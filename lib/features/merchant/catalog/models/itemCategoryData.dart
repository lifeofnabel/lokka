class ItemCategoryData {
  const ItemCategoryData({
    required this.id,
    required this.merchantId,
    required this.name,
    required this.normalizedName,
    required this.sortOrder,
    required this.emoji,
    required this.iconUrl,
    required this.isActive,
    required this.isPrivate,
    required this.isArchived,
  });

  final String id;
  final String merchantId;
  final String name;
  final String normalizedName;
  final int sortOrder;
  final String emoji;
  final String iconUrl;
  final bool isActive;
  final bool isPrivate;
  final bool isArchived;

  factory ItemCategoryData.fromMap(Map<String, dynamic> map) {
    return ItemCategoryData(
      id: map['id'] as String? ?? '',
      merchantId: map['merchantId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      normalizedName: map['normalizedName'] as String? ?? '',
      sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
      emoji: map['emoji'] as String? ?? '',
      iconUrl: map['iconUrl'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? true,
      isPrivate: map['isPrivate'] as bool? ?? false,
      isArchived: map['isArchived'] as bool? ?? false,
    );
  }
}
