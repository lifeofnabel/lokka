import 'package:cloud_firestore/cloud_firestore.dart';

/// Ein einzelner Speisekarten-Eintrag (User-Sicht, read-only).
class UserMenuItem {
  const UserMenuItem({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.price,
    this.originalPrice,
    this.imageUrl,
    required this.isAvailable,
  });

  final String id;
  final String categoryId;
  final String name;
  final String description;
  final num price;
  final num? originalPrice;
  final String? imageUrl;
  final bool isAvailable;

  bool get hasDiscount =>
      originalPrice != null && (originalPrice ?? 0) > price && price > 0;

  /// Nur öffentlich sichtbare, aktive Einträge gehören in die User-Karte.
  bool get isPublic => isAvailable;

  factory UserMenuItem.fromMap(Map<String, dynamic> map) {
    final name = (map['name'] ?? map['title'] ?? '').toString();
    return UserMenuItem(
      id: map['id'] as String? ?? '',
      categoryId: map['categoryId'] as String? ?? '',
      name: name,
      description: map['description'] as String? ?? '',
      price: map['price'] as num? ?? 0,
      originalPrice: map['originalPrice'] as num?,
      imageUrl: (map['imageUrl'] as String?)?.isNotEmpty == true
          ? map['imageUrl'] as String
          : map['imageThumbUrl'] as String?,
      isAvailable: map['isAvailable'] as bool? ?? true,
    );
  }
}

/// Eine Kategorie mit ihren Einträgen.
class UserMenuCategory {
  const UserMenuCategory({
    required this.id,
    required this.name,
    this.emoji,
    required this.sortOrder,
    required this.items,
  });

  final String id;
  final String name;
  final String? emoji;
  final int sortOrder;
  final List<UserMenuItem> items;

  UserMenuCategory copyWith({List<UserMenuItem>? items}) => UserMenuCategory(
        id: id,
        name: name,
        emoji: emoji,
        sortOrder: sortOrder,
        items: items ?? this.items,
      );

  factory UserMenuCategory.fromMap(Map<String, dynamic> map) {
    return UserMenuCategory(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      emoji: (map['emoji'] as String?)?.isNotEmpty == true
          ? map['emoji'] as String
          : null,
      sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
      items: const [],
    );
  }
}

DateTime? menuDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  return DateTime.tryParse(value.toString());
}
