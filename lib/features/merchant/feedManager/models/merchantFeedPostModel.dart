class MerchantFeedPostModel {
  const MerchantFeedPostModel({
    required this.id,
  });

  final String id;

  factory MerchantFeedPostModel.fromMap(Map<String, dynamic> map) {
    return MerchantFeedPostModel(
      id: map['id'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
    };
  }
}

