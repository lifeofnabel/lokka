import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lokka/core/constants/firebasePaths.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/services/localCacheService.dart';
import 'package:lokka/features/user/discover/models/publicMerchantUserModel.dart';
import '../models/walletCardModel.dart';
import '../models/stampProgressModel.dart';
import '../models/pointsProgressModel.dart';
import '../models/couponModel.dart';
import '../models/availableRewardModel.dart';

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

    final prefix = _buildPrefix(merchant.shopName);
    final number = _hashNumber(uid, merchant.merchantId);
    final walletCode = '$prefix-$number';

    await firestoreService.setDocument(
      FirebasePaths.userWalletCard(uid, merchant.merchantId),
      {
        'merchantId': merchant.merchantId,
        'merchantName': merchant.shopName,
        'merchantLogoUrl': merchant.logoUrl,
        'merchantArea': merchant.area,
        'merchantShopType': merchant.shopType,
        'walletCode': walletCode,
        'walletNumber': number,
        'prefix': prefix,
        'joinedAt': FieldValue.serverTimestamp(),
        'status': 'active',
        'hasStampCards': false,
        'hasPoints': false,
        'hasCoupons': false,
        'lastActivityAt': FieldValue.serverTimestamp(),
      },
      merge: false,
    );
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

  String _buildPrefix(String shopName) {
    final cleaned = shopName.replaceAll(RegExp(r'[^a-zA-Z]'), '');
    if (cleaned.length >= 2) return cleaned.substring(0, 2).toUpperCase();
    if (cleaned.length == 1) return cleaned.toUpperCase();
    final fallback = shopName.replaceAll(RegExp(r'\s'), '');
    return fallback.substring(0, fallback.length.clamp(0, 2)).toUpperCase();
  }

  /// Deterministic 5-digit number derived from uid+merchantId.
  /// Same inputs always produce the same code.
  String _hashNumber(String uid, String merchantId) {
    final input = uid + merchantId;
    int hash = 5381;
    for (final c in input.codeUnits) {
      hash = ((hash << 5) + hash + c) & 0x7FFFFFFF;
    }
    return (10000 + (hash % 90000)).toString();
  }
}
