import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lokka/core/constants/firebasePaths.dart';
import 'package:lokka/core/models/appUserModel.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/services/localCacheService.dart';

class UserProfileService {
  const UserProfileService({
    required this.firestoreService,
    required this.authService,
    required this.cacheService,
  });

  final FirestoreService firestoreService;
  final AuthService authService;
  final LocalCacheService cacheService;

  String? get _uid => authService.currentUser?.uid;

  Stream<AppUserModel?> profileStream() {
    final uid = _uid;
    if (uid == null) return Stream.value(null);
    return _cachedProfileStream(uid);
  }

  Stream<AppUserModel?> _cachedProfileStream(String uid) async* {
    final cached = await cacheService.readMap('user.profile.$uid');
    if (cached != null) {
      yield AppUserModel.fromMap(cached);
    }
    yield* firestoreService
        .document(FirebasePaths.user(uid))
        .snapshots()
        .asyncMap((doc) async {
      if (!doc.exists || doc.data() == null) return null;
      final data = doc.data()!;
      final user = AppUserModel.fromMap(data);
      await cacheService.writeMap('user.profile.$uid', user.toMap());
      return user;
    });
  }

  Future<int> walletCount() async {
    final uid = _uid;
    if (uid == null) return 0;
    final snap = await firestoreService
        .collection(FirebasePaths.userWalletCards(uid))
        .get();
    return snap.docs.length;
  }

  Future<int> rewardsCount() async {
    final uid = _uid;
    if (uid == null) return 0;
    final snap = await firestoreService
        .collection(FirebasePaths.userAvailableRewards(uid))
        .get();
    return snap.docs.length;
  }

  Future<int> couponsCount() async {
    final uid = _uid;
    if (uid == null) return 0;
    final snap = await firestoreService
        .collection(FirebasePaths.userCoupons(uid))
        .get();
    return snap.docs.length;
  }

  Future<void> updatePersonalData(Map<String, dynamic> data) async {
    final uid = _uid;
    if (uid == null) return;
    await firestoreService.updateDocument(
      FirebasePaths.user(uid),
      {...data, 'updatedAt': FieldValue.serverTimestamp()},
    );
  }

  Future<void> updatePhoneVerified(String phone) async {
    final uid = _uid;
    if (uid == null) return;
    await firestoreService.updateDocument(
      FirebasePaths.user(uid),
      {
        'phone': phone,
        'phoneVerified': true,
        'phoneVerifiedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> updateProfileImage(String imageUrl) async {
    final uid = _uid;
    if (uid == null) return;
    await firestoreService.updateDocument(
      FirebasePaths.user(uid),
      {'profileImageUrl': imageUrl, 'updatedAt': FieldValue.serverTimestamp()},
    );
  }

  Future<void> updateCoverGradient(int index) async {
    final uid = _uid;
    if (uid == null) return;
    await firestoreService.updateDocument(
      FirebasePaths.user(uid),
      {'profileCoverGradient': index, 'updatedAt': FieldValue.serverTimestamp()},
    );
  }

  Future<void> createDeletionRequest() async {
    final uid = _uid;
    if (uid == null) return;
    final ref =
        firestoreService.collection(FirebasePaths.accountDeletionRequests).doc();
    await firestoreService.setDocument(FirebasePaths.accountDeletionRequest(ref.id), {
      'requestId': ref.id,
      'userId': uid,
      'requestedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }

  Future<void> signOut() => authService.signOut();
}
