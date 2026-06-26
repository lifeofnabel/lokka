import 'package:cloud_firestore/cloud_firestore.dart';

/// A single comment on a feed post (`feed/{postId}/comments/{commentId}`).
///
/// Comments use auto-generated document ids (a user may write several), so
/// ownership is tracked via [userId] rather than the doc id.
class CommentModel {
  const CommentModel({
    required this.commentId,
    required this.postId,
    required this.userId,
    required this.userName,
    required this.text,
    this.createdAt,
  });

  final String commentId;
  final String postId;
  final String userId;
  final String userName;
  final String text;
  final DateTime? createdAt;

  factory CommentModel.fromMap(Map<String, dynamic> map) {
    return CommentModel(
      commentId: map['commentId'] as String? ?? '',
      postId: map['postId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      userName: map['userName'] as String? ?? '',
      text: map['text'] as String? ?? '',
      createdAt: _tsToDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'commentId': commentId,
      'postId': postId,
      'userId': userId,
      'userName': userName,
      'text': text,
      'createdAt': createdAt,
    };
  }
}

DateTime? _tsToDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is Timestamp) return v.toDate();
  return DateTime.tryParse(v.toString());
}
