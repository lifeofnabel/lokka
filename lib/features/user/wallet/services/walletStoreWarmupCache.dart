import 'package:lokka/features/merchant/stamps/models/stampCardModel.dart';
import 'package:lokka/features/user/discover/models/publicMerchantUserModel.dart';
import 'package:lokka/features/user/wallet/services/userWalletService.dart';

/// Vorab geladene ("warme") Store-Deck-Daten (Merchant-Profil, aktive
/// Stempelkarten, Punkte-Verfügbarkeit), keyed by merchantId. Jede Wallet-
/// Store-Karte braucht diese 3 Dinge, bisher sequenziell UND bei jedem
/// (Wieder-)Aufbau des Decks (z. B. nach dem Zurückswipen, wenn PageView das
/// Element zwischenzeitlich verworfen hat) komplett neu geladen – daher das
/// "Swipen dauert ewig". Rein passiver In-Memory-Cache, kein Provider nötig.
class WalletStoreWarmupEntry {
  const WalletStoreWarmupEntry({
    required this.merchant,
    required this.activeCards,
    required this.pointsEnabled,
    required this.fetchedAt,
  });

  final PublicMerchantUserModel? merchant;
  final List<StampCardModel> activeCards;
  final bool pointsEnabled;
  final DateTime fetchedAt;
}

class WalletStoreWarmupCache {
  WalletStoreWarmupCache._();

  static final Map<String, WalletStoreWarmupEntry> _entries = {};
  static final Map<String, Future<WalletStoreWarmupEntry>> _inFlight = {};

  /// Liefert einen frischen (< [maxAge] alten) Eintrag oder null.
  static WalletStoreWarmupEntry? peek(
    String merchantId, {
    Duration maxAge = const Duration(minutes: 5),
  }) {
    final entry = _entries[merchantId];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.fetchedAt) > maxAge) return null;
    return entry;
  }

  /// Lädt (parallel statt sequenziell) und cacht die 3 Store-Deck-Daten.
  /// Mehrfachaufrufe für dieselbe merchantId (z. B. Deck-Load + Prefetch der
  /// Nachbarkarte treffen sich) teilen sich dasselbe In-Flight-Future statt
  /// doppelt zu lesen.
  static Future<WalletStoreWarmupEntry> warm(
    String merchantId, {
    required UserWalletService service,
  }) {
    final cached = peek(merchantId);
    if (cached != null) return Future.value(cached);
    final pending = _inFlight[merchantId];
    if (pending != null) return pending;

    final future = () async {
      final results = await Future.wait([
        service.loadMerchant(merchantId),
        service.loadActiveStampCards(merchantId),
        service.loadPointsEnabled(merchantId),
      ]);
      final entry = WalletStoreWarmupEntry(
        merchant: results[0] as PublicMerchantUserModel?,
        activeCards: results[1] as List<StampCardModel>,
        pointsEnabled: results[2] as bool,
        fetchedAt: DateTime.now(),
      );
      _entries[merchantId] = entry;
      return entry;
    }();
    _inFlight[merchantId] = future;
    // ignore: unawaited_futures — Cleanup, kein UI wartet darauf.
    future.whenComplete(() => _inFlight.remove(merchantId));
    return future;
  }
}
