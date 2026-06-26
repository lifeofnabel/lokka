/// The individual store↔user code — the spine of the Wallet.
///
/// Format: Letter + 3 digits + Letter + 3 digits, e.g. `A123B456`, shown as
/// `A123-B456`. The ambiguous letters **I** and **O** are excluded so the code
/// can be read aloud over the phone without being confused with 1 / 0.
///
/// The code is the same value encoded in the Wallet QR (`lokka://wallet/{uid}/
/// {mid}/{code}`) and printed on the credit-card — one identity, used
/// everywhere. The merchant scanner resolves a customer by the `uid`+`mid` in
/// the QR path, so the code is the human-readable identity, never a secret.
class WalletCode {
  const WalletCode._();

  /// 24 letters — the full alphabet minus the dictation-ambiguous I and O.
  static const String letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';

  static const int _len = 8; // L D D D L D D D

  /// Deterministic dictatable code for a [seed] (use `uid|merchantId`). The same
  /// inputs always yield the same code, so it is stable across re-follows. Pass
  /// an increasing [salt] to regenerate on a collision within a user's wallet.
  static String generate(String seed, {int salt = 0}) {
    final a = _hash('lokka:$seed:$salt:a');
    final b = _hash('lokka:$seed:$salt:b');
    final l1 = letters[a % letters.length];
    final d1 = (a ~/ letters.length) % 1000;
    final l2 = letters[b % letters.length];
    final d2 = (b ~/ letters.length) % 1000;
    return '$l1${_pad(d1)}$l2${_pad(d2)}';
  }

  /// `A123B456` → `A123-B456` for display and dictation. Leaves any non-standard
  /// value untouched so legacy codes (e.g. `BO-12345`) still render.
  static String pretty(String code) {
    final c = code.trim();
    if (c.length == _len && _isValid(c)) {
      return '${c.substring(0, 4)}-${c.substring(4)}';
    }
    return c;
  }

  /// True when [code] matches the `L DDD L DDD` shape with no ambiguous letters.
  static bool isValid(String code) => _isValid(code.trim().toUpperCase());

  static bool _isValid(String c) {
    if (c.length != _len) return false;
    bool isLetter(int i) => letters.contains(c[i]);
    bool isDigit(int i) => c.codeUnitAt(i) >= 0x30 && c.codeUnitAt(i) <= 0x39;
    return isLetter(0) &&
        isDigit(1) &&
        isDigit(2) &&
        isDigit(3) &&
        isLetter(4) &&
        isDigit(5) &&
        isDigit(6) &&
        isDigit(7);
  }

  static String _pad(int n) => n.toString().padLeft(3, '0');

  /// Stable, non-cryptographic DJB2 hash → a positive 31-bit int.
  static int _hash(String input) {
    int hash = 5381;
    for (final c in input.codeUnits) {
      hash = ((hash << 5) + hash + c) & 0x7FFFFFFF;
    }
    return hash;
  }
}
