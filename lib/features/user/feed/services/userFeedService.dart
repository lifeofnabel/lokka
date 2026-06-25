import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lokka/core/constants/firebasePaths.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/features/user/discover/models/publicMerchantUserModel.dart';
import 'package:lokka/features/user/feed/models/commentModel.dart';
import 'package:lokka/features/user/feed/models/feedPostModel.dart';
import 'package:lokka/features/user/feed/models/reviewModel.dart';

class UserFeedService {
  const UserFeedService({
    required this.firestoreService,
    required this.authService,
  });

  final FirestoreService firestoreService;
  final AuthService authService;

  Stream<List<FeedPostModel>> feedStream({String? shopType}) {
    // Single orderBy on auto-indexed field — no composite index needed.
    // isActive / isArchived / isPrivate are filtered client-side.
    return firestoreService
        .collection(FirebasePaths.feed)
        .orderBy('publishedAt', descending: true)
        .snapshots()
        .asyncMap((snap) async {
      final rawPosts = snap.docs
          .where((doc) {
            final d = doc.data();
            return d['isActive'] == true &&
                d['isArchived'] != true &&
                d['isPrivate'] != true;
          })
          .map((doc) => FeedPostModel.fromMap({...doc.data(), 'postId': doc.id}))
          .toList();
      final subscribedMerchantIds = rawPosts.any((post) => post.isForRegulars)
          ? await _walletMerchantIds()
          : <String>{};
      var posts = rawPosts
          .where((post) => _visibleForAudience(post, subscribedMerchantIds))
          .toList();

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

  // ── Kommentare ─────────────────────────────────────────────────────────────

  /// Live-Strom aller Kommentare eines Beitrags (neueste zuletzt, damit der
  /// Verlauf chronologisch wie in einem Chat liest).
  Stream<List<CommentModel>> commentsStream(String postId) {
    return firestoreService
        .collection(FirebasePaths.feedComments(postId))
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) =>
                CommentModel.fromMap({...doc.data(), 'commentId': doc.id}))
            .toList());
  }

  /// Legt einen Kommentar an und erhöht den denormalisierten Zähler atomar.
  Future<void> addComment(String postId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final uid = authService.currentUser?.uid;
    if (uid == null) throw StateError('Bitte einloggen');
    final user = authService.currentUser!;

    final commentRef =
        firestoreService.collection(FirebasePaths.feedComments(postId)).doc();
    final postRef = firestoreService.document(FirebasePaths.feedPost(postId));

    await firestoreService.runTransaction((tx) async {
      tx.set(commentRef, {
        'commentId': commentRef.id,
        'postId': postId,
        'userId': uid,
        'userName': user.displayName ?? user.email ?? 'Anonym',
        'text': trimmed,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(postRef, {'commentsCount': FieldValue.increment(1)});
    });
  }

  /// Löscht einen eigenen Kommentar und verringert den Zähler atomar.
  Future<void> deleteComment(String postId, String commentId) async {
    final uid = authService.currentUser?.uid;
    if (uid == null) return;
    final commentRef =
        firestoreService.document(FirebasePaths.feedComment(postId, commentId));
    final postRef = firestoreService.document(FirebasePaths.feedPost(postId));

    await firestoreService.runTransaction((tx) async {
      final snap = await tx.get(commentRef);
      if (!snap.exists) return;
      tx.delete(commentRef);
      tx.update(postRef, {'commentsCount': FieldValue.increment(-1)});
    });
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
    final post = FeedPostModel.fromMap({...data, 'postId': doc.id});
    final subscribedMerchantIds =
        post.isForRegulars ? await _walletMerchantIds() : <String>{};
    return _visibleForAudience(post, subscribedMerchantIds) ? post : null;
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
    String imageUrl = '',
  }) async {
    final uid = authService.currentUser?.uid;
    if (uid == null) throw StateError('Bitte einloggen');
    final user = authService.currentUser!;
    // Doc-ID = uid ⇒ eine editierbare Rezension pro Nutzer je Beitrag.
    await firestoreService.setDocument(FirebasePaths.feedReview(postId, uid), {
      'reviewId': uid,
      'postId': postId,
      'merchantId': merchantId,
      'userId': uid,
      'userName': user.displayName ?? user.email ?? 'Anonym',
      'rating': rating,
      'text': text.trim(),
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete the signed-in user's own review for a post (doc id == uid, so the
  /// rules allow it). No-op when not signed in.
  Future<void> deleteReview(String postId) async {
    final uid = authService.currentUser?.uid;
    if (uid == null) return;
    await firestoreService.document(FirebasePaths.feedReview(postId, uid)).delete();
  }

  Future<ReviewModel?> myReview(String postId) async {
    final uid = authService.currentUser?.uid;
    if (uid == null) return null;
    final doc = await firestoreService
        .document(FirebasePaths.feedReview(postId, uid))
        .get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;
    return ReviewModel.fromMap({...data, 'reviewId': doc.id});
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

  /// Meldet einen Beitrag (schreibt nach `contentReports`, nur Admin/Console
  /// liest). Gleiche Datenform wie `UserDiscoverService.reportPost`, hier als
  /// schlanker Passthrough, damit Feed/Profil keinen zweiten Service brauchen.
  Future<void> reportPost({
    required String postId,
    required String reason,
    String? merchantId,
  }) async {
    final uid = authService.currentUser?.uid;
    final ref =
        firestoreService.collection(FirebasePaths.contentReports).doc();
    await firestoreService.setDocument(FirebasePaths.contentReport(ref.id), {
      'reportId': ref.id,
      'postId': postId,
      'merchantId': merchantId ?? '',
      'userId': uid ?? '',
      'reason': reason,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> incrementViews(String postId) async {
    await firestoreService.updateDocument(
      FirebasePaths.feedPost(postId),
      {'viewsCount': FieldValue.increment(1)},
    );
  }

  Future<void> incrementClicks(String postId) async {
    await firestoreService.updateDocument(
      FirebasePaths.feedPost(postId),
      {'clicksCount': FieldValue.increment(1)},
    );
  }

  /// Loads liked posts (in 10-id `whereIn` chunks, not N reads) together with
  /// each post's `likedAt` timestamp, so the UI can filter by when it was liked
  /// (today / yesterday / last 7 days / month). Newest first.
  Future<List<LikedFeedPost>> fetchLikedEntries() async {
    final uid = authService.currentUser?.uid;
    if (uid == null) return [];

    final likedSnap = await firestoreService
        .collection(FirebasePaths.userLikedPosts(uid))
        .orderBy('likedAt', descending: true)
        .get();
    final orderedIds = likedSnap.docs.map((doc) => doc.id).toList();
    if (orderedIds.isEmpty) return [];

    final likedAtById = <String, DateTime?>{
      for (final doc in likedSnap.docs)
        doc.id: _likedTs(doc.data()['likedAt']),
    };

    final byId = <String, FeedPostModel>{};
    for (var i = 0; i < orderedIds.length; i += 10) {
      final end = (i + 10 < orderedIds.length) ? i + 10 : orderedIds.length;
      final chunk = orderedIds.sublist(i, end);
      final snap = await firestoreService
          .collection(FirebasePaths.feed)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        byId[doc.id] = FeedPostModel.fromMap({...doc.data(), 'postId': doc.id});
      }
    }

    return [
      for (final id in orderedIds)
        if (byId[id] != null)
          LikedFeedPost(post: byId[id]!, likedAt: likedAtById[id]),
    ];
  }

  Future<Set<String>> _walletMerchantIds() async {
    final uid = authService.currentUser?.uid;
    if (uid == null) return <String>{};
    final snapshot =
        await firestoreService.collection(FirebasePaths.userWalletCards(uid)).get();
    return snapshot.docs
        .map((doc) => (doc.data()['merchantId'] as String?) ?? doc.id)
        .where((merchantId) => merchantId.trim().isNotEmpty)
        .toSet();
  }

  bool _visibleForAudience(
    FeedPostModel post,
    Set<String> subscribedMerchantIds,
  ) {
    if (!post.isForRegulars) return true;
    return subscribedMerchantIds.contains(post.merchantId);
  }
}

DateTime? _likedTs(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

/// A liked feed post together with the moment the user liked it.
class LikedFeedPost {
  const LikedFeedPost({required this.post, required this.likedAt});

  final FeedPostModel post;
  final DateTime? likedAt;
}
