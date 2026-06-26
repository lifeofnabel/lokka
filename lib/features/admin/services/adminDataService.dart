import 'package:cloud_firestore/cloud_firestore.dart';

/// Direct Firestore access for the Godmode console. Works because the deployed
/// rules grant accounts with the `admin` claim full read/write on every
/// document. Keep destructive calls behind a confirm in the UI.
class AdminDataService {
  AdminDataService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // ── Händler & Nutzer ───────────────────────────────────────────────────────
  Future<List<AdminDoc>> pendingMerchants({int limit = 50}) async {
    final snap = await _db
        .collection('merchants')
        .where('verificationStatus', isEqualTo: 'pending')
        .limit(limit)
        .get();
    return _docs(snap);
  }

  /// status ∈ pending | approved | rejected | blocked | paused.
  Future<void> setMerchantStatus(String uid, String status) =>
      _db.doc('merchants/$uid').set(
        {'verificationStatus': status},
        SetOptions(merge: true),
      );

  Future<List<AdminDoc>> listMerchants({int limit = 300}) async =>
      _docs(await _db.collection('publicMerchants').limit(limit).get());

  Future<List<AdminDoc>> listUsers({int limit = 300}) async =>
      _docs(await _db.collection('users').limit(limit).get());

  Future<void> setUserRole(String uid, String role) =>
      _db.doc('users/$uid').set({'role': role}, SetOptions(merge: true));

  Future<void> setUserActive(String uid, bool active) =>
      _db.doc('users/$uid').set({'isActive': active}, SetOptions(merge: true));

  // ── Inhalte moderieren ──────────────────────────────────────────────────────
  Future<List<AdminDoc>> recentPosts({int limit = 60}) async => _docs(
        await _db
            .collection('feed')
            .orderBy('publishedAt', descending: true)
            .limit(limit)
            .get(),
      );

  /// isActive==false → the post drops out of the public feed (paused/hidden).
  Future<void> setPostActive(String id, bool active) =>
      _db.doc('feed/$id').set({'isActive': active}, SetOptions(merge: true));

  Future<void> deletePost(String id) => _db.doc('feed/$id').delete();

  Future<List<AdminDoc>> recentReports({int limit = 80}) async =>
      _docs(await _db.collection('contentReports').limit(limit).get());

  Future<void> deleteReport(String id) =>
      _db.doc('contentReports/$id').delete();

  // ── Register: Stempelkarten (über alle Händler) ─────────────────────────────
  Future<List<AdminDoc>> stampCards({int limit = 150}) async {
    final snap = await _db.collectionGroup('stampCards').limit(limit).get();
    // Use the full path as the id so the editor can open it directly.
    return snap.docs
        .map((d) => AdminDoc(d.reference.path, d.data()))
        .toList();
  }

  // ── Generischer Firestore-Editor ────────────────────────────────────────────
  Future<Map<String, dynamic>?> getDoc(String path) async {
    final snap = await _db.doc(path).get();
    return snap.exists ? snap.data() : null;
  }

  Future<List<String>> listCollection(String path, {int limit = 150}) async {
    final snap = await _db.collection(path).limit(limit).get();
    return snap.docs.map((d) => d.id).toList();
  }

  Future<void> mergeDoc(String path, Map<String, dynamic> data) =>
      _db.doc(path).set(data, SetOptions(merge: true));

  Future<void> deleteDoc(String path) => _db.doc(path).delete();

  Future<void> deleteField(String path, String field) =>
      _db.doc(path).update({field: FieldValue.delete()});

  List<AdminDoc> _docs(QuerySnapshot<Map<String, dynamic>> snap) =>
      snap.docs.map((d) => AdminDoc(d.id, d.data())).toList();
}

/// A document id (or full path) + its data.
class AdminDoc {
  AdminDoc(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
}
