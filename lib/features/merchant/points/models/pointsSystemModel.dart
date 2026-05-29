class PointsSystemModel {
  const PointsSystemModel({
    required this.id,
  });

  final String id;

  factory PointsSystemModel.fromMap(Map<String, dynamic> map) {
    return PointsSystemModel(
      id: map['id'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
    };
  }
}

