import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  const ReviewModel({
    required this.reviewId,
    required this.postId,
    required this.merchantId,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.text,
    this.imageUrl = '',
    this.createdAt,
    this.updatedAt,
  });

  final String reviewId;
  final String postId;
  final String merchantId;
  final String userId;
  final String userName;
  final double rating;
  final String text;
  final String imageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ReviewModel.fromMap(Map<String, dynamic> map) {
    return ReviewModel(
      reviewId: map['reviewId'] as String? ?? '',
      postId: map['postId'] as String? ?? '',
      merchantId: map['merchantId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      userName: map['userName'] as String? ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      text: map['text'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? '',
      createdAt: _tsToDate(map['createdAt']),
      updatedAt: _tsToDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reviewId': reviewId,
      'postId': postId,
      'merchantId': merchantId,
      'userId': userId,
      'userName': userName,
      'rating': rating,
      'text': text,
      'imageUrl': imageUrl,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

DateTime? _tsToDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is Timestamp) return v.toDate();
  return DateTime.tryParse(v.toString());
}
