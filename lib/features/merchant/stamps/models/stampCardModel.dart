import 'package:cloud_firestore/cloud_firestore.dart';

class StampCardStatus {
  const StampCardStatus._();

  static const draft = 'draft';
  static const active = 'active';
  static const paused = 'paused';
  static const archived = 'archived';
}

class StampConditionType {
  const StampConditionType._();

  static const minimumAmount = 'minimumAmount';
  static const item = 'item';
  static const visit = 'visit';
  static const custom = 'custom';
}

class StampRewardType {
  const StampRewardType._();

  static const item = 'item';
  static const custom = 'custom';
}

class StampCardModel {
  const StampCardModel({
    required this.id,
    required this.merchantId,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.requiredStamps,
    required this.conditionType,
    required this.minimumAmount,
    required this.requiredItemId,
    required this.requiredItemName,
    required this.conditionText,
    required this.rewardType,
    required this.rewardItemId,
    required this.rewardItemName,
    required this.rewardTitle,
    required this.rewardDescription,
    required this.backgroundColor,
    required this.gradientColor,
    required this.gradientEnabled,
    required this.accentColor,
    required this.textColor,
    required this.styleName,
    required this.stampShape,
    required this.stampIconType,
    required this.stampIconValue,
    required this.imageUrl,
    required this.imagePlacement,
    required this.claimLimits,
    required this.creditCostPerWeek,
    required this.status,
    required this.isActive,
    required this.isArchived,
    this.createdAt,
    this.updatedAt,
    this.publishedAt,
    this.activatedAt,
    this.pausedAt,
    this.archivedAt,
  });

  final String id;
  final String merchantId;
  final String title;
  final String subtitle;
  final String description;
  final int requiredStamps;
  final String conditionType;
  final num? minimumAmount;
  final String requiredItemId;
  final String requiredItemName;
  final String conditionText;
  final String rewardType;
  final String rewardItemId;
  final String rewardItemName;
  final String rewardTitle;
  final String rewardDescription;
  final String backgroundColor;
  final String gradientColor;
  final bool gradientEnabled;
  final String accentColor;
  final String textColor;
  final String styleName;
  final String stampShape;
  final String stampIconType;
  final String stampIconValue;
  final String imageUrl;
  final String imagePlacement;
  final Map<String, dynamic> claimLimits;
  final int creditCostPerWeek;
  final String status;
  final bool isActive;
  final bool isArchived;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? publishedAt;
  final DateTime? activatedAt;
  final DateTime? pausedAt;
  final DateTime? archivedAt;

  bool get isDraft => status == StampCardStatus.draft;
  bool get isLive => status == StampCardStatus.active && isActive;
  bool get isPaused => status == StampCardStatus.paused;
  bool get isArchivedCard => status == StampCardStatus.archived || isArchived;

  factory StampCardModel.empty({required String merchantId}) {
    return StampCardModel(
      id: '',
      merchantId: merchantId,
      title: '',
      subtitle: '',
      description: '',
      requiredStamps: 10,
      conditionType: StampConditionType.visit,
      minimumAmount: null,
      requiredItemId: '',
      requiredItemName: '',
      conditionText: '',
      rewardType: StampRewardType.custom,
      rewardItemId: '',
      rewardItemName: '',
      rewardTitle: '',
      rewardDescription: '',
      backgroundColor: '#171A18',
      gradientColor: '#45C9A4',
      gradientEnabled: false,
      accentColor: '#9CE8CF',
      textColor: '#FEFFFC',
      styleName: 'noir',
      stampShape: 'circle',
      stampIconType: 'icon',
      stampIconValue: 'star',
      imageUrl: '',
      imagePlacement: 'side',
      claimLimits: const {'perUser': null, 'perDay': null},
      creditCostPerWeek: 2,
      status: StampCardStatus.draft,
      isActive: false,
      isArchived: false,
    );
  }

  factory StampCardModel.fromMap(Map<String, dynamic> map) {
    return StampCardModel(
      id: (map['id'] ?? map['stampCardId'] ?? '').toString(),
      merchantId: (map['merchantId'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      subtitle: (map['subtitle'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      requiredStamps: _readInt(map['requiredStamps'], fallback: 10),
      conditionType: (map['conditionType'] ?? StampConditionType.visit).toString(),
      minimumAmount: map['minimumAmount'] is num ? map['minimumAmount'] as num : num.tryParse((map['minimumAmount'] ?? '').toString()),
      requiredItemId: (map['requiredItemId'] ?? '').toString(),
      requiredItemName: (map['requiredItemName'] ?? '').toString(),
      conditionText: (map['conditionText'] ?? '').toString(),
      rewardType: (map['rewardType'] ?? StampRewardType.custom).toString(),
      rewardItemId: (map['rewardItemId'] ?? '').toString(),
      rewardItemName: (map['rewardItemName'] ?? '').toString(),
      rewardTitle: (map['rewardTitle'] ?? '').toString(),
      rewardDescription: (map['rewardDescription'] ?? '').toString(),
      backgroundColor: (map['backgroundColor'] ?? '#171A18').toString(),
      gradientColor: (map['gradientColor'] ?? '#45C9A4').toString(),
      gradientEnabled: map['gradientEnabled'] as bool? ?? false,
      accentColor: (map['accentColor'] ?? '#9CE8CF').toString(),
      textColor: (map['textColor'] ?? '#FEFFFC').toString(),
      styleName: (map['styleName'] ?? 'noir').toString(),
      stampShape: (map['stampShape'] ?? 'circle').toString(),
      stampIconType: (map['stampIconType'] ?? 'icon').toString(),
      stampIconValue: (map['stampIconValue'] ?? 'star').toString(),
      imageUrl: (map['imageUrl'] ?? '').toString(),
      imagePlacement: (map['imagePlacement'] ?? 'side').toString(),
      claimLimits: Map<String, dynamic>.from(map['claimLimits'] as Map? ?? const {'perUser': null, 'perDay': null}),
      creditCostPerWeek: _readInt(map['creditCostPerWeek'], fallback: 2),
      status: (map['status'] ?? StampCardStatus.draft).toString(),
      isActive: map['isActive'] as bool? ?? false,
      isArchived: map['isArchived'] as bool? ?? false,
      createdAt: _readDateTime(map['createdAt']),
      updatedAt: _readDateTime(map['updatedAt']),
      publishedAt: _readDateTime(map['publishedAt']),
      activatedAt: _readDateTime(map['activatedAt']),
      pausedAt: _readDateTime(map['pausedAt']),
      archivedAt: _readDateTime(map['archivedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'stampCardId': id,
      'merchantId': merchantId,
      'title': title.trim(),
      'subtitle': subtitle.trim(),
      'description': description.trim(),
      'requiredStamps': requiredStamps,
      'conditionType': conditionType,
      'minimumAmount': minimumAmount,
      'requiredItemId': requiredItemId,
      'requiredItemName': requiredItemName,
      'conditionText': conditionText.trim(),
      'rewardType': rewardType,
      'rewardItemId': rewardItemId,
      'rewardItemName': rewardItemName,
      'rewardTitle': rewardTitle.trim(),
      'rewardDescription': rewardDescription.trim(),
      'backgroundColor': backgroundColor,
      'gradientColor': gradientColor,
      'gradientEnabled': gradientEnabled,
      'accentColor': accentColor,
      'textColor': textColor,
      'styleName': styleName,
      'stampShape': stampShape,
      'stampIconType': stampIconType,
      'stampIconValue': stampIconValue,
      'imageUrl': imageUrl,
      'imagePlacement': imagePlacement,
      'claimLimits': claimLimits,
      'creditCostPerWeek': creditCostPerWeek,
      'status': status,
      'isActive': isActive,
      'isArchived': isArchived,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (publishedAt != null) 'publishedAt': Timestamp.fromDate(publishedAt!),
      if (activatedAt != null) 'activatedAt': Timestamp.fromDate(activatedAt!),
      if (pausedAt != null) 'pausedAt': Timestamp.fromDate(pausedAt!),
      if (archivedAt != null) 'archivedAt': Timestamp.fromDate(archivedAt!),
    };
  }

  StampCardModel copyWith({
    String? id,
    String? merchantId,
    String? title,
    String? subtitle,
    String? description,
    int? requiredStamps,
    String? conditionType,
    num? minimumAmount,
    String? requiredItemId,
    String? requiredItemName,
    String? conditionText,
    String? rewardType,
    String? rewardItemId,
    String? rewardItemName,
    String? rewardTitle,
    String? rewardDescription,
    String? backgroundColor,
    String? gradientColor,
    bool? gradientEnabled,
    String? accentColor,
    String? textColor,
    String? styleName,
    String? stampShape,
    String? stampIconType,
    String? stampIconValue,
    String? imageUrl,
    String? imagePlacement,
    Map<String, dynamic>? claimLimits,
    int? creditCostPerWeek,
    String? status,
    bool? isActive,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? publishedAt,
    DateTime? activatedAt,
    DateTime? pausedAt,
    DateTime? archivedAt,
  }) {
    return StampCardModel(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      requiredStamps: requiredStamps ?? this.requiredStamps,
      conditionType: conditionType ?? this.conditionType,
      minimumAmount: minimumAmount ?? this.minimumAmount,
      requiredItemId: requiredItemId ?? this.requiredItemId,
      requiredItemName: requiredItemName ?? this.requiredItemName,
      conditionText: conditionText ?? this.conditionText,
      rewardType: rewardType ?? this.rewardType,
      rewardItemId: rewardItemId ?? this.rewardItemId,
      rewardItemName: rewardItemName ?? this.rewardItemName,
      rewardTitle: rewardTitle ?? this.rewardTitle,
      rewardDescription: rewardDescription ?? this.rewardDescription,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      gradientColor: gradientColor ?? this.gradientColor,
      gradientEnabled: gradientEnabled ?? this.gradientEnabled,
      accentColor: accentColor ?? this.accentColor,
      textColor: textColor ?? this.textColor,
      styleName: styleName ?? this.styleName,
      stampShape: stampShape ?? this.stampShape,
      stampIconType: stampIconType ?? this.stampIconType,
      stampIconValue: stampIconValue ?? this.stampIconValue,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePlacement: imagePlacement ?? this.imagePlacement,
      claimLimits: claimLimits ?? this.claimLimits,
      creditCostPerWeek: creditCostPerWeek ?? this.creditCostPerWeek,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      publishedAt: publishedAt ?? this.publishedAt,
      activatedAt: activatedAt ?? this.activatedAt,
      pausedAt: pausedAt ?? this.pausedAt,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }

  static int _readInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse((value ?? '').toString()) ?? fallback;
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
