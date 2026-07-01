import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:geolocator/geolocator.dart';

/// Single client gateway to the server-authored stamp logic (Cloud Functions,
/// region europe-west1). The client is never trusted for stamp validity — every
/// method here just forwards to a callable that enforces CMAC/counter/cooldown/
/// ownership server-side.
class StampFunctionsService {
  StampFunctionsService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  /// Merchant QR-scan door: add [delta] stamps to a scanned customer's card.
  Future<StampTapResult> merchantStampCustomer({
    required String customerUid,
    required String cardId,
    int delta = 1,
  }) async {
    final res = await _call('merchantStampCustomer', {
      'customerUid': customerUid,
      'cardId': cardId,
      'delta': delta,
    });
    return StampTapResult.fromMap(res);
  }

  /// Merchant marks an earned reward as used.
  Future<void> merchantRedeemReward({
    required String customerUid,
    required String rewardId,
  }) async {
    await _call('merchantRedeemReward', {
      'customerUid': customerUid,
      'rewardId': rewardId,
    });
  }

  /// Customer adds one of a store's stamp cards to their own wallet (zero
  /// progress). Idempotent server-side — calling twice never resets a real card.
  Future<StampTapResult> userAddStampCard({
    required String merchantId,
    required String cardId,
  }) async {
    final res = await _call('userAddStampCard', {
      'merchantId': merchantId,
      'cardId': cardId,
    });
    return StampTapResult.fromMap(res);
  }

  /// Customer removes ONE of their own stamps (decrement, never below 0). Earned
  /// rewards are never clawed back.
  Future<StampTapResult> userRemoveStamp({
    required String merchantId,
    required String cardId,
  }) async {
    final res = await _call('userRemoveStamp', {
      'merchantId': merchantId,
      'cardId': cardId,
    });
    return StampTapResult.fromMap(res);
  }

  /// Customer unfollows a merchant → server wipes ALL their data for that store
  /// (wallet card, stamp + points progress, earned rewards, follower record).
  Future<void> userUnfollowMerchant({required String merchantId}) async {
    await _call('userUnfollowMerchant', {'merchantId': merchantId});
  }

  /// Customer converts a completed card into earned reward(s).
  Future<ClaimResult> claimReward({
    required String merchantId,
    required String cardId,
  }) async {
    final res = await _call('claimReward', {
      'merchantId': merchantId,
      'cardId': cardId,
    });
    return ClaimResult.fromMap(res);
  }

  /// Bind an owner-minted static stick (scanned bind code
  /// `lokka-stick-a:<id>:<claim>`) to [cardId]. The tag already carries the
  /// fixed redeem link (written by the owner in the workshop), so binding is all
  /// that's needed; the returned token is the same identity link.
  Future<StaticStick> claimStaticStick({
    required String stickId,
    required String claimToken,
    required String cardId,
  }) async {
    final res = await _call('claimStaticStick', {
      'stickId': stickId,
      'claimToken': claimToken,
      'cardId': cardId,
    });
    return StaticStick(
      stickId: (res['stickId'] ?? '').toString(),
      token: (res['token'] ?? '').toString(),
    );
  }

  /// Path A tap — a customer redeems a static stick link. Forwards best-effort
  /// location (only if already granted) for the optional geofence.
  Future<StampTapResult> redeemStaticStamp({
    required String token,
    (double, double)? location,
  }) async {
    final loc = location ?? await _bestEffortLocation();
    final res = await _call('redeemStaticStamp', {
      'token': token,
      if (loc != null) 'lat': loc.$1,
      if (loc != null) 'lng': loc.$2,
    });
    return StampTapResult.fromMap(res);
  }

  /// Merchant loads a scanned customer's cards/progress/rewards.
  Future<MerchantCustomerView> merchantLoadCustomer(String customerUid) async {
    final res = await _call('merchantLoadCustomer', {'customerUid': customerUid});
    return MerchantCustomerView.fromMap(res);
  }

  Future<Map<String, dynamic>> _call(
      String name, Map<String, dynamic> data) async {
    try {
      final callable = _functions.httpsCallable(name);
      final result = await callable.call<Object?>(data);
      final raw = result.data;
      if (raw is Map) return Map<String, dynamic>.from(raw);
      return <String, dynamic>{};
    } on FirebaseFunctionsException catch (e) {
      // Make the real cause visible in the browser console (devtools) — the
      // on-screen text alone has been hiding it.
      developer.log(
        'callable "$name" failed → code=${e.code} message=${e.message} details=${e.details}',
        name: 'stamp',
      );
      rethrow;
    } catch (e) {
      developer.log('callable "$name" error → $e', name: 'stamp');
      rethrow;
    }
  }

  /// Returns (lat, lng) ONLY if location permission is already granted and a fix
  /// is obtained quickly. Never prompts and never throws — geofence is opt-in.
  Future<(double, double)?> _bestEffortLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null; // do not prompt — opt-in only
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      ).timeout(const Duration(seconds: 6));
      return (pos.latitude, pos.longitude);
    } catch (_) {
      return null; // any failure → skip geofence silently
    }
  }

  /// Actively asks for a FRESH, high-accuracy device location — prompts for the
  /// permission if needed (unlike [_bestEffortLocation], which never prompts).
  /// Used by the "update my location" retry on the "too far" error so a merchant
  /// who just walked into range can re-stamp immediately. Returns null if the
  /// user denies permission or no fix is obtained.
  Future<(double, double)?> requestFreshLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      ).timeout(const Duration(seconds: 12));
      return (pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }
}

/// The short error code for display/diagnosis (e.g. "unavailable", "internal",
/// "permission-denied"). Turns the opaque generic toast into something we can
/// actually act on. Returns '' when there's no meaningful code.
String stampErrorCode(Object error) {
  if (error is FirebaseFunctionsException) {
    final msg = error.message ?? '';
    // Our intended, already-translated errors carry a stamp/ message → no code.
    if (msg.startsWith('stamp/') && !msg.startsWith('stamp/server-error')) {
      return '';
    }
    return error.code;
  }
  return '';
}

/// Maps a Cloud Functions error to a stable, translatable message key. The
/// server throws HttpsError with codes like `stamp/cooldown` in `message`.
String stampErrorKey(Object error) {
  if (error is FirebaseFunctionsException) {
    final msg = error.message ?? '';
    if (msg.startsWith('stamp/')) return 'merchant.stampScan.err.${msg.substring(6)}';
    switch (error.code) {
      case 'unauthenticated':
        return 'merchant.stampScan.err.login-required';
      case 'resource-exhausted':
        return 'merchant.stampScan.err.cooldown';
      case 'unavailable':
        return 'merchant.stampScan.err.offline';
      // No `stamp/...` message → the callable itself is unreachable (backend not
      // deployed / wrong region / transient). Make it actionable, not vague.
      case 'not-found':
      case 'internal':
      case 'deadline-exceeded':
        return 'merchant.stampScan.err.unreachable';
    }
  }
  return 'merchant.stampScan.err.generic';
}

/// A freshly created static stick: the signed token to write onto the tag plus
/// its server id. The merchant writes `https://<app>/s/<token>`.
class StaticStick {
  const StaticStick({required this.stickId, required this.token});
  final String stickId;
  final String token;
}

class StampTapResult {
  const StampTapResult({
    required this.currentStamps,
    required this.maxStamps,
    required this.completed,
    required this.added,
    this.cardId = '',
    this.merchantId = '',
  });

  final int currentStamps;
  final int maxStamps;
  final bool completed;
  final int added;
  final String cardId;
  final String merchantId;

  factory StampTapResult.fromMap(Map<String, dynamic> map) {
    return StampTapResult(
      currentStamps: (map['currentStamps'] as num?)?.toInt() ?? 0,
      maxStamps: (map['maxStamps'] as num?)?.toInt() ?? 0,
      completed: map['completed'] == true,
      added: (map['added'] as num?)?.toInt() ?? 0,
      cardId: (map['cardId'] ?? '').toString(),
      merchantId: (map['merchantId'] ?? '').toString(),
    );
  }
}

class ClaimResult {
  const ClaimResult({required this.rewards, required this.reset});

  final List<ClaimedReward> rewards;
  final bool reset;

  factory ClaimResult.fromMap(Map<String, dynamic> map) {
    final list = (map['rewards'] as List?) ?? const [];
    return ClaimResult(
      rewards: list
          .whereType<Map>()
          .map((e) => ClaimedReward.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      reset: map['reset'] == true,
    );
  }
}

class ClaimedReward {
  const ClaimedReward({required this.id, required this.label, required this.type});

  final String id;
  final String label;
  final String type;

  factory ClaimedReward.fromMap(Map<String, dynamic> map) => ClaimedReward(
        id: (map['id'] ?? '').toString(),
        label: (map['label'] ?? '').toString(),
        type: (map['type'] ?? '').toString(),
      );
}

/// Combined view a merchant sees after scanning a customer's wallet QR.
class MerchantCustomerView {
  const MerchantCustomerView({
    required this.customerName,
    required this.walletCode,
    required this.cards,
    required this.progress,
    required this.rewards,
    this.photoUrl = '',
    this.postalCode = '',
    this.followedAt,
    this.interests = const [],
  });

  final String customerName;
  final String walletCode;
  final List<ScanCard> cards;
  final Map<String, ScanProgress> progress; // by cardId
  final List<ScanReward> rewards;

  /// Basic customer info for the page header (shared by the user on follow).
  final String photoUrl;
  final String postalCode;
  final DateTime? followedAt;
  final List<String> interests;

  factory MerchantCustomerView.fromMap(Map<String, dynamic> map) {
    final customer = Map<String, dynamic>.from(map['customer'] as Map? ?? {});
    final cards = ((map['cards'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => ScanCard.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    final progress = <String, ScanProgress>{};
    for (final p in ((map['progress'] as List?) ?? const []).whereType<Map>()) {
      final sp = ScanProgress.fromMap(Map<String, dynamic>.from(p));
      progress[sp.cardId] = sp;
    }
    final rewards = ((map['rewards'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => ScanReward.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    final followedMs = (customer['followedAt'] as num?)?.toInt();
    return MerchantCustomerView(
      customerName: (customer['name'] ?? '').toString(),
      walletCode: (customer['walletCode'] ?? '').toString(),
      cards: cards,
      progress: progress,
      rewards: rewards,
      photoUrl: (customer['photoUrl'] ?? '').toString(),
      postalCode: (customer['postalCode'] ?? '').toString(),
      followedAt: followedMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(followedMs),
      interests: ((customer['interests'] as List?) ?? const [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList(),
    );
  }
}

class ScanCard {
  const ScanCard({required this.id, required this.title, required this.maxStamps});
  final String id;
  final String title;
  final int maxStamps;

  factory ScanCard.fromMap(Map<String, dynamic> map) => ScanCard(
        id: (map['id'] ?? '').toString(),
        title: (map['title'] ?? '').toString(),
        maxStamps: (map['maxStamps'] as num?)?.toInt() ?? 0,
      );
}

class ScanProgress {
  const ScanProgress({
    required this.cardId,
    required this.currentStamps,
    required this.stampsRequired,
    required this.status,
  });
  final String cardId;
  final int currentStamps;
  final int stampsRequired;
  final String status;

  bool get isCompleted => status == 'completed' || currentStamps >= stampsRequired;

  factory ScanProgress.fromMap(Map<String, dynamic> map) => ScanProgress(
        cardId: (map['cardId'] ?? '').toString(),
        currentStamps: (map['currentStamps'] as num?)?.toInt() ?? 0,
        stampsRequired: (map['stampsRequired'] as num?)?.toInt() ?? 0,
        status: (map['status'] ?? 'active').toString(),
      );
}

class ScanReward {
  const ScanReward({
    required this.id,
    required this.cardId,
    required this.label,
    required this.type,
  });
  final String id;
  final String cardId;
  final String label;
  final String type;

  factory ScanReward.fromMap(Map<String, dynamic> map) => ScanReward(
        id: (map['id'] ?? '').toString(),
        cardId: (map['cardId'] ?? '').toString(),
        label: (map['label'] ?? '').toString(),
        type: (map['type'] ?? 'custom').toString(),
      );
}
