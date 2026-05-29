class PointsProgressModel {
  const PointsProgressModel({
    required this.id,
  });

  final String id;

  factory PointsProgressModel.fromMap(Map<String, dynamic> map) {
    return PointsProgressModel(
      id: map['id'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
    };
  }
}

