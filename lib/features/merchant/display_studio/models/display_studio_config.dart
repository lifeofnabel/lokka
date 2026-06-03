import 'package:cloud_firestore/cloud_firestore.dart';

class DisplayStudioConfig {
  const DisplayStudioConfig({
    required this.isEnabled,
    required this.layoutCount,
    required this.displayCount,
    required this.routineCount,
    required this.defaultAnimation,
    required this.updatedAt,
  });

  final bool isEnabled;
  final int layoutCount;
  final int displayCount;
  final int routineCount;
  final String defaultAnimation;
  final DateTime? updatedAt;

  static DisplayStudioConfig empty() => const DisplayStudioConfig(
        isEnabled: false,
        layoutCount: 0,
        displayCount: 0,
        routineCount: 0,
        defaultAnimation: 'fade',
        updatedAt: null,
      );

  factory DisplayStudioConfig.fromMap(Map<String, dynamic> map) {
    return DisplayStudioConfig(
      isEnabled: map['isEnabled'] as bool? ?? false,
      layoutCount: (map['layoutCount'] as num?)?.toInt() ?? 0,
      displayCount: (map['displayCount'] as num?)?.toInt() ?? 0,
      routineCount: (map['routineCount'] as num?)?.toInt() ?? 0,
      defaultAnimation: map['defaultAnimation'] as String? ?? 'fade',
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'isEnabled': isEnabled,
        'layoutCount': layoutCount,
        'displayCount': displayCount,
        'routineCount': routineCount,
        'defaultAnimation': defaultAnimation,
        'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      };

  Map<String, dynamic> toInitMap() => {
        'isEnabled': true,
        'layoutCount': 0,
        'displayCount': 0,
        'routineCount': 0,
        'defaultAnimation': 'fade',
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
