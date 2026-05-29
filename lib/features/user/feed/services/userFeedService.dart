import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import '../models/feedPostModel.dart';

const _feed = 'feed';
const _likes = 'likes';
const _users = 'users';
const _likedPosts = 'likedPosts';

class UserFeedService {
  const UserFeedService({
    required this.firestoreService,
    required this.authService,
  });

  final FirestoreService firestoreService;
  final AuthService authService;

  Stream<List<FeedPostModel>> feedStream({String? area, String? shopType}) {
    Query<Map<String, dynamic>> query = firestoreService
        .collection(_feed)
        .where('isActive', isEqualTo: true)
        .where('isArchived', isEqualTo: false)
        .where('isPrivate', isEqualTo: false)
        .orderBy('publishedAt', descending: true);

    return query.snapshots().map((snap) {
      var posts = snap.docs
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
        .document('$_feed/$postId/$_likes/$uid')
        .snapshots()
        .map((doc) => doc.exists);
  }

  Future<void> toggleLike(String postId, bool currentlyLiked) async {
    final uid = authService.currentUser?.uid;
    if (uid == null) return;

    final likePath = '$_feed/$postId/$_likes/$uid';
    final userLikePath = '$_users/$uid/$_likedPosts/$postId';
    final postPath = '$_feed/$postId';

    await FirebaseFirestore.instance.runTransaction((tx) async {
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

  Future<void> incrementViews(String postId) async {
    await firestoreService.updateDocument(
      '$_feed/$postId',
      {'viewsCount': FieldValue.increment(1)},
    );
  }
}
