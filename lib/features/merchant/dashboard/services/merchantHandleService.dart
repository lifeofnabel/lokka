import 'package:lokka/core/constants/firebasePaths.dart';
import 'package:lokka/core/services/firestoreService.dart';

/// Manages a merchant's public profile handle (slug) used for the shareable
/// link `<origin>/<handle>`. Stored as `handle` on both `merchants/{id}` and
/// `publicMerchants/{id}` (the latter is what the public resolver queries).
class MerchantHandleService {
  const MerchantHandleService(this.firestoreService);

  final FirestoreService firestoreService;

  static const int minLength = 3;
  static const int maxLength = 30;

  /// Normalizes free text into a valid slug candidate: lowercase, only
  /// [a-z0-9-], spaces/underscores → '-', collapsed and trimmed dashes.
  static String normalize(String raw) {
    var s = raw.trim().toLowerCase();
    s = s.replaceAll(RegExp(r'[\s_]+'), '-');
    s = s.replaceAll(RegExp(r'[^a-z0-9-]'), '');
    s = s.replaceAll(RegExp(r'-+'), '-');
    s = s.replaceAll(RegExp(r'^-+|-+$'), '');
    if (s.length > maxLength) s = s.substring(0, maxLength);
    return s;
  }

  /// Returns a German validation error for [slug], or null if it is valid.
  static String? validationError(String slug) {
    if (slug.isEmpty) return 'Bitte einen Link-Namen eingeben.';
    if (slug.length < minLength) {
      return 'Mindestens $minLength Zeichen.';
    }
    if (!RegExp(r'^[a-z0-9-]+$').hasMatch(slug)) {
      return 'Nur Kleinbuchstaben, Zahlen und Bindestriche.';
    }
    if (_reserved.contains(slug)) {
      return 'Dieser Name ist reserviert.';
    }
    return null;
  }

  /// Reserved top-level paths a handle must never shadow.
  static const _reserved = <String>{
    'auth', 'user', 'merchant', 'shop', 'runner', 'stamp', 's', 'claim', 'dev',
    'admin', 'api', 'login', 'register', 'profile', 'settings', 'about', 'help',
    'support', 'lokka', 'feed', 'wallet', 'discover', 'explore', 'partners',
  };

  /// Current handle of [merchantId] (from the public doc), or '' if unset.
  Future<String> handleFor(String merchantId) async {
    final doc = await firestoreService
        .document(FirebasePaths.publicMerchant(merchantId))
        .get();
    return (doc.data()?['handle'] as String? ?? '').trim().toLowerCase();
  }

  /// True if [slug] is free (or already owned by [merchantId]).
  Future<bool> isAvailable(String slug, String merchantId) async {
    final snap = await firestoreService
        .collection(FirebasePaths.publicMerchants)
        .where('handle', isEqualTo: slug)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return true;
    return snap.docs.first.id == merchantId;
  }

  /// Validates, checks uniqueness, then persists the handle on both docs.
  /// Throws [StateError] with a user-facing message on any problem.
  Future<void> setHandle(String merchantId, String slug) async {
    final error = validationError(slug);
    if (error != null) throw StateError(error);
    if (!await isAvailable(slug, merchantId)) {
      throw StateError('Dieser Link-Name ist schon vergeben.');
    }
    await firestoreService.setDocument(
      FirebasePaths.publicMerchant(merchantId),
      {'handle': slug},
    );
    await firestoreService.setDocument(
      FirebasePaths.merchant(merchantId),
      {'handle': slug},
    );
  }
}
