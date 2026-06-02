import 'package:cloud_firestore/cloud_firestore.dart';

class PointsStatus {
  const PointsStatus._();

  static const draft = 'draft';
  static const active = 'active';
  static const paused = 'paused';
  static const archived = 'archived';
}

class PointsRewardType {
  const PointsRewardType._();

  static const item = 'item';
  static const discount = 'discount';
  static const custom = 'custom';
}

class PointsSystemModel {
  const PointsSystemModel({
    required this.id,
    required this.merchantId,
    required this.title,
    required this.description,
    required this.pointsPerEuro,
    required this.status,
    required this.isActive,
    required this.isArchived,
    required this.existingParticipantsCanContinue,
    required this.creditCostPerWeek,
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
  final String description;
  final num pointsPerEuro;
  final String status;
  final bool isActive;
  final bool isArchived;
  final bool existingParticipantsCanContinue;
  final int creditCostPerWeek;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? publishedAt;
  final DateTime? activatedAt;
  final DateTime? pausedAt;
  final DateTime? archivedAt;

  bool get isDraft => status == PointsStatus.draft;
  bool get isLive => status == PointsStatus.active && isActive;
  bool get isPaused => status == PointsStatus.paused;
  bool get isArchivedSystem => status == PointsStatus.archived || isArchived;

  factory PointsSystemModel.empty({required String merchantId}) {
    return PointsSystemModel(
      id: '',
      merchantId: merchantId,
      title: 'Lokka Punkte',
      description: '',
      pointsPerEuro: 1,
      status: PointsStatus.draft,
      isActive: false,
      isArchived: false,
      existingParticipantsCanContinue: true,
      creditCostPerWeek: 1,
    );
  }

  factory PointsSystemModel.fromMap(Map<String, dynamic> map) {
    return PointsSystemModel(
      id: (map['id'] ?? map['pointsSystemId'] ?? '').toString(),
      merchantId: (map['merchantId'] ?? '').toString(),
      title: (map['title'] ?? map['name'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      pointsPerEuro: _readNum(map['pointsPerEuro'], fallback: 1),
      status: (map['status'] ?? PointsStatus.draft).toString(),
      isActive: map['isActive'] as bool? ?? false,
      isArchived: map['isArchived'] as bool? ?? false,
      existingParticipantsCanContinue:
          map['existingParticipantsCanContinue'] as bool? ?? true,
      creditCostPerWeek: _readInt(map['creditCostPerWeek'], fallback: 1),
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
      'pointsSystemId': id,
      'merchantId': merchantId,
      'title': title.trim(),
      'name': title.trim(),
      'description': description.trim(),
      'pointsPerEuro': pointsPerEuro,
      'status': status,
      'isActive': isActive,
      'isArchived': isArchived,
      'existingParticipantsCanContinue': existingParticipantsCanContinue,
      'creditCostPerWeek': creditCostPerWeek,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (publishedAt != null) 'publishedAt': Timestamp.fromDate(publishedAt!),
      if (activatedAt != null) 'activatedAt': Timestamp.fromDate(activatedAt!),
      if (pausedAt != null) 'pausedAt': Timestamp.fromDate(pausedAt!),
      if (archivedAt != null) 'archivedAt': Timestamp.fromDate(archivedAt!),
    };
  }

  PointsSystemModel copyWith({
    String? id,
    String? merchantId,
    String? title,
    String? description,
    num? pointsPerEuro,
    String? status,
    bool? isActive,
    bool? isArchived,
    bool? existingParticipantsCanContinue,
    int? creditCostPerWeek,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? publishedAt,
    DateTime? activatedAt,
    DateTime? pausedAt,
    DateTime? archivedAt,
  }) {
    return PointsSystemModel(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      title: title ?? this.title,
      description: description ?? this.description,
      pointsPerEuro: pointsPerEuro ?? this.pointsPerEuro,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      isArchived: isArchived ?? this.isArchived,
      existingParticipantsCanContinue:
          existingParticipantsCanContinue ?? this.existingParticipantsCanContinue,
      creditCostPerWeek: creditCostPerWeek ?? this.creditCostPerWeek,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      publishedAt: publishedAt ?? this.publishedAt,
      activatedAt: activatedAt ?? this.activatedAt,
      pausedAt: pausedAt ?? this.pausedAt,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }
}

class PointsRewardModel {
  const PointsRewardModel({
    required this.id,
    required this.merchantId,
    required this.title,
    required this.description,
    required this.rewardType,
    required this.requiredPoints,
    required this.rewardItemId,
    required this.rewardItemName,
    required this.discountText,
    required this.imageUrl,
    required this.status,
    required this.isActive,
    required this.isArchived,
    required this.creditCostPerWeek,
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
  final String description;
  final String rewardType;
  final int requiredPoints;
  final String rewardItemId;
  final String rewardItemName;
  final String discountText;
  final String imageUrl;
  final String status;
  final bool isActive;
  final bool isArchived;
  final int creditCostPerWeek;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? publishedAt;
  final DateTime? activatedAt;
  final DateTime? pausedAt;
  final DateTime? archivedAt;

  bool get isDraft => status == PointsStatus.draft;
  bool get isLive => status == PointsStatus.active && isActive;
  bool get isPaused => status == PointsStatus.paused;
  bool get isArchivedReward => status == PointsStatus.archived || isArchived;

  factory PointsRewardModel.empty({required String merchantId}) {
    return PointsRewardModel(
      id: '',
      merchantId: merchantId,
      title: '',
      description: '',
      rewardType: PointsRewardType.custom,
      requiredPoints: 100,
      rewardItemId: '',
      rewardItemName: '',
      discountText: '',
      imageUrl: '',
      status: PointsStatus.draft,
      isActive: false,
      isArchived: false,
      creditCostPerWeek: 1,
    );
  }

  factory PointsRewardModel.fromMap(Map<String, dynamic> map) {
    return PointsRewardModel(
      id: (map['id'] ?? map['rewardId'] ?? '').toString(),
      merchantId: (map['merchantId'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      rewardType: (map['rewardType'] ?? PointsRewardType.custom).toString(),
      requiredPoints: _readInt(map['requiredPoints'], fallback: 100),
      rewardItemId: (map['rewardItemId'] ?? '').toString(),
      rewardItemName: (map['rewardItemName'] ?? '').toString(),
      discountText: (map['discountText'] ?? '').toString(),
      imageUrl: (map['imageUrl'] ?? '').toString(),
      status: (map['status'] ?? PointsStatus.draft).toString(),
      isActive: map['isActive'] as bool? ?? false,
      isArchived: map['isArchived'] as bool? ?? false,
      creditCostPerWeek: _readInt(map['creditCostPerWeek'], fallback: 1),
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
      'rewardId': id,
      'merchantId': merchantId,
      'title': title.trim(),
      'description': description.trim(),
      'rewardType': rewardType,
      'requiredPoints': requiredPoints,
      'rewardItemId': rewardItemId,
      'rewardItemName': rewardItemName,
      'discountText': discountText.trim(),
      'imageUrl': imageUrl,
      'status': status,
      'isActive': isActive,
      'isArchived': isArchived,
      'creditCostPerWeek': creditCostPerWeek,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (publishedAt != null) 'publishedAt': Timestamp.fromDate(publishedAt!),
      if (activatedAt != null) 'activatedAt': Timestamp.fromDate(activatedAt!),
      if (pausedAt != null) 'pausedAt': Timestamp.fromDate(pausedAt!),
      if (archivedAt != null) 'archivedAt': Timestamp.fromDate(archivedAt!),
    };
  }

  PointsRewardModel copyWith({
    String? id,
    String? merchantId,
    String? title,
    String? description,
    String? rewardType,
    int? requiredPoints,
    String? rewardItemId,
    String? rewardItemName,
    String? discountText,
    String? imageUrl,
    String? status,
    bool? isActive,
    bool? isArchived,
    int? creditCostPerWeek,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? publishedAt,
    DateTime? activatedAt,
    DateTime? pausedAt,
    DateTime? archivedAt,
  }) {
    return PointsRewardModel(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      title: title ?? this.title,
      description: description ?? this.description,
      rewardType: rewardType ?? this.rewardType,
      requiredPoints: requiredPoints ?? this.requiredPoints,
      rewardItemId: rewardItemId ?? this.rewardItemId,
      rewardItemName: rewardItemName ?? this.rewardItemName,
      discountText: discountText ?? this.discountText,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      isArchived: isArchived ?? this.isArchived,
      creditCostPerWeek: creditCostPerWeek ?? this.creditCostPerWeek,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      publishedAt: publishedAt ?? this.publishedAt,
      activatedAt: activatedAt ?? this.activatedAt,
      pausedAt: pausedAt ?? this.pausedAt,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }
}

int _readInt(dynamic value, {required int fallback}) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse((value ?? '').toString()) ?? fallback;
}

num _readNum(dynamic value, {required num fallback}) {
  if (value is num) return value;
  return num.tryParse((value ?? '').toString()) ?? fallback;
}

DateTime? _readDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
