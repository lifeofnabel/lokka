class FeedPostModel {
  const FeedPostModel({
    required this.postId,
    required this.merchantId,
    required this.merchantName,
    required this.merchantLogoUrl,
    required this.merchantArea,
    required this.merchantShopType,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.imageUrl,
    required this.isActive,
    required this.isArchived,
    required this.isPrivate,
    required this.likesCount,
    required this.viewsCount,
    required this.opensCount,
    required this.clicksCount,
    this.oldPrice,
    this.newPrice,
    this.discountPercent,
    this.categoryId,
    this.createdAt,
    this.updatedAt,
    this.publishedAt,
  });

  final String postId;
  final String merchantId;
  final String merchantName;
  final String merchantLogoUrl;
  final String merchantArea;
  final String merchantShopType;
  final String type;
  final String title;
  final String subtitle;
  final String description;
  final String imageUrl;
  final bool isActive;
  final bool isArchived;
  final bool isPrivate;
  final int likesCount;
  final int viewsCount;
  final int opensCount;
  final int clicksCount;
  final double? oldPrice;
  final double? newPrice;
  final int? discountPercent;
  final String? categoryId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? publishedAt;

  factory FeedPostModel.fromMap(Map<String, dynamic> map) {
    return FeedPostModel(
      postId: map['postId'] as String? ?? map['id'] as String? ?? '',
      merchantId: map['merchantId'] as String? ?? '',
      merchantName: map['merchantName'] as String? ?? '',
      merchantLogoUrl: map['merchantLogoUrl'] as String? ?? '',
      merchantArea: map['merchantArea'] as String? ?? '',
      merchantShopType: map['merchantShopType'] as String? ?? '',
      type: map['type'] as String? ?? '',
      title: map['title'] as String? ?? '',
      subtitle: map['subtitle'] as String? ?? '',
      description: map['description'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? false,
      isArchived: map['isArchived'] as bool? ?? false,
      isPrivate: map['isPrivate'] as bool? ?? false,
      likesCount: (map['likesCount'] as num?)?.toInt() ?? 0,
      viewsCount: (map['viewsCount'] as num?)?.toInt() ?? 0,
      opensCount: (map['opensCount'] as num?)?.toInt() ?? 0,
      clicksCount: (map['clicksCount'] as num?)?.toInt() ?? 0,
      oldPrice: (map['oldPrice'] as num?)?.toDouble(),
      newPrice: (map['newPrice'] as num?)?.toDouble(),
      discountPercent: (map['discountPercent'] as num?)?.toInt(),
      categoryId: map['categoryId'] as String?,
      createdAt: _tsToDate(map['createdAt']),
      updatedAt: _tsToDate(map['updatedAt']),
      publishedAt: _tsToDate(map['publishedAt']),
    );
  }

  bool get hasPriceInfo => newPrice != null || discountPercent != null;
  bool get hasDiscount => discountPercent != null && discountPercent! > 0;
}

DateTime? _tsToDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  try {
    return (v as dynamic).toDate() as DateTime;
  } catch (_) {
    return DateTime.tryParse(v.toString());
  }
}
