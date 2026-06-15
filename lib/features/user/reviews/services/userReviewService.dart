import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lokka/core/constants/firebasePaths.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/features/user/feed/models/reviewModel.dart';

/// Partner-(Shop-)Bewertungen. Eine editierbare Rezension pro Nutzer
/// (Doc-ID = uid). Hält das aggregierte `merchantRatings/{id}` aktuell.
class UserReviewService {
  const UserReviewService({
    required this.firestoreService,
    required this.authService,
  });

  final FirestoreService firestoreService;
  final AuthService authService;

  Stream<List<ReviewModel>> merchantReviewsStream(String merchantId) {
    return firestoreService
        .collection(FirebasePaths.merchantReviews(merchantId))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ReviewModel.fromMap({...d.data(), 'reviewId': d.id}))
            .toList());
  }

  Future<ReviewModel?> myMerchantReview(String merchantId) async {
    final uid = authService.currentUser?.uid;
    if (uid == null) return null;
    final doc = await firestoreService
        .document(FirebasePaths.merchantReview(merchantId, uid))
        .get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;
    return ReviewModel.fromMap({...data, 'reviewId': doc.id});
  }

  Future<void> submitMerchantReview({
    required String merchantId,
    required double rating,
    required String text,
    String imageUrl = '',
  }) async {
    final user = authService.currentUser;
    final uid = user?.uid;
    if (uid == null) throw StateError('Bitte einloggen');
    await firestoreService.setDocument(
      FirebasePaths.merchantReview(merchantId, uid),
      {
        'reviewId': uid,
        'merchantId': merchantId,
        'postId': '',
        'userId': uid,
        'userName': user?.displayName ?? user?.email ?? 'Anonym',
        'rating': rating,
        'text': text.trim(),
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
    await _recomputeRating(merchantId);
  }

  Future<void> _recomputeRating(String merchantId) async {
    final snap = await firestoreService
        .collection(FirebasePaths.merchantReviews(merchantId))
        .get();
    final ratings = snap.docs
        .map((d) => (d.data()['rating'] as num?)?.toDouble())
        .whereType<double>()
        .where((r) => r >= 1 && r <= 5)
        .toList();
    final count = ratings.length;
    final avg = count == 0 ? 0.0 : ratings.reduce((a, b) => a + b) / count;
    await firestoreService.setDocument(
      FirebasePaths.merchantRating(merchantId),
      {
        'merchantId': merchantId,
        'avg': avg,
        'count': count,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }
}
