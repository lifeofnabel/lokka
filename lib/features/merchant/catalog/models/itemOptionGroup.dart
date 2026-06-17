/// Eine einzelne Option innerhalb einer Optionsgruppe (z.B. „Ketchup",
/// „Extra Käse"). [price] ist der Aufpreis (0 = ohne Aufpreis).
class ItemOption {
  const ItemOption({
    required this.id,
    required this.name,
    required this.price,
  });

  final String id;
  final String name;
  final num price;

  factory ItemOption.fromMap(Map<String, dynamic> map) {
    return ItemOption(
      id: (map['id'] ?? map['name'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      price: _readNum(map['price']),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'price': price,
      };
}

/// Eine Optionsgruppe eines Artikels (z.B. „Soße wählen", „Extras").
/// [multiSelect] = Mehrfachauswahl erlaubt; [isRequired] = Pflichtauswahl.
class ItemOptionGroup {
  const ItemOptionGroup({
    required this.id,
    required this.title,
    required this.multiSelect,
    required this.isRequired,
    required this.options,
  });

  final String id;
  final String title;
  final bool multiSelect;
  final bool isRequired;
  final List<ItemOption> options;

  factory ItemOptionGroup.fromMap(Map<String, dynamic> map) {
    final rawOptions = map['options'];
    final options = <ItemOption>[];
    if (rawOptions is List) {
      for (final raw in rawOptions) {
        if (raw is Map) {
          options.add(ItemOption.fromMap(Map<String, dynamic>.from(raw)));
        }
      }
    }
    return ItemOptionGroup(
      id: (map['id'] ?? map['title'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      multiSelect: map['multiSelect'] as bool? ?? false,
      isRequired: map['isRequired'] as bool? ?? false,
      options: options,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'multiSelect': multiSelect,
        'isRequired': isRequired,
        'options': options.map((option) => option.toMap()).toList(),
      };
}

num _readNum(dynamic value) {
  if (value is num) return value;
  return num.tryParse((value ?? '').toString().replaceAll(',', '.')) ?? 0;
}
