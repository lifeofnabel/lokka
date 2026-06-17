import 'itemOptionGroup.dart';

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
    this.imageRatio = 'square',
    this.optionGroups = const [],
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

  /// Bild-Seitenverhältnis: 'square' (1:1) oder 'wide' (16:9, magazin-tauglich).
  final String imageRatio;

  bool get isWideImage => imageRatio == 'wide';

  /// Optionsgruppen (z.B. „Soße", „Extras") mit Aufpreis-Optionen.
  final List<ItemOptionGroup> optionGroups;

  bool get hasOptions => optionGroups.isNotEmpty;

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
      imageRatio: (map['imageRatio'] as String?) == 'wide' ? 'wide' : 'square',
      optionGroups: _readOptionGroups(map['optionGroups']),
    );
  }
}

List<ItemOptionGroup> _readOptionGroups(dynamic value) {
  if (value is! List) return const [];
  final groups = <ItemOptionGroup>[];
  for (final raw in value) {
    if (raw is Map) {
      groups.add(ItemOptionGroup.fromMap(Map<String, dynamic>.from(raw)));
    }
  }
  return groups;
}

List<String> _stringList(dynamic value) {
  if (value is Iterable) {
    return value.map((item) => item.toString()).where((item) => item.trim().isNotEmpty).toList();
  }
  return const [];
}
