class ItemCategoryModel {
  const ItemCategoryModel({
    required this.id,
  });

  final String id;

  factory ItemCategoryModel.fromMap(Map<String, dynamic> map) {
    return ItemCategoryModel(
      id: map['id'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
    };
  }
}

