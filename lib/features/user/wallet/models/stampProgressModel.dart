class StampProgressModel {
  const StampProgressModel({
    required this.id,
  });

  final String id;

  factory StampProgressModel.fromMap(Map<String, dynamic> map) {
    return StampProgressModel(
      id: map['id'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
    };
  }
}

