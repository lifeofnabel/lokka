import 'package:cloud_firestore/cloud_firestore.dart';

class CouponStatus {
  const CouponStatus._();

  static const draft = 'draft';
  static const active = 'active';
  static const paused = 'paused';
  static const archived = 'archived';
}

class CouponType {
  const CouponType._();

  static const percent = 'percent';
  static const fixed = 'fixed';
  static const freeItem = 'freeItem';
  static const custom = 'custom';
}

class CouponCodeStatus {
  const CouponCodeStatus._();

  static const available = 'available';
  static const used = 'used';
  static const blocked = 'blocked';

  /// Normalisiert eine Status-Map auf genau die übergebenen Codes und mappt
  /// unbekannte/fehlende Werte auf [available].
  static Map<String, String> normalize(
    List<String> codes,
    Map<String, String> statuses,
  ) {
    final result = <String, String>{};
    for (final code in codes) {
      result[code] = switch (statuses[code]) {
        used => used,
        blocked => blocked,
        _ => available,
      };
    }
    return result;
  }
}

class CouponModel {
  const CouponModel({
    required this.id,
    required this.merchantId,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.type,
    required this.valueText,
    required this.codePrefix,
    required this.codes,
    required this.codeStatuses,
    required this.maxUsesPerCode,
    required this.imageUrl,
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
  final String type;
  final String valueText;
  final String codePrefix;
  final List<String> codes;
  final Map<String, String> codeStatuses;
  final int maxUsesPerCode;
  final String imageUrl;
  final String status;
  final bool isActive;
  final bool isArchived;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? publishedAt;
  final DateTime? activatedAt;
  final DateTime? pausedAt;
  final DateTime? archivedAt;

  bool get isDraft => status == CouponStatus.draft;
  bool get isLive => status == CouponStatus.active && isActive;
  bool get isPaused => status == CouponStatus.paused;
  bool get isArchivedCoupon => status == CouponStatus.archived || isArchived;

  factory CouponModel.empty({required String merchantId}) {
    return CouponModel(
      id: '',
      merchantId: merchantId,
      title: '',
      subtitle: '',
      description: '',
      type: CouponType.percent,
      valueText: '',
      codePrefix: 'LK',
      codes: const [],
      codeStatuses: const {},
      maxUsesPerCode: 1,
      imageUrl: '',
      status: CouponStatus.draft,
      isActive: false,
      isArchived: false,
    );
  }

  factory CouponModel.fromMap(Map<String, dynamic> map) {
    return CouponModel(
      id: (map['id'] ?? map['couponId'] ?? '').toString(),
      merchantId: (map['merchantId'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      subtitle: (map['subtitle'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      type: (map['type'] ?? CouponType.percent).toString(),
      valueText: (map['valueText'] ?? '').toString(),
      codePrefix: (map['codePrefix'] ?? 'LK').toString(),
      codes: _readStringList(map['codes']),
      codeStatuses: _readStatusMap(map['codeStatuses']),
      maxUsesPerCode: (map['maxUsesPerCode'] as num?)?.toInt() ?? 1,
      imageUrl: (map['imageUrl'] ?? '').toString(),
      status: (map['status'] ?? CouponStatus.draft).toString(),
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
    // Timestamp-Felder bewusst NICHT pauschal serialisieren: bei merge:true würde
    // ein null-Wert ein bereits gesetztes Server-Datum überschreiben. Nur bereits
    // gesetzte (nicht-null) Timestamps durchreichen.
    return {
      'id': id,
      'couponId': id,
      'merchantId': merchantId,
      'title': title.trim(),
      'subtitle': subtitle.trim(),
      'description': description.trim(),
      'type': type,
      'valueText': valueText.trim(),
      'codePrefix': codePrefix.trim().toUpperCase(),
      'codes': codes,
      'codeStatuses': codeStatuses,
      'maxUsesPerCode': maxUsesPerCode,
      'imageUrl': imageUrl,
      'status': status,
      'isActive': isActive,
      'isArchived': isArchived,
      if (createdAt != null) 'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
      if (publishedAt != null) 'publishedAt': publishedAt,
      if (activatedAt != null) 'activatedAt': activatedAt,
      if (pausedAt != null) 'pausedAt': pausedAt,
      if (archivedAt != null) 'archivedAt': archivedAt,
    };
  }

  CouponModel copyWith({
    String? id,
    String? merchantId,
    String? title,
    String? subtitle,
    String? description,
    String? type,
    String? valueText,
    String? codePrefix,
    List<String>? codes,
    Map<String, String>? codeStatuses,
    int? maxUsesPerCode,
    String? imageUrl,
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
    return CouponModel(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      type: type ?? this.type,
      valueText: valueText ?? this.valueText,
      codePrefix: codePrefix ?? this.codePrefix,
      codes: codes ?? this.codes,
      codeStatuses: codeStatuses ?? this.codeStatuses,
      maxUsesPerCode: maxUsesPerCode ?? this.maxUsesPerCode,
      imageUrl: imageUrl ?? this.imageUrl,
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
}

List<String> _readStringList(dynamic value) {
  if (value is Iterable) {
    return value.map((item) => item.toString()).where((item) => item.isNotEmpty).toList();
  }
  return const [];
}

Map<String, String> _readStatusMap(dynamic value) {
  if (value is Map) {
    return value.map(
      (key, status) => MapEntry(key.toString(), status.toString()),
    );
  }
  return const {};
}

DateTime? _readDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
