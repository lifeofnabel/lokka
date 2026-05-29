import 'package:lokka/core/constants/firebasePaths.dart';
import 'package:lokka/core/models/appUserModel.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';

class UserProfileService {
  const UserProfileService({
    required this.firestoreService,
    required this.authService,
  });

  final FirestoreService firestoreService;
  final AuthService authService;

  String? get _uid => authService.currentUser?.uid;

  Stream<AppUserModel?> profileStream() {
    final uid = _uid;
    if (uid == null) return Stream.value(null);
    return firestoreService
        .document('${FirebasePaths.users}/$uid')
        .snapshots()
        .map((doc) => doc.exists && doc.data() != null
            ? AppUserModel.fromMap(doc.data()!)
            : null);
  }

  Future<int> walletCount() async {
    final uid = _uid;
    if (uid == null) return 0;
    final snap = await firestoreService
        .collection(
            '${FirebasePaths.users}/$uid/${FirebasePaths.walletCards}')
        .get();
    return snap.docs.length;
  }

  Future<int> rewardsCount() async {
    final uid = _uid;
    if (uid == null) return 0;
    final snap = await firestoreService
        .collection(
            '${FirebasePaths.users}/$uid/${FirebasePaths.availableRewards}')
        .get();
    return snap.docs.length;
  }

  Future<int> couponsCount() async {
    final uid = _uid;
    if (uid == null) return 0;
    final snap = await firestoreService
        .collection('${FirebasePaths.users}/$uid/${FirebasePaths.coupons}')
        .get();
    return snap.docs.length;
  }

  Future<void> signOut() => authService.signOut();
}
