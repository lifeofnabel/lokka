class ItemTagType {
  const ItemTagType._();

  static const allergen = 'allergen';
  static const additive = 'additive';
}

class ItemTagData {
  const ItemTagData({
    required this.id,
    required this.merchantId,
    required this.type,
    required this.code,
    required this.name,
    required this.isActive,
    required this.isCustom,
  });

  final String id;
  final String merchantId;
  final String type;
  final String code;
  final String name;
  final bool isActive;
  final bool isCustom;

  factory ItemTagData.fromMap(Map<String, dynamic> map) {
    return ItemTagData(
      id: (map['id'] ?? map['tagId'] ?? '').toString(),
      merchantId: (map['merchantId'] ?? '').toString(),
      type: (map['type'] ?? ItemTagType.allergen).toString(),
      code: (map['code'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      isActive: map['isActive'] as bool? ?? true,
      isCustom: map['isCustom'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'merchantId': merchantId,
      'type': type,
      'code': code,
      'name': name,
      'isActive': isActive,
      'isCustom': isCustom,
    };
  }
}

List<ItemTagData> defaultItemTags(String merchantId) {
  const allergens = [
    ('gluten', 'A', 'Gluten'),
    ('crustaceans', 'B', 'Krebstiere'),
    ('eggs', 'C', 'Eier'),
    ('fish', 'D', 'Fisch'),
    ('peanuts', 'E', 'Erdnuesse'),
    ('soy', 'F', 'Soja'),
    ('milk', 'G', 'Milch'),
    ('nuts', 'H', 'Schalenfruechte'),
    ('celery', 'I', 'Sellerie'),
    ('mustard', 'J', 'Senf'),
    ('sesame', 'K', 'Sesam'),
    ('sulphites', 'L', 'Sulfite'),
    ('lupin', 'M', 'Lupinen'),
    ('molluscs', 'N', 'Weichtiere'),
  ];
  const additives = [
    ('coloring', '1', 'Farbstoff'),
    ('preservative', '2', 'Konservierungsstoff'),
    ('antioxidant', '3', 'Antioxidationsmittel'),
    ('flavorEnhancer', '4', 'Geschmacksverstaerker'),
    ('sweetener', '5', 'Suessungsmittel'),
    ('phosphate', '6', 'Phosphat'),
    ('caffeine', '7', 'Koffein'),
    ('quinine', '8', 'Chinin'),
  ];

  return [
    for (final item in allergens)
      ItemTagData(
        id: item.$1,
        merchantId: merchantId,
        type: ItemTagType.allergen,
        code: item.$2,
        name: item.$3,
        isActive: true,
        isCustom: false,
      ),
    for (final item in additives)
      ItemTagData(
        id: item.$1,
        merchantId: merchantId,
        type: ItemTagType.additive,
        code: item.$2,
        name: item.$3,
        isActive: true,
        isCustom: false,
      ),
  ];
}
