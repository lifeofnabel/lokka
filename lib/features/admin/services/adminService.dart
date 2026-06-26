import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Single client gateway to the Godmode (admin) Cloud Functions, region
/// europe-west1. Admin status lives in a Firebase custom claim (`admin`), set
/// once by `bootstrapAdmin` for the owner account — never trusted from the
/// client, every callable re-checks the claim server-side.
class AdminService {
  AdminService({FirebaseFunctions? functions, FirebaseAuth? auth})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1'),
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  /// The one email allowed to bootstrap itself into the admin role (mirrors the
  /// server-side constant). Only used to decide whether to OFFER the bootstrap
  /// affordance — the grant itself is gated server-side.
  static const ownerEmail = 'nabell.321@gmail.com';

  /// True if the signed-in account carries the `admin` custom claim. Pass
  /// [refresh] = true to force a fresh ID token (e.g. right after bootstrap).
  Future<bool> isAdmin({bool refresh = false}) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return false;
    try {
      final res = await user.getIdTokenResult(refresh);
      return res.claims?['admin'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Whether to show the one-time bootstrap action: signed in as the owner email
  /// but not yet carrying the admin claim.
  bool get canBootstrap {
    final u = _auth.currentUser;
    final email = (u?.email ?? '').toLowerCase();
    return u != null && !u.isAnonymous && email == ownerEmail.toLowerCase();
  }

  /// Grants the admin claim to the owner, then refreshes the local token so the
  /// claim takes effect immediately.
  Future<void> bootstrapAdmin() async {
    await _call('bootstrapAdmin', const {});
    await _auth.currentUser?.getIdToken(true);
  }

  /// Mints [count] unbound Path-A (link) sticks. Returns their claim codes.
  Future<List<MintedStick>> mintStaticSticks({
    required int count,
    String note = '',
  }) async {
    final res = await _call('adminMintStaticSticks', {
      'count': count,
      'note': note,
    });
    return ((res['sticks'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => MintedStick.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Derives the chip keys + provToken for a Path-B (NTAG 424) stick UID.
  Future<DerivedNtagStick> deriveNtagStick({
    required String tagUid,
    String note = '',
  }) async {
    final res = await _call('adminDeriveNtagStick', {
      'tagUid': tagUid,
      'note': note,
    });
    return DerivedNtagStick.fromMap(res);
  }

  /// Loads the stick inventory (newest first) for the register.
  Future<List<StickInventoryItem>> listSticks({int limit = 200}) async {
    final res = await _call('adminListSticks', {'limit': limit});
    return ((res['sticks'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => StickInventoryItem.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Map<String, dynamic>> _call(
      String name, Map<String, dynamic> data) async {
    final callable = _functions.httpsCallable(name);
    final result = await callable.call<Object?>(data);
    final raw = result.data;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }
}

/// Maps an admin Cloud Functions error to a short German message.
String adminErrorMessage(Object error) {
  if (error is FirebaseFunctionsException) {
    final msg = error.message ?? '';
    switch (msg) {
      case 'admin/forbidden':
        return 'Kein Admin-Zugriff.';
      case 'admin/not-owner':
        return 'Nur das Eigentümer-Konto darf den Godmode aktivieren.';
      case 'admin/invalid-uid':
        return 'Ungültige Chip-UID (mindestens 8 Hex-Zeichen).';
      case 'stamp/master-key-missing':
        return 'Server-Schlüssel fehlt — STAMP_MASTER_KEY ist nicht gesetzt.';
    }
    switch (error.code) {
      case 'unauthenticated':
        return 'Bitte zuerst einloggen.';
      case 'permission-denied':
        return 'Keine Berechtigung.';
      case 'unavailable':
        return 'Offline — keine Verbindung zum Server.';
      case 'not-found':
      case 'internal':
      case 'deadline-exceeded':
        return 'Server nicht erreichbar. Sind die Functions deployt?';
    }
    return msg.isEmpty ? 'Unbekannter Fehler.' : msg;
  }
  return 'Unbekannter Fehler.';
}

/// A freshly minted, still-unbound Path-A stick. The merchant scans [code] to
/// claim and bind it.
class MintedStick {
  const MintedStick({
    required this.stickId,
    required this.claim,
    required this.code,
  });

  final String stickId;
  final String claim;
  final String code; // lokka-stick-a:<id>:<claim>

  factory MintedStick.fromMap(Map<String, dynamic> m) => MintedStick(
        stickId: (m['stickId'] ?? '').toString(),
        claim: (m['claim'] ?? '').toString(),
        code: (m['code'] ?? '').toString(),
      );
}

/// Path-B (NTAG 424) derivation result: the two keys to program into the chip
/// plus the printed-QR provToken.
class DerivedNtagStick {
  const DerivedNtagStick({
    required this.uid,
    required this.metaKey,
    required this.fileKey,
    required this.provToken,
    required this.qr,
  });

  final String uid;
  final String metaKey;
  final String fileKey;
  final String provToken;
  final String qr; // lokka-stick:<uid>:<provToken>

  factory DerivedNtagStick.fromMap(Map<String, dynamic> m) => DerivedNtagStick(
        uid: (m['uid'] ?? '').toString(),
        metaKey: (m['sdmMetaReadKey'] ?? '').toString(),
        fileKey: (m['sdmFileReadKey'] ?? '').toString(),
        provToken: (m['provToken'] ?? '').toString(),
        qr: (m['qr'] ?? '').toString(),
      );
}

/// One row in the stick register.
class StickInventoryItem {
  const StickInventoryItem({
    required this.stickId,
    required this.type,
    required this.bound,
    required this.boundMerchantId,
    required this.boundCardId,
    required this.note,
    required this.verified,
    this.createdAt,
    this.lastTapAt,
  });

  final String stickId;
  final String type; // 'static' | 'ntag424'
  final bool bound;
  final String boundMerchantId;
  final String boundCardId;
  final String note;
  final bool verified;
  final DateTime? createdAt;
  final DateTime? lastTapAt;

  bool get isStatic => type == 'static';

  factory StickInventoryItem.fromMap(Map<String, dynamic> m) {
    DateTime? ts(Object? v) {
      final n = (v as num?)?.toInt();
      return n == null ? null : DateTime.fromMillisecondsSinceEpoch(n);
    }

    return StickInventoryItem(
      stickId: (m['stickId'] ?? '').toString(),
      type: (m['type'] ?? '').toString(),
      bound: m['bound'] == true,
      boundMerchantId: (m['boundMerchantId'] ?? '').toString(),
      boundCardId: (m['boundCardId'] ?? '').toString(),
      note: (m['note'] ?? '').toString(),
      verified: m['verified'] == true,
      createdAt: ts(m['createdAt']),
      lastTapAt: ts(m['lastTapAt']),
    );
  }
}
