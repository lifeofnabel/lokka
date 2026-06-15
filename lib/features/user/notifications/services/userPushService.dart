import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:lokka/core/config/appConfig.dart';
import 'package:lokka/core/constants/firebasePaths.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';

/// Web-Push (FCM Phase B). Holt Berechtigung + Token, speichert den Token unter
/// `users/{uid}.fcmTokens` und leitet Vorder-/Hintergrund-Nachrichten weiter.
/// Der Versand passiert serverlos über den Cloudflare-Worker (siehe /cloudflare).
class UserPushService {
  UserPushService({
    required this.firestoreService,
    required this.authService,
  });

  final FirestoreService firestoreService;
  final AuthService authService;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _initialized = false;

  /// Berechtigung anfragen, Token speichern, Listener registrieren.
  /// [onForeground] = Nachricht bei offener App, [onOpen] = Tap auf Push.
  Future<void> init({
    required void Function(String title, String body) onForeground,
    required void Function(String? route) onOpen,
  }) async {
    if (_initialized) return;
    _initialized = true;

    try {
      final settings = await _messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      await _refreshToken();
      _messaging.onTokenRefresh.listen(_saveToken);

      FirebaseMessaging.onMessage.listen((message) {
        final n = message.notification;
        if (n != null) {
          onForeground(n.title ?? 'Lokka', n.body ?? '');
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        onOpen(message.data['route'] as String?);
      });

      final initial = await _messaging.getInitialMessage();
      if (initial != null) onOpen(initial.data['route'] as String?);
    } catch (_) {
      // Push ist best-effort — Fehler dürfen die App nie blockieren.
    }
  }

  Future<void> _refreshToken() async {
    final vapid = AppConfig.fcmVapidKey;
    final token =
        await _messaging.getToken(vapidKey: vapid.isEmpty ? null : vapid);
    if (token != null) await _saveToken(token);
  }

  Future<void> _saveToken(String token) async {
    final uid = authService.currentUser?.uid;
    if (uid == null || token.isEmpty) return;
    await firestoreService.setDocument(FirebasePaths.user(uid), {
      'fcmTokens': FieldValue.arrayUnion([token]),
      'fcmUpdatedAt': FieldValue.serverTimestamp(),
    });
  }
}
