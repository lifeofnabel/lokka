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
    this.buttonText,
    this.buttonLink,
    this.buttonActionType,
    this.ctaLabel,
    this.ctaLinkType,
    this.ctaTargetId,
    this.ctaUrl,
    this.ctaRoute,
    this.targetAudience,
    this.isScheduled = false,
    this.validFrom,
    this.validUntil,
    this.createdAt,
    this.updatedAt,
    this.publishedAt,
    this.scheduledAt,
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
  final String? buttonText;
  final String? buttonLink;
  final String? buttonActionType;
  final String? ctaLabel;
  final String? ctaLinkType;
  final String? ctaTargetId;
  final String? ctaUrl;
  final String? ctaRoute;
  final String? targetAudience;
  final bool isScheduled;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? publishedAt;
  final DateTime? scheduledAt;

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
      categoryId: _optionalString(map['categoryId']),
      buttonText: _optionalString(map['buttonText']),
      buttonLink: _optionalString(map['buttonLink']),
      buttonActionType: _optionalString(map['buttonActionType']),
      ctaLabel: _optionalString(map['ctaLabel'] ?? map['buttonText']),
      ctaLinkType: _optionalString(map['ctaLinkType']),
      ctaTargetId: _optionalString(map['ctaTargetId']),
      ctaUrl: _optionalString(map['ctaUrl'] ?? map['buttonLink']),
      ctaRoute: _optionalString(map['ctaRoute']),
      targetAudience: _optionalString(map['targetAudience']),
      isScheduled: map['isScheduled'] as bool? ?? false,
      validFrom: _tsToDate(map['validFrom']),
      validUntil: _tsToDate(map['validUntil']),
      createdAt: _tsToDate(map['createdAt']),
      updatedAt: _tsToDate(map['updatedAt']),
      publishedAt: _tsToDate(map['publishedAt']),
      scheduledAt: _tsToDate(map['scheduledAt'] ?? map['startDate']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'merchantId': merchantId,
      'merchantName': merchantName,
      'merchantLogoUrl': merchantLogoUrl,
      'merchantArea': merchantArea,
      'merchantShopType': merchantShopType,
      'type': type,
      'title': title,
      'subtitle': subtitle,
      'description': description,
      'imageUrl': imageUrl,
      'isActive': isActive,
      'isArchived': isArchived,
      'isPrivate': isPrivate,
      'likesCount': likesCount,
      'viewsCount': viewsCount,
      'opensCount': opensCount,
      'clicksCount': clicksCount,
      'oldPrice': oldPrice,
      'newPrice': newPrice,
      'discountPercent': discountPercent,
      'categoryId': categoryId,
      'buttonText': buttonText,
      'buttonLink': buttonLink,
      'buttonActionType': buttonActionType,
      'ctaLabel': ctaLabel,
      'ctaLinkType': ctaLinkType,
      'ctaTargetId': ctaTargetId,
      'ctaUrl': ctaUrl,
      'ctaRoute': ctaRoute,
      'targetAudience': targetAudience,
      'isScheduled': isScheduled,
      'validFrom': validFrom?.toIso8601String(),
      'validUntil': validUntil?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'publishedAt': publishedAt?.toIso8601String(),
      'scheduledAt': scheduledAt?.toIso8601String(),
    };
  }

  bool get hasPriceInfo => newPrice != null || discountPercent != null;
  bool get hasDiscount => discountPercent != null && discountPercent! > 0;
  String get effectiveButtonText {
    final current = ctaLabel ?? buttonText ?? '';
    return current.trim();
  }

  String get effectiveButtonUrl {
    final current = ctaUrl ?? buttonLink ?? '';
    return current.trim();
  }

  String get effectiveCtaType {
    final current = ctaLinkType ?? buttonActionType ?? '';
    return current.trim();
  }

  bool get isForRegulars => targetAudience?.trim() == 'regulars';
  bool get hasButton => effectiveButtonText.isNotEmpty;

  bool get isCurrentlyValid {
    final now = DateTime.now();
    if (validFrom != null && now.isBefore(validFrom!)) return false;
    if (validUntil != null && now.isAfter(validUntil!)) return false;
    return true;
  }
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

String? _optionalString(dynamic value) {
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}
