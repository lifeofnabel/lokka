import 'authService.dart';
import 'firestoreService.dart';
import 'localCacheService.dart';

class SessionService {
  const SessionService({
    required this.authService,
    required this.firestoreService,
    required this.cacheService,
  });

  final AuthService authService;
  final FirestoreService firestoreService;
  final LocalCacheService cacheService;

  Future<void> markLastSeenIfNeeded() async {
    final user = authService.currentUser;
    if (user == null) return;

    final key = 'session.lastSeen.${user.uid}';
    final lastLocalWrite = await cacheService.readTimestamp(key);
    if (lastLocalWrite != null &&
        DateTime.now().difference(lastLocalWrite) < const Duration(hours: 24)) {
      return;
    }

    await firestoreService.updateUserSession(
      uid: user.uid,
      updateLastSeen: true,
    );
    await cacheService.writeTimestamp(key, DateTime.now());
  }
}
