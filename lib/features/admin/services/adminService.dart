import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'adminDataService.dart';

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
  ///
  /// Returns false only for the genuine "no eligible user" cases. A token-fetch
  /// failure (offline / stalled secure-token endpoint) is allowed to THROW so
  /// the caller can show a retry instead of mislabelling the owner as not-admin
  /// (the gate bounds this call with a timeout + cached-token fallback).
  Future<bool> isAdmin({bool refresh = false}) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return false;
    final res = await user.getIdTokenResult(refresh);
    return res.claims?['admin'] == true;
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

  /// Deletes a stick from the register. If it was bound, the server detaches it
  /// from the card first.
  Future<void> deleteStick(String stickId) async {
    await _call('adminDeleteStick', {'stickId': stickId});
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
    // Fallback: surface the real code + message so a hosted-only failure
    // (CORS / functions not deployed / SDK not loaded) is diagnosable instead
    // of a dead-end "unknown error".
    return 'Fehler (${error.code})${msg.isEmpty ? '' : ': $msg'}';
  }
  // Not a Functions error at all — e.g. the Firebase SDK module failed to load
  // (self-hosted /firebase/*) or a network/JS error. Show the raw cause.
  return 'Unerwarteter Fehler: $error';
}

/// A freshly minted, still-unbound link stick. Two artefacts:
///  • [redeemToken] → the NFC link `https://<app>/s/<redeemToken>` that the
///    OWNER writes onto the tag once (stable across re-binding).
///  • [code] → the bind-QR `lokka-stick-a:<id>:<claim>` that ships with the
///    stick; the merchant scans it to bind the stick to one of their cards.
class MintedStick {
  const MintedStick({
    required this.stickId,
    required this.claim,
    required this.code,
    required this.redeemToken,
  });

  final String stickId;
  final String claim;
  final String code; // lokka-stick-a:<id>:<claim>  (bind QR)
  final String redeemToken; // <stickId>.<sig>  (NFC link token)

  factory MintedStick.fromMap(Map<String, dynamic> m) => MintedStick(
        stickId: (m['stickId'] ?? '').toString(),
        claim: (m['claim'] ?? '').toString(),
        code: (m['code'] ?? '').toString(),
        redeemToken: (m['redeemToken'] ?? '').toString(),
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

  /// Builds from a direct Firestore read ([AdminDataService.listSticks]) — the
  /// fast path (no Cloud Functions cold start) used by the inventory lists.
  /// `bound`/`verified` are re-derived here exactly like the old server-side
  /// mapping did, since the raw doc doesn't always carry an explicit `bound`.
  factory StickInventoryItem.fromDoc(AdminDoc d) {
    final m = d.data;
    DateTime? ts(Object? v) => v is Timestamp ? v.toDate() : null;
    final boundMerchantId = (m['boundMerchantId'] ?? '').toString();
    final boundCardId = (m['boundCardId'] ?? '').toString();
    return StickInventoryItem(
      stickId: d.id,
      type: (m['type'] ?? '').toString(),
      bound: m['bound'] == true ||
          (boundMerchantId.isNotEmpty && boundCardId.isNotEmpty),
      boundMerchantId: boundMerchantId,
      boundCardId: boundCardId,
      note: (m['note'] ?? '').toString(),
      verified: m['verifiedAt'] != null,
      createdAt: ts(m['createdAt']),
      lastTapAt: ts(m['lastTapAt']),
    );
  }
}
