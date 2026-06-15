class MerchantItemData {
  const MerchantItemData({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    required this.description,
    required this.price,
    required this.originalPrice,
    required this.imageUrl,
    required this.articleNumber,
    required this.allergenIds,
    required this.additiveIds,
    required this.isActive,
    required this.isAvailable,
    required this.isPrivate,
    required this.isArchived,
  });

  final String id;
  final String categoryId;
  final String categoryName;
  final String name;
  final String description;
  final num price;
  final num? originalPrice;
  final String imageUrl;
  final String articleNumber;
  final List<String> allergenIds;
  final List<String> additiveIds;
  final bool isActive;
  final bool isAvailable;
  final bool isPrivate;
  final bool isArchived;

  factory MerchantItemData.fromMap(Map<String, dynamic> map) {
    return MerchantItemData(
      id: map['id'] as String? ?? '',
      categoryId: map['categoryId'] as String? ?? '',
      categoryName: map['categoryName'] as String? ?? '',
      name: (map['name'] ?? map['title'] ?? '').toString(),
      description: map['description'] as String? ?? '',
      price: map['price'] as num? ?? 0,
      originalPrice: map['originalPrice'] as num?,
      imageUrl: map['imageUrl'] as String? ?? '',
      articleNumber: map['articleNumber'] as String? ?? '',
      allergenIds: _stringList(map['allergenIds']),
      additiveIds: _stringList(map['additiveIds']),
      isActive: map['isActive'] as bool? ?? true,
      isAvailable: map['isAvailable'] as bool? ?? true,
      isPrivate: map['isPrivate'] as bool? ?? false,
      isArchived: map['isArchived'] as bool? ?? false,
    );
  }
}

List<String> _stringList(dynamic value) {
  if (value is Iterable) {
    return value.map((item) => item.toString()).where((item) => item.trim().isNotEmpty).toList();
  }
  return const [];
}
