import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lokka/core/constants/firebasePaths.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/features/user/discover/models/publicMerchantUserModel.dart';
import 'package:lokka/features/user/feed/models/feedPostModel.dart';
import 'package:lokka/features/user/feed/models/reviewModel.dart';

class UserFeedService {
  const UserFeedService({
    required this.firestoreService,
    required this.authService,
  });

  final FirestoreService firestoreService;
  final AuthService authService;

  Stream<List<FeedPostModel>> feedStream({String? area, String? shopType}) {
    // Single orderBy on auto-indexed field — no composite index needed.
    // isActive / isArchived / isPrivate are filtered client-side.
    return firestoreService
        .collection(FirebasePaths.feed)
        .orderBy('publishedAt', descending: true)
        .snapshots()
        .map((snap) {
      var posts = snap.docs
          .where((doc) {
            final d = doc.data();
            return d['isActive'] == true &&
                d['isArchived'] != true &&
                d['isPrivate'] != true;
          })
          .map((doc) => FeedPostModel.fromMap({...doc.data(), 'postId': doc.id}))
          .toList();

      if (area != null && area.isNotEmpty) {
        posts = posts.where((p) => p.merchantArea == area).toList();
      }
      if (shopType != null && shopType.isNotEmpty) {
        posts = posts.where((p) => p.merchantShopType == shopType).toList();
      }
      return posts;
    });
  }

  Stream<bool> likedStream(String postId) {
    final uid = authService.currentUser?.uid;
    if (uid == null) return Stream.value(false);
    return firestoreService
        .document(FirebasePaths.feedLike(postId, uid))
        .snapshots()
        .map((doc) => doc.exists);
  }

  Stream<List<ReviewModel>> reviewsStream(String postId) {
    return firestoreService
        .collection(FirebasePaths.feedReviews(postId))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ReviewModel.fromMap({...doc.data(), 'reviewId': doc.id}))
            .toList());
  }

  Future<FeedPostModel?> fetchPostById(String postId) async {
    final doc = await firestoreService.document(FirebasePaths.feedPost(postId)).get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;
    if (data['isActive'] != true ||
        data['isArchived'] == true ||
        data['isPrivate'] == true) {
      return null;
    }
    return FeedPostModel.fromMap({...data, 'postId': doc.id});
  }

  Future<void> toggleLike(String postId, bool currentlyLiked) async {
    final uid = authService.currentUser?.uid;
    if (uid == null) return;

    final likePath = FirebasePaths.feedLike(postId, uid);
    final userLikePath = FirebasePaths.userLikedPost(uid, postId);
    final postPath = FirebasePaths.feedPost(postId);

    await firestoreService.runTransaction((tx) async {
      final postRef = firestoreService.document(postPath);
      final likeRef = firestoreService.document(likePath);
      final userRef = firestoreService.document(userLikePath);

      if (currentlyLiked) {
        tx.delete(likeRef);
        tx.delete(userRef);
        tx.update(postRef, {'likesCount': FieldValue.increment(-1)});
      } else {
        tx.set(likeRef, {'uid': uid, 'likedAt': FieldValue.serverTimestamp()});
        tx.set(userRef, {'postId': postId, 'likedAt': FieldValue.serverTimestamp()});
        tx.update(postRef, {'likesCount': FieldValue.increment(1)});
      }
    });
  }

  Future<void> submitReview({
    required String postId,
    required String merchantId,
    required double rating,
    required String text,
  }) async {
    final uid = authService.currentUser?.uid;
    if (uid == null) throw StateError('Bitte einloggen');
    final user = authService.currentUser!;
    final ref = firestoreService.collection(FirebasePaths.feedReviews(postId)).doc();
    await firestoreService.setDocument(FirebasePaths.feedReview(postId, ref.id), {
      'reviewId': ref.id,
      'postId': postId,
      'merchantId': merchantId,
      'userId': uid,
      'userName': user.displayName ?? user.email ?? 'Anonym',
      'rating': rating,
      'text': text.trim(),
      'imageUrl': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<double?> averageRatingFor(String postId) async {
    final snap = await firestoreService
        .collection(FirebasePaths.feedReviews(postId))
        .get();
    final ratings = snap.docs
        .map((doc) => (doc.data()['rating'] as num?)?.toDouble())
        .whereType<double>()
        .where((r) => r >= 1 && r <= 5)
        .toList();
    if (ratings.isEmpty) return null;
    return ratings.reduce((a, b) => a + b) / ratings.length;
  }

  Future<PublicMerchantUserModel?> fetchMerchantById(String merchantId) async {
    final doc = await firestoreService
        .document(FirebasePaths.publicMerchant(merchantId))
        .get();
    if (!doc.exists || doc.data() == null) return null;
    return PublicMerchantUserModel.fromMap({...doc.data()!, 'merchantId': doc.id});
  }

  Future<void> incrementViews(String postId) async {
    await firestoreService.updateDocument(
      FirebasePaths.feedPost(postId),
      {'viewsCount': FieldValue.increment(1)},
    );
  }
}
