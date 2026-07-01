import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Direct Firestore access for the Godmode console. Works because the deployed
/// rules grant accounts with the `admin` claim full read/write on every
/// document.
///
/// Robustness: on Flutter Web with offline persistence enabled, a one-time
/// `Query.get()` can stall (the rest of the app reads collections via
/// `.snapshots()`, which works). Every read here goes through [_query]/[_getDoc]:
/// a bounded server `get()` that, only if it STALLS (TimeoutException), falls
/// back to a single non-cache snapshot via [_firstNonCache] — which manages its
/// own subscription and cancels it on every exit path (no listener leak) and
/// surfaces a clean error if the stream closes. A clean error (e.g. offline →
/// `unavailable`) propagates immediately for fast feedback. Net: the UI can
/// never spin forever — it resolves with data or a real, surfaced error.
class AdminDataService {
  AdminDataService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const _readTimeout = Duration(seconds: 8);
  static const _writeTimeout = Duration(seconds: 15);

  // ── Robust read primitives ──────────────────────────────────────────────────
  Future<QuerySnapshot<Map<String, dynamic>>> _query(
      Query<Map<String, dynamic>> q) async {
    try {
      return await q
          .get(const GetOptions(source: Source.server))
          .timeout(_readTimeout);
    } on TimeoutException {
      return _firstNonCache(q.snapshots(), (s) => !s.metadata.isFromCache);
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _getDoc(String path) async {
    final ref = _db.doc(path);
    try {
      return await ref
          .get(const GetOptions(source: Source.server))
          .timeout(_readTimeout);
    } on TimeoutException {
      return _firstNonCache(ref.snapshots(), (s) => !s.metadata.isFromCache);
    }
  }

  /// Completes with the first stream value satisfying [test], cancelling the
  /// subscription on EVERY exit path (match, timeout, error, close) so the
  /// Firestore listener never leaks. A closed stream surfaces a clean error.
  Future<T> _firstNonCache<T>(Stream<T> stream, bool Function(T) test) {
    final completer = Completer<T>();
    late final StreamSubscription<T> sub;
    final timer = Timer(_readTimeout, () {
      if (!completer.isCompleted) {
        completer.completeError(
            TimeoutException('Firestore-Listener Zeitüberschreitung', _readTimeout));
      }
    });
    sub = stream.listen(
      (value) {
        if (test(value) && !completer.isCompleted) completer.complete(value);
      },
      onError: (Object e, StackTrace st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.completeError(
              StateError('Keine Serverdaten erhalten. Bitte erneut versuchen.'));
        }
      },
    );
    return completer.future.whenComplete(() {
      timer.cancel();
      sub.cancel();
    });
  }

  Future<List<AdminDoc>> _docs(Query<Map<String, dynamic>> q,
          {bool fullPath = false}) async =>
      (await _query(q))
          .docs
          .map((d) => AdminDoc(fullPath ? d.reference.path : d.id, d.data()))
          .toList();

  // ── Händler & Nutzer ───────────────────────────────────────────────────────
  Future<List<AdminDoc>> pendingMerchants({int limit = 50}) => _docs(
        _db
            .collection('merchants')
            .where('verificationStatus', isEqualTo: 'pending')
            .limit(limit),
      );

  /// status ∈ pending | approved | rejected | blocked | paused.
  Future<void> setMerchantStatus(String uid, String status) => _db
      .doc('merchants/$uid')
      .set({'verificationStatus': status}, SetOptions(merge: true))
      .timeout(_writeTimeout);

  Future<List<AdminDoc>> listMerchants({int limit = 300}) =>
      _docs(_db.collection('publicMerchants').limit(limit));

  Future<List<AdminDoc>> listUsers({int limit = 300}) =>
      _docs(_db.collection('users').limit(limit));

  Future<void> setUserRole(String uid, String role) => _db
      .doc('users/$uid')
      .set({'role': role}, SetOptions(merge: true))
      .timeout(_writeTimeout);

  Future<void> setUserActive(String uid, bool active) => _db
      .doc('users/$uid')
      .set({'isActive': active}, SetOptions(merge: true))
      .timeout(_writeTimeout);

  // ── Inhalte moderieren ──────────────────────────────────────────────────────
  Future<List<AdminDoc>> recentPosts({int limit = 60}) => _docs(
        _db.collection('feed').orderBy('publishedAt', descending: true).limit(limit),
      );

  /// isActive==false → the post drops out of the public feed (paused/hidden).
  Future<void> setPostActive(String id, bool active) => _db
      .doc('feed/$id')
      .set({'isActive': active}, SetOptions(merge: true))
      .timeout(_writeTimeout);

  Future<void> deletePost(String id) =>
      _db.doc('feed/$id').delete().timeout(_writeTimeout);

  Future<List<AdminDoc>> recentReports({int limit = 80}) =>
      _docs(_db.collection('contentReports').limit(limit));

  Future<void> deleteReport(String id) =>
      _db.doc('contentReports/$id').delete().timeout(_writeTimeout);

  // ── Register: Stempelkarten (über alle Händler) ─────────────────────────────
  Future<List<AdminDoc>> stampCards({int limit = 150}) =>
      _docs(_db.collectionGroup('stampCards').limit(limit), fullPath: true);

  // ── Generischer Firestore-Editor ────────────────────────────────────────────
  Future<Map<String, dynamic>?> getDoc(String path) async {
    final snap = await _getDoc(path);
    return snap.exists ? snap.data() : null;
  }

  Future<List<String>> listCollection(String path, {int limit = 150}) async =>
      (await _query(_db.collection(path).limit(limit)))
          .docs
          .map((d) => d.id)
          .toList();

  Future<void> mergeDoc(String path, Map<String, dynamic> data) =>
      _db.doc(path).set(data, SetOptions(merge: true)).timeout(_writeTimeout);

  /// Applies [data] (which may contain FieldValue.delete() to remove fields).
  /// Falls back to a merge-set if the document doesn't exist yet (FieldValue is
  /// stripped first, since delete() is invalid on a fresh create).
  Future<void> updateDoc(String path, Map<String, dynamic> data) async {
    try {
      await _db.doc(path).update(data).timeout(_writeTimeout);
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') {
        final clean = Map<String, dynamic>.from(data)
          ..removeWhere((_, v) => v is FieldValue);
        await _db
            .doc(path)
            .set(clean, SetOptions(merge: true))
            .timeout(_writeTimeout);
      } else {
        rethrow;
      }
    }
  }

  Future<void> deleteDoc(String path) =>
      _db.doc(path).delete().timeout(_writeTimeout);

  Future<void> deleteField(String path, String field) => _db
      .doc(path)
      .update({field: FieldValue.delete()}).timeout(_writeTimeout);
}

/// A document id (or full path) + its data.
class AdminDoc {
  AdminDoc(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
}
