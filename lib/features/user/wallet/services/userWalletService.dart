import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lokka/core/constants/firebasePaths.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/services/localCacheService.dart';
import 'package:lokka/features/merchant/stamps/models/stampCardModel.dart';
import 'package:lokka/features/user/discover/models/publicMerchantUserModel.dart';
import '../models/walletCardModel.dart';
import '../models/stampProgressModel.dart';
import '../models/pointsProgressModel.dart';
import '../models/couponModel.dart';
import '../models/availableRewardModel.dart';
import '../models/earnedRewardModel.dart';
import '../utils/walletCode.dart';

class UserWalletService {
  const UserWalletService({
    required this.firestoreService,
    required this.authService,
    required this.cacheService,
  });

  final FirestoreService firestoreService;
  final AuthService authService;
  final LocalCacheService cacheService;

  String? get _uid => authService.currentUser?.uid;

  Stream<List<WalletCardModel>> walletCardsStream() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    return _cachedWalletCardsStream(uid);
  }

  Stream<List<WalletCardModel>> _cachedWalletCardsStream(String uid) async* {
    final cached = await cacheService.readMapList('user.walletCards.$uid');
    if (cached != null) {
      yield cached.map(WalletCardModel.fromMap).toList();
    }
    yield* firestoreService
        .collection(FirebasePaths.userWalletCards(uid))
        .orderBy('joinedAt', descending: true)
        .snapshots()
        .asyncMap((snap) async {
      final cards = snap.docs.map((d) => WalletCardModel.fromMap(d.data())).toList();
      await cacheService.writeMapList(
        'user.walletCards.$uid',
        cards.map((card) => card.toMap()).toList(),
      );
      return cards;
    });
  }

  Future<bool> isInWallet(String merchantId) async {
    final uid = _uid;
    if (uid == null) return false;
    final doc = await firestoreService.readDocument(
      FirebasePaths.userWalletCard(uid, merchantId),
    );
    return doc != null;
  }

  Future<void> addToWallet(PublicMerchantUserModel merchant) async {
    final uid = _uid;
    if (uid == null) return;

    // Stable identity: keep the existing code on re-follow, never re-roll it.
    final existing = await firestoreService.readDocument(
      FirebasePaths.userWalletCard(uid, merchant.merchantId),
    );
    final existingCode = (existing?['walletCode'] as String?) ?? '';
    final code = WalletCode.isValid(existingCode)
        ? existingCode
        : await _uniqueCode(uid, merchant.merchantId);

    // Treue-Verfügbarkeit aus der ECHTEN Quelle ableiten: das früher genutzte
    // `merchant.featuresPublic` wird nie gepflegt (immer leer) → hätte die
    // Wallet-Karte fälschlich ohne Stempel/Punkte/Coupons markiert. Stattdessen
    // live Stempelkarten + aktive Feature-Configs lesen.
    final loyalty = await Future.wait([
      loadActiveStampCards(merchant.merchantId),
      loadPointsEnabled(merchant.merchantId),
      _isFeatureEnabled(merchant.merchantId, 'coupons'),
    ]);
    final hasStampCards = (loyalty[0] as List).isNotEmpty;
    final hasPoints = loyalty[1] as bool;
    final hasCoupons = loyalty[2] as bool;
    await firestoreService.setDocument(
      FirebasePaths.userWalletCard(uid, merchant.merchantId),
      {
        'merchantId': merchant.merchantId,
        'merchantName': merchant.shopName,
        'merchantLogoUrl': merchant.logoUrl,
        'merchantCoverUrl': merchant.coverUrl,
        'merchantCity': merchant.displayCity,
        'merchantShopType': merchant.shopType,
        'merchantOrigin': merchant.origins.isNotEmpty ? merchant.origins.first : '',
        'merchantLat': merchant.lat,
        'merchantLng': merchant.lng,
        'walletCode': code,
        'walletNumber': code,
        'prefix': code.isNotEmpty ? code.substring(0, 1) : '',
        'joinedAt': existing?['joinedAt'] ?? FieldValue.serverTimestamp(),
        'status': 'active',
        'hasStampCards': hasStampCards,
        'hasPoints': hasPoints,
        'hasCoupons': hasCoupons,
        'lastActivityAt': FieldValue.serverTimestamp(),
      },
      merge: true,
    );

    // Denormalise a follower record into the merchant's customer index so the
    // merchant can see who follows them (+ a bit of profile info) AND resolve a
    // typed wallet code → uid at the counter. The user writes only their OWN
    // record (doc id == uid). Non-fatal: following must still work even if this
    // write is denied (e.g. rules not yet deployed).
    await _registerFollower(uid, merchant, walletCode: code);
  }

  /// Backfills the merchant-side follower record for a merchant the user
  /// ALREADY follows (e.g. followed before this feature existed — the follow
  /// button is then hidden, so [addToWallet] won't run again). Idempotent:
  /// skips the write once a follower record exists. Safe to call on page open.
  Future<void> ensureFollowerRecord(PublicMerchantUserModel merchant) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final existing = await firestoreService.readDocument(
          FirebasePaths.merchantCustomer(merchant.merchantId, uid));
      if (existing != null && existing['isFollower'] == true) return;
    } catch (_) {
      // Own-record read may be denied until the rule is (re)deployed — fall
      // through and write the record anyway so existing followers backfill.
    }
    await _registerFollower(uid, merchant);
  }

  /// Writes/refreshes the current user's denormalised follower record under
  /// `merchants/{mid}/customers/{uid}` with the basic profile info the user
  /// chooses to share by following (name, photo, postal code, interests).
  Future<void> _registerFollower(
      String uid, PublicMerchantUserModel merchant,
      {String walletCode = ''}) async {
    try {
      final profile =
          await firestoreService.readDocument(FirebasePaths.user(uid)) ??
              const <String, dynamic>{};
      // Preserve the original follow date when we can read our own record.
      // Isolated guard: the user may have no read permission on the merchant's
      // customer doc — a denied read must NEVER block the follower write below.
      dynamic existingFollowedAt;
      try {
        final existing = await firestoreService.readDocument(
            FirebasePaths.merchantCustomer(merchant.merchantId, uid));
        existingFollowedAt = existing?['followedAt'];
      } catch (_) {
        existingFollowedAt = null;
      }
      final firstName = (profile['firstName'] ?? '').toString();
      final lastName = (profile['lastName'] ?? '').toString();
      final name = [firstName, lastName]
          .where((part) => part.trim().isNotEmpty)
          .join(' ');
      List<String> stringList(dynamic value) => value is Iterable
          ? value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
          : const <String>[];
      await firestoreService.setDocument(
        FirebasePaths.merchantCustomer(merchant.merchantId, uid),
        {
          'uid': uid,
          'firstName': firstName,
          'lastName': lastName,
          'name': name,
          'profileImageUrl': (profile['profileImageUrl'] ?? '').toString(),
          'postalCode': (profile['postalCode'] ?? '').toString(),
          'interestOrigins': stringList(profile['interestOrigins']),
          'interestCategories': stringList(profile['interestCategories']),
          'isFollower': true,
          'usedSystems': FieldValue.arrayUnion(['follower']),
          // Lets the merchant scanner resolve a typed code → this uid. Only
          // written when known (the backfill path leaves the existing value).
          if (walletCode.isNotEmpty) 'walletCode': walletCode,
          'followedAt': existingFollowedAt ?? FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        merge: true,
      );
    } catch (_) {
      // Swallow: the wallet add already succeeded; the merchant-side index is
      // best-effort.
    }
  }

  /// Live single wallet card (so the expanded view reflects newly added cards).
  Stream<WalletCardModel?> walletCardStream(String merchantId) {
    final uid = _uid;
    if (uid == null) return Stream.value(null);
    return firestoreService
        .document(FirebasePaths.userWalletCard(uid, merchantId))
        .snapshots()
        .map((d) {
      final data = d.data();
      return data == null ? null : WalletCardModel.fromMap(data);
    });
  }

  /// Add ONE stamp card to the user's wallet (client write to the user-owned
  /// walletCards doc — no Cloud Function needed). Only added cards are shown in
  /// the wallet. Idempotent via arrayUnion.
  Future<void> addStampCardToWallet(String merchantId, String cardId) async {
    final uid = _uid;
    if (uid == null) return;
    await firestoreService.setDocument(
      FirebasePaths.userWalletCard(uid, merchantId),
      {
        'addedStampCardIds': FieldValue.arrayUnion([cardId]),
        'hasStampCards': true,
        'lastActivityAt': FieldValue.serverTimestamp(),
      },
      merge: true,
    );
  }

  /// Remove ONE stamp card from the user's wallet (client write to the
  /// user-owned walletCards doc). The server-authored progress doc is kept, so
  /// re-adding the card later restores the collected stamps.
  Future<void> removeStampCardFromWallet(
      String merchantId, String cardId) async {
    final uid = _uid;
    if (uid == null) return;
    await firestoreService.setDocument(
      FirebasePaths.userWalletCard(uid, merchantId),
      {
        'addedStampCardIds': FieldValue.arrayRemove([cardId]),
        'lastActivityAt': FieldValue.serverTimestamp(),
      },
      merge: true,
    );
  }

  /// The set of stamp-card ids the user already added for a merchant.
  Future<Set<String>> loadAddedStampCardIds(String merchantId) async {
    final uid = _uid;
    if (uid == null) return <String>{};
    final doc = await firestoreService
        .readDocument(FirebasePaths.userWalletCard(uid, merchantId));
    return (doc?['addedStampCardIds'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toSet() ??
        <String>{};
  }

  /// Full public merchant profile (for the store header + quick actions:
  /// route / call / hours / social).
  Future<PublicMerchantUserModel?> loadMerchant(String merchantId) async {
    final doc = await firestoreService.readDocument(
      FirebasePaths.publicMerchant(merchantId),
    );
    if (doc == null) return null;
    return PublicMerchantUserModel.fromMap({...doc, 'merchantId': merchantId});
  }

  /// Active stamp cards a merchant currently offers (public read). Sorted by
  /// creation so the pager order is stable. Drafts/paused/archived are excluded.
  Future<List<StampCardModel>> loadActiveStampCards(String merchantId) async {
    final snap = await firestoreService
        .collection(FirebasePaths.merchantStampCards(merchantId))
        .get();
    final cards = snap.docs
        .map((d) => StampCardModel.fromMap({...d.data(), 'id': d.id}))
        .where((c) => c.isLive)
        .toList()
      ..sort((a, b) =>
          (a.createdAt ?? DateTime(2100)).compareTo(b.createdAt ?? DateTime(2100)));
    return cards.take(3).toList(); // a store offers up to 3 cards
  }

  /// Whether the store announced a points system (drives the reserved points
  /// placeholder + the system switch). The points *logic* is built later; this
  /// only reflects the merchant feature flag.
  Future<bool> loadPointsEnabled(String merchantId) =>
      _isFeatureEnabled(merchantId, 'pointsSystems');

  Future<bool> _isFeatureEnabled(String merchantId, String module) async {
    try {
      final doc = await firestoreService.readDocument(
        FirebasePaths.merchantFeatureConfig(merchantId, module),
      );
      if (doc == null) return false;
      return doc['isEnabled'] == true || doc['status'] == 'enabled';
    } catch (_) {
      return false;
    }
  }

  /// A dictatable code unique within THIS user's wallet. Deterministic from
  /// (uid, merchantId); on the rare collision with another of the user's cards
  /// it regenerates with an increasing salt (edge case #8).
  Future<String> _uniqueCode(String uid, String merchantId) async {
    // A fresh nonce per generation → the code is RE-rolled on every (re)follow
    // (a deterministic uid|merchantId seed would hand back the same code after
    // an unfollow). Stable while followed because addToWallet reuses the stored
    // code; only a fresh follow (no stored card) reaches here.
    final seed = '$uid|$merchantId|${DateTime.now().microsecondsSinceEpoch}';
    final taken = await _existingCodes(uid, except: merchantId);
    for (var salt = 0; salt < 64; salt++) {
      final code = WalletCode.generate(seed, salt: salt);
      if (!taken.contains(code)) return code;
    }
    // Pathological fallback (should never happen): salt by time.
    return WalletCode.generate(seed, salt: DateTime.now().microsecondsSinceEpoch);
  }

  Future<Set<String>> _existingCodes(String uid, {required String except}) async {
    try {
      final snap = await firestoreService
          .collection(FirebasePaths.userWalletCards(uid))
          .get();
      return snap.docs
          .where((d) => d.id != except)
          .map((d) => (d.data()['walletCode'] as String?) ?? '')
          .where((c) => c.isNotEmpty)
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Stream<List<StampProgressModel>> stampProgressStream() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    return firestoreService
        .collection(FirebasePaths.userStampProgress(uid))
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => StampProgressModel.fromMap(d.data())).toList());
  }

  Stream<List<StampProgressModel>> stampProgressByMerchantStream(
      String merchantId) {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    return firestoreService
        .collection(FirebasePaths.userStampProgress(uid))
        .where('merchantId', isEqualTo: merchantId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => StampProgressModel.fromMap(d.data())).toList());
  }

  Stream<List<PointsProgressModel>> pointsProgressStream() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    return firestoreService
        .collection(FirebasePaths.userPointsProgress(uid))
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => PointsProgressModel.fromMap(d.data())).toList());
  }

  Stream<PointsProgressModel?> pointsProgressByMerchantStream(
      String merchantId) {
    final uid = _uid;
    if (uid == null) return Stream.value(null);
    return firestoreService
        .collection(FirebasePaths.userPointsProgress(uid))
        .where('merchantId', isEqualTo: merchantId)
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isEmpty
            ? null
            : PointsProgressModel.fromMap(snap.docs.first.data()));
  }

  /// Earned rewards for one merchant (status `earned`). Filtered client-side so
  /// no composite index is required.
  Stream<List<EarnedRewardModel>> earnedRewardsByMerchantStream(
      String merchantId) {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    return firestoreService
        .collection(FirebasePaths.userEarnedRewards(uid))
        .where('merchantId', isEqualTo: merchantId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => EarnedRewardModel.fromMap({...d.data(), 'id': d.id}))
            .where((r) => r.isEarned)
            .toList());
  }

  Stream<List<CouponModel>> couponsStream() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    return firestoreService
        .collection(FirebasePaths.userCoupons(uid))
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => CouponModel.fromMap(d.data())).toList());
  }

  Stream<List<AvailableRewardModel>> availableRewardsStream() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    return firestoreService
        .collection(FirebasePaths.userAvailableRewards(uid))
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => AvailableRewardModel.fromMap(d.data())).toList());
  }

}
