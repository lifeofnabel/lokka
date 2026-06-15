class FeedCatalogItem {
  const FeedCatalogItem({
    required this.id,
    required this.name,
    required this.title,
    required this.description,
    required this.categoryName,
    required this.price,
    this.originalPrice,
    required this.imageUrl,
    required this.isActive,
    required this.isAvailable,
    required this.isPrivate,
  });

  final String id;
  final String name;
  final String title;
  final String description;
  final String categoryName;
  final num price;
  final num? originalPrice;
  final String imageUrl;
  final bool isActive;
  final bool isAvailable;
  final bool isPrivate;

  String get displayName {
    final value = title.trim().isNotEmpty ? title : name;
    return value.trim();
  }

  factory FeedCatalogItem.fromMap(Map<String, dynamic> map) {
    final name = (map['name'] ?? map['title'] ?? '').toString();
    return FeedCatalogItem(
      id: (map['id'] ?? '').toString(),
      name: name,
      title: (map['title'] ?? name).toString(),
      description: (map['description'] ?? '').toString(),
      categoryName: (map['categoryName'] ?? '').toString(),
      price: map['price'] is num ? map['price'] as num : num.tryParse((map['price'] ?? '0').toString()) ?? 0,
      originalPrice: map['originalPrice'] is num
          ? map['originalPrice'] as num
          : num.tryParse((map['originalPrice'] ?? '').toString()),
      imageUrl: (map['imageUrl'] ?? map['imageThumbUrl'] ?? '').toString(),
      isActive: map['isActive'] as bool? ?? true,
      isAvailable: map['isAvailable'] as bool? ?? true,
      isPrivate: map['isPrivate'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toRuleMap() {
    return {
      'id': id,
      'name': displayName,
      'categoryName': categoryName,
      'price': price,
      'originalPrice': originalPrice,
      'imageUrl': imageUrl,
      'isActive': isActive,
      'isAvailable': isAvailable,
      'isPrivate': isPrivate,
    };
  }
}
