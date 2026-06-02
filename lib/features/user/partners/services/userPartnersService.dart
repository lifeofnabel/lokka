import 'package:lokka/core/constants/firebasePaths.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/features/user/discover/models/publicMerchantUserModel.dart';

class UserPartnersService {
  const UserPartnersService({required this.firestoreService});

  final FirestoreService firestoreService;

  Stream<List<PublicMerchantUserModel>> partnersStream() {
    return firestoreService
        .collection(FirebasePaths.publicMerchants)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .where((doc) {
                final d = doc.data();
                return (d['isActive'] as bool? ?? false) &&
                    (d['isPublic'] as bool? ?? false);
              })
              .map((doc) => PublicMerchantUserModel.fromMap(
                  {...doc.data(), 'merchantId': doc.id}))
              .toList()
            ..sort((a, b) => a.shopName.compareTo(b.shopName));
          return list;
        });
  }

  Future<PublicMerchantUserModel?> fetchPartnerById(String merchantId) async {
    final doc = await firestoreService
        .document(FirebasePaths.publicMerchant(merchantId))
        .get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;
    if (data['isActive'] != true || data['isPublic'] != true) return null;
    return PublicMerchantUserModel.fromMap({...data, 'merchantId': doc.id});
  }

  /// Loads feed posts and counts (postCount + totalLikes) per merchant.
  /// Returns a map of merchantId → beliebt score.
  Future<Map<String, int>> fetchBeliebtScores() async {
    try {
      // Plain read — filter isActive client-side to avoid index requirements.
      final snap = await firestoreService
          .collection(FirebasePaths.feed)
          .get();

      final scores = <String, int>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['isActive'] != true) continue;
        final merchantId = data['merchantId'] as String? ?? '';
        if (merchantId.isEmpty) continue;
        final likes = (data['likesCount'] as num?)?.toInt() ?? 0;
        scores[merchantId] = (scores[merchantId] ?? 0) + 1 + likes;
      }
      return scores;
    } catch (_) {
      return {};
    }
  }

  /// Loads the user's wallet card merchant IDs.
  Future<Set<String>> fetchWalletIds(String uid) async {
    try {
      final snap = await firestoreService
          .collection(FirebasePaths.userWalletCards(uid))
          .get();
      return snap.docs.map((d) => d.id).toSet();
    } catch (_) {
      return {};
    }
  }
}
