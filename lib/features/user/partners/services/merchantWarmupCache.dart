import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lokka/core/constants/firebasePaths.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/features/user/feed/models/feedPostModel.dart';
import 'package:lokka/features/user/wallet/services/userWalletService.dart';

/// Vorab geladene ("warme") Partner-Profil-Daten, keyed by merchantId. Wird
/// angestoßen, sobald ein Beitrag-Detail geöffnet wird (die merchantId ist
/// dort schon vor dem eigentlichen Profil-Öffnen bekannt) – die
/// wahrscheinlichsten nächsten Schritte sind "zurück" oder "Profil ansehen",
/// also lohnt es sich, dessen Daten im Hintergrund schon zu holen. Rein
/// passiver In-Memory-Cache, kein Provider/State nötig.
class MerchantWarmupEntry {
  const MerchantWarmupEntry({
    required this.isInWallet,
    required this.posts,
    required this.stampsEnabled,
    required this.pointsEnabled,
    required this.fetchedAt,
  });

  final bool isInWallet;
  final List<FeedPostModel> posts;
  final bool stampsEnabled;
  final bool pointsEnabled;
  final DateTime fetchedAt;
}

class MerchantWarmupCache {
  MerchantWarmupCache._();

  static final Map<String, MerchantWarmupEntry> _entries = {};

  /// Liefert einen frischen (< [maxAge] alten) Eintrag oder null.
  static MerchantWarmupEntry? peek(
    String merchantId, {
    Duration maxAge = const Duration(seconds: 60),
  }) {
    final entry = _entries[merchantId];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.fetchedAt) > maxAge) return null;
    return entry;
  }

  /// Stößt das Vorab-Laden an (fire-and-forget, kein UI wartet darauf).
  /// Bewusst OHNE Rating-Burst (wie [UserPartnerDetailPage]) – Bewertungen
  /// lädt die Profilseite selbst fensterweise nach.
  static Future<void> warm(
    String merchantId, {
    required FirestoreService firestoreService,
    required UserWalletService walletService,
  }) async {
    if (merchantId.isEmpty || peek(merchantId) != null) return;
    try {
      final results = await Future.wait([
        walletService.isInWallet(merchantId),
        firestoreService
            .collection(FirebasePaths.feed)
            .where('merchantId', isEqualTo: merchantId)
            .orderBy('publishedAt', descending: true)
            .get(),
        walletService.loadActiveStampCards(merchantId),
        walletService.loadPointsEnabled(merchantId),
      ]);
      final isInWallet = results[0] as bool;
      final snap = results[1] as QuerySnapshot<Map<String, dynamic>>;
      final stampsEnabled = (results[2] as List).isNotEmpty;
      final pointsEnabled = results[3] as bool;
      final posts = snap.docs
          .where((doc) {
            final d = doc.data();
            return d['isArchived'] != true && d['isPrivate'] != true;
          })
          .map((doc) =>
              FeedPostModel.fromMap({...doc.data(), 'postId': doc.id}))
          .toList();
      _entries[merchantId] = MerchantWarmupEntry(
        isInWallet: isInWallet,
        posts: posts,
        stampsEnabled: stampsEnabled,
        pointsEnabled: pointsEnabled,
        fetchedAt: DateTime.now(),
      );
    } catch (_) {
      // Best-effort – schlägt der Warmup fehl, lädt die Profilseite später
      // einfach ganz normal selbst (kein Nutzer-Fehler nötig).
    }
  }
}
