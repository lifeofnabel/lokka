import 'package:cloud_firestore/cloud_firestore.dart';

class UserNotificationModel {
  const UserNotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.route,
    this.read = false,
    this.createdAt,
  });

  final String id;
  final String type; // 'stamp' | 'coupon' | 'general'
  final String title;
  final String body;
  final String? route;
  final bool read;
  final DateTime? createdAt;

  factory UserNotificationModel.fromMap(Map<String, dynamic> map) {
    return UserNotificationModel(
      id: map['id'] as String? ?? '',
      type: map['type'] as String? ?? 'general',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      route: map['route'] as String?,
      read: map['read'] as bool? ?? false,
      createdAt: _date(map['createdAt']),
    );
  }

  static DateTime? _date(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
