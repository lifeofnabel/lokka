import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lokka/core/constants/firebasePaths.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/features/user/notifications/models/userNotificationModel.dart';

class UserNotificationService {
  const UserNotificationService({
    required this.firestoreService,
    required this.authService,
  });

  final FirestoreService firestoreService;
  final AuthService authService;

  String? get _uid => authService.currentUser?.uid;

  Stream<List<UserNotificationModel>> notificationsStream() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return firestoreService
        .collection(FirebasePaths.userNotifications(uid))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                UserNotificationModel.fromMap({...d.data(), 'id': d.id}))
            .toList());
  }

  Future<void> markRead(String id) async {
    final uid = _uid;
    if (uid == null) return;
    await firestoreService.setDocument(
      FirebasePaths.userNotification(uid, id),
      {'read': true},
    );
  }

  Future<void> markAllRead(Iterable<String> ids) async {
    final uid = _uid;
    if (uid == null) return;
    final batch = firestoreService.batch();
    for (final id in ids) {
      batch.set(
        firestoreService.document(FirebasePaths.userNotification(uid, id)),
        {'read': true},
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  /// Erzeugt Nudges clientseitig (kostenlos, ohne Server). Deduppt über feste
  /// Doc-IDs, damit nichts mehrfach erscheint. Echtes Push folgt in Sprint 7.
  Future<void> generateNudges() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await Future.wait([_stampNudges(uid), _couponNudges(uid)]);
    } catch (_) {
      // Nudges sind best-effort — Fehler dürfen die App nicht stören.
    }
  }

  Future<void> _stampNudges(String uid) async {
    final snap = await firestoreService
        .collection(FirebasePaths.userStampProgress(uid))
        .get();
    for (final doc in snap.docs) {
      final d = doc.data();
      if ((d['status'] as String? ?? 'active') == 'claimed') continue;
      final current = (d['currentStamps'] as num?)?.toInt() ?? 0;
      final required = (d['stampsRequired'] as num?)?.toInt() ?? 0;
      if (required <= 0) continue;
      final remaining = required - current;
      if (remaining < 1 || remaining > 2) continue;
      final merchant = (d['merchantName'] as String?) ?? 'deinem Partner';
      final cardId = d['stampCardId'] as String? ?? doc.id;
      await _createIfAbsent(
        uid,
        'stamp_${cardId}_$current',
        type: 'stamp',
        title: remaining == 1
            ? 'Nur noch 1 Stempel! 🎉'
            : 'Nur noch $remaining Stempel!',
        body: 'Bei $merchant fehlt dir nicht mehr viel bis zur Belohnung.',
        route: '/user/wallet',
      );
    }
  }

  Future<void> _couponNudges(String uid) async {
    final now = DateTime.now();
    final snap =
        await firestoreService.collection(FirebasePaths.userCoupons(uid)).get();
    for (final doc in snap.docs) {
      final d = doc.data();
      if ((d['status'] as String? ?? 'active') != 'active') continue;
      final expiresAt = _date(d['expiresAt']);
      if (expiresAt == null) continue;
      final days = expiresAt.difference(now).inDays;
      if (days < 0 || days > 3) continue;
      final merchant = (d['merchantName'] as String?) ?? 'einem Partner';
      final couponId = d['couponId'] as String? ?? doc.id;
      await _createIfAbsent(
        uid,
        'coupon_$couponId',
        type: 'coupon',
        title: 'Dein Coupon läuft bald ab ⏳',
        body: 'Dein Coupon bei $merchant ist nur noch kurz gültig.',
        route: '/user/wallet',
      );
    }
  }

  Future<void> _createIfAbsent(
    String uid,
    String id, {
    required String type,
    required String title,
    required String body,
    String? route,
  }) async {
    final path = FirebasePaths.userNotification(uid, id);
    final existing = await firestoreService.document(path).get();
    if (existing.exists) return;
    await firestoreService.setDocument(path, {
      'type': type,
      'title': title,
      'body': body,
      'route': route,
      'read': false,
      'pushed': false, // wird vom Cloudflare-Worker nach Versand auf true gesetzt
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static DateTime? _date(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
