import 'package:connectivity_plus/connectivity_plus.dart';

/// Schlanker Netzwerk-Status-Check. Wird vor schreibenden Aktionen (z. B.
/// Bestellung absenden / Kassen-Bestätigung) benutzt, um offline NICHT in einen
/// hängenden Firestore-Write zu laufen, sondern dem Nutzer sofort einen klaren
/// Hinweis zu geben (Edge-Case „Offline / schlechtes Netz").
///
/// Bewusst als injizierbare Klasse (statt static), damit Provider/Tests einen
/// Fake einsetzen können.
class ConnectivityService {
  const ConnectivityService();

  /// `true`, wenn mindestens eine Verbindung gemeldet wird. Schlägt der Check
  /// selbst fehl, nehmen wir defensiv „online" an (lieber den Write versuchen
  /// als fälschlich blocken).
  Future<bool> isOnline() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((result) => result != ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }
}
