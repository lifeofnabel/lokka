import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../constants/firebasePaths.dart';
import 'firestoreService.dart';

/// Loads legal texts (privacy policy) with a robust fallback chain:
/// 1) Firestore `legal/privacyPolicy` (authoritative once present),
/// 2) bundled asset `assets/legal/datenschutz.json` (offline / not-yet-seeded),
/// and best-effort seeds Firestore from the bundle so the text is also stored
/// there (write is admin-only per rules; non-admin seeds fail silently).
class LegalService {
  const LegalService(this._firestore);

  final FirestoreService _firestore;

  static const _privacyAsset = 'assets/legal/datenschutz.json';

  String get _privacyPath =>
      FirebasePaths.legalDocument(FirebasePaths.legalPrivacyPolicy);

  /// Returns the privacy-policy content as a map with the shape
  /// `{title, updated, intro, sections: [{heading, body}]}`.
  Future<Map<String, dynamic>> loadPrivacyPolicy() async {
    // 1) Firestore (authoritative when it exists).
    try {
      final doc = await _firestore.readDocument(_privacyPath);
      if (doc != null && doc['sections'] is List) return doc;
    } catch (_) {
      // Read denied (rules not deployed) or offline → fall back to the bundle.
    }

    // 2) Bundled asset fallback.
    final bundled = await _loadBundled();

    // 3) Best-effort seed into Firestore (so it is "stored in Firestore").
    unawaited(_seedIfPossible(bundled));

    return bundled;
  }

  Future<Map<String, dynamic>> _loadBundled() async {
    final raw = await rootBundle.loadString(_privacyAsset);
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> _seedIfPossible(Map<String, dynamic> content) async {
    try {
      await _firestore.setDocument(_privacyPath, content, merge: false);
    } catch (_) {
      // Non-admin write is denied by rules — ignore; the page still shows the
      // bundled content, and an admin's first open seeds Firestore.
    }
  }
}
