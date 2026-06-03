import 'package:cloud_firestore/cloud_firestore.dart';

class DisplayLog {
  const DisplayLog({
    required this.id,
    required this.type,
    required this.deviceId,
    required this.layoutId,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String type; // 'start' | 'stop' | 'error' | 'pair' | 'command'
  final String deviceId;
  final String layoutId;
  final String message;
  final DateTime? createdAt;

  factory DisplayLog.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>? ?? {};
    return DisplayLog.fromMap(map, id: doc.id);
  }

  factory DisplayLog.fromMap(Map<String, dynamic> map, {String id = ''}) {
    return DisplayLog(
      id: id.isNotEmpty ? id : (map['id'] as String? ?? ''),
      type: map['type'] as String? ?? 'info',
      deviceId: map['deviceId'] as String? ?? '',
      layoutId: map['layoutId'] as String? ?? '',
      message: map['message'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'deviceId': deviceId,
        'layoutId': layoutId,
        'message': message,
        'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      };
}
