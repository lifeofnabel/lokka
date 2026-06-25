import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lokka/core/constants/firebasePaths.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/features/user/discover/models/publicMerchantUserModel.dart';
import 'package:lokka/features/user/reviews/models/merchantRating.dart';

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

  /// Resolves a public profile by its custom [handle] (slug). Single-field
  /// equality query → auto-indexed, no composite index needed.
  Future<PublicMerchantUserModel?> fetchPartnerByHandle(String handle) async {
    final slug = handle.trim().toLowerCase();
    if (slug.isEmpty) return null;
    final snap = await firestoreService
        .collection(FirebasePaths.publicMerchants)
        .where('handle', isEqualTo: slug)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    final data = doc.data();
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

  /// Lädt aggregierte Partner-Ratings in 10er-Blöcken (whereIn).
  Future<Map<String, MerchantRating>> fetchMerchantRatings(
    Iterable<String> ids,
  ) async {
    final list = ids.where((id) => id.isNotEmpty).toSet().toList();
    if (list.isEmpty) return {};
    final result = <String, MerchantRating>{};
    try {
      for (var i = 0; i < list.length; i += 10) {
        final end = (i + 10 < list.length) ? i + 10 : list.length;
        final chunk = list.sublist(i, end);
        final snap = await firestoreService
            .collection(FirebasePaths.merchantRatings)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snap.docs) {
          final d = doc.data();
          result[doc.id] = MerchantRating(
            avg: (d['avg'] as num?)?.toDouble() ?? 0,
            count: (d['count'] as num?)?.toInt() ?? 0,
          );
        }
      }
    } catch (_) {
      // best-effort — Social Proof darf die Liste nie blockieren
    }
    return result;
  }
}
