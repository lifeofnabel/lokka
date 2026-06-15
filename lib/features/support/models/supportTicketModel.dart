import 'package:cloud_firestore/cloud_firestore.dart';

class SupportTicketModel {
  const SupportTicketModel({
    required this.ticketId,
    required this.merchantId,
    required this.merchantName,
    required this.merchantEmail,
    required this.type,
    required this.message,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.lastMessageAt,
  });

  final String ticketId;
  final String merchantId;
  final String merchantName;
  final String merchantEmail;
  final String type;
  final String message;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastMessageAt;

  factory SupportTicketModel.fromMap(Map<String, dynamic> map) {
    return SupportTicketModel(
      ticketId: map['ticketId'] as String? ?? '',
      merchantId: map['merchantId'] as String? ?? '',
      merchantName: map['merchantName'] as String? ?? '',
      merchantEmail: map['merchantEmail'] as String? ?? '',
      type: map['type'] as String? ?? '',
      message: map['message'] as String? ?? '',
      status: map['status'] as String? ?? 'open',
      createdAt: _date(map['createdAt']),
      updatedAt: _date(map['updatedAt']),
      lastMessageAt: _date(map['lastMessageAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ticketId': ticketId,
      'merchantId': merchantId,
      'merchantName': merchantName,
      'merchantEmail': merchantEmail,
      'type': type,
      'message': message,
      'status': status,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'lastMessageAt': lastMessageAt,
    };
  }
}

class SupportMessageModel {
  const SupportMessageModel({
    required this.messageId,
    required this.senderRole,
    required this.senderId,
    required this.text,
    this.createdAt,
  });

  final String messageId;
  final String senderRole;
  final String senderId;
  final String text;
  final DateTime? createdAt;

  factory SupportMessageModel.fromMap(Map<String, dynamic> map) {
    return SupportMessageModel(
      messageId: map['messageId'] as String? ?? '',
      senderRole: map['senderRole'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      text: map['text'] as String? ?? '',
      createdAt: _date(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'senderRole': senderRole,
      'senderId': senderId,
      'text': text,
      'createdAt': createdAt,
    };
  }
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  return DateTime.tryParse(value.toString());
}
