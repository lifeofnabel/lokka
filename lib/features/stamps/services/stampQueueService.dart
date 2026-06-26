import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/services/localCacheService.dart';
import 'stampFunctionsService.dart';

/// Offline-safe queue for NFC taps. Kiosk Wi-Fi is unreliable, so a tap that
/// can't reach the server right now is persisted locally and retried later.
/// Each tap carries the chip's monotonic counter inside `picc`, so the server's
/// counter dedup makes retries idempotent — no double-stamping, no lost stamps.
class StampQueueService {
  StampQueueService({
    required this.cache,
    required this.functions,
  });

  final LocalCacheService cache;
  final StampFunctionsService functions;

  static const _key = 'stamps.pendingTaps';

  Future<void> enqueue({required String picc, required String cmac}) async {
    final pending = await _read();
    // Dedup by picc (same tap) so repeated offline submits don't pile up.
    if (pending.any((e) => e['picc'] == picc)) return;
    pending.add({'picc': picc, 'cmac': cmac});
    await cache.writeMapList(_key, pending);
  }

  Future<int> pendingCount() async => (await _read()).length;

  /// Tries to submit all queued taps. Removes a tap on success OR on a permanent
  /// rejection (replay/invalid — already counted or never valid); keeps it only
  /// on a transient/offline error so it retries next time.
  Future<int> flush() async {
    final pending = await _read();
    if (pending.isEmpty) return 0;
    final remaining = <Map<String, dynamic>>[];
    var done = 0;
    for (final tap in pending) {
      try {
        await functions.redeemStampTap(
          picc: (tap['picc'] ?? '').toString(),
          cmac: (tap['cmac'] ?? '').toString(),
        );
        done++;
      } on FirebaseFunctionsException catch (e) {
        if (_isTransient(e)) {
          remaining.add(tap); // keep for next retry
        } else {
          // permanent (already-exists/replay/invalid) → drop, do not retry
          done++;
        }
      } catch (_) {
        remaining.add(tap);
      }
    }
    await cache.writeMapList(_key, remaining);
    return done;
  }

  bool _isTransient(FirebaseFunctionsException e) {
    return e.code == 'unavailable' ||
        e.code == 'deadline-exceeded' ||
        e.code == 'internal';
  }

  Future<List<Map<String, dynamic>>> _read() async {
    final raw = await cache.readMapList(_key);
    return raw == null
        ? <Map<String, dynamic>>[]
        : raw.map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
