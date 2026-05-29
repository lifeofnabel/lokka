class MerchantSetupModel {
  const MerchantSetupModel({
    required this.id,
  });

  final String id;

  factory MerchantSetupModel.fromMap(Map<String, dynamic> map) {
    return MerchantSetupModel(
      id: map['id'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
    };
  }
}

