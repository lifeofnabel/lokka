import 'package:cloud_firestore/cloud_firestore.dart';

import '../enums/featureStatus.dart';

class FeatureConfigModel {
  const FeatureConfigModel({
    required this.module,
    required this.status,
    required this.isEnabled,
    this.settings = const {},
    this.updatedAt,
  });

  final String module;
  final FeatureStatus status;
  final bool isEnabled;
  final Map<String, dynamic> settings;
  final DateTime? updatedAt;

  factory FeatureConfigModel.fromMap(Map<String, dynamic> map) {
    return FeatureConfigModel(
      module: map['module'] as String? ?? map['id'] as String? ?? '',
      status: _featureStatus(map['status']),
      isEnabled: map['isEnabled'] as bool? ?? map['enabled'] as bool? ?? false,
      settings: Map<String, dynamic>.from(map['settings'] as Map? ?? {}),
      updatedAt: _date(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'module': module,
      'status': status.name,
      'isEnabled': isEnabled,
      'settings': settings,
      'updatedAt': updatedAt,
    };
  }
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  return DateTime.tryParse(value.toString());
}

FeatureStatus _featureStatus(dynamic value) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) return FeatureStatus.disabled;
  if (raw == 'active') return FeatureStatus.enabled;
  for (final status in FeatureStatus.values) {
    if (status.name == raw) return status;
  }
  return FeatureStatus.disabled;
}
