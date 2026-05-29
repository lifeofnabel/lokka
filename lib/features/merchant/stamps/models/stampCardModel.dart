class StampCardModel {
  const StampCardModel({
    required this.id,
  });

  final String id;

  factory StampCardModel.fromMap(Map<String, dynamic> map) {
    return StampCardModel(
      id: map['id'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
    };
  }
}

