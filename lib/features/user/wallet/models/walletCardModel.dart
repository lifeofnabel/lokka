class WalletCardModel {
  const WalletCardModel({
    required this.id,
  });

  final String id;

  factory WalletCardModel.fromMap(Map<String, dynamic> map) {
    return WalletCardModel(
      id: map['id'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
    };
  }
}

