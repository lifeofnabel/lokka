class FeedPostModel {
  const FeedPostModel({
    required this.id,
  });

  final String id;

  factory FeedPostModel.fromMap(Map<String, dynamic> map) {
    return FeedPostModel(
      id: map['id'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
    };
  }
}

