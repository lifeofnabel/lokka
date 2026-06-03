import 'package:cloud_firestore/cloud_firestore.dart';

class DisplayRoutine {
  const DisplayRoutine({
    required this.id,
    required this.title,
    required this.deviceIds,
    required this.layoutIds,
    required this.days,
    required this.startTime,
    required this.endTime,
    required this.isActive,
    required this.animation,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final List<String> deviceIds;
  final List<String> layoutIds;
  final List<int> days; // 1=Mon … 7=Sun
  final String startTime; // 'HH:MM'
  final String endTime;
  final bool isActive;
  final String animation;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory DisplayRoutine.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>? ?? {};
    return DisplayRoutine.fromMap(map, id: doc.id);
  }

  factory DisplayRoutine.fromMap(Map<String, dynamic> map, {String id = ''}) {
    List<String> toStrings(dynamic raw) =>
        raw is List ? raw.map((e) => e.toString()).toList() : [];
    List<int> toInts(dynamic raw) =>
        raw is List ? raw.whereType<num>().map((e) => e.toInt()).toList() : [];

    return DisplayRoutine(
      id: id.isNotEmpty ? id : (map['id'] as String? ?? ''),
      title: map['title'] as String? ?? '',
      deviceIds: toStrings(map['deviceIds']),
      layoutIds: toStrings(map['layoutIds']),
      days: toInts(map['days']),
      startTime: map['startTime'] as String? ?? '08:00',
      endTime: map['endTime'] as String? ?? '20:00',
      isActive: map['isActive'] as bool? ?? false,
      animation: map['animation'] as String? ?? 'fade',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'deviceIds': deviceIds,
        'layoutIds': layoutIds,
        'days': days,
        'startTime': startTime,
        'endTime': endTime,
        'isActive': isActive,
        'animation': animation,
        'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  String get daysLabel {
    const names = ['', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    if (days.isEmpty) return '–';
    return days.map((d) => d >= 1 && d <= 7 ? names[d] : '').join(', ');
  }
}
