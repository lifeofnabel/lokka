class UploadedMediaModel {
  const UploadedMediaModel({
    required this.id,
  });

  final String id;

  factory UploadedMediaModel.fromMap(Map<String, dynamic> map) {
    return UploadedMediaModel(
      id: map['id'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
    };
  }
}

