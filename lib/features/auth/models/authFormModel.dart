class AuthFormModel {
  const AuthFormModel({
    required this.id,
  });

  final String id;

  factory AuthFormModel.fromMap(Map<String, dynamic> map) {
    return AuthFormModel(
      id: map['id'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
    };
  }
}

