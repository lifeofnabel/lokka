import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/firebasePaths.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> collection(String path) {
    return _firestore.collection(path);
  }

  Query<Map<String, dynamic>> collectionGroup(String collectionId) {
    return _firestore.collectionGroup(collectionId);
  }

  DocumentReference<Map<String, dynamic>> document(String path) {
    return _firestore.doc(path);
  }

  Future<Map<String, dynamic>?> readDocument(String path) async {
    final snapshot = await document(path).get();
    return snapshot.data();
  }

  Future<void> setDocument(
    String path,
    Map<String, dynamic> data, {
    bool merge = true,
  }) {
    return document(path).set(data, SetOptions(merge: merge));
  }

  Future<void> updateDocument(String path, Map<String, dynamic> data) {
    return document(path).update(data);
  }

  Future<T> runTransaction<T>(
    Future<T> Function(Transaction transaction) action,
  ) {
    return _firestore.runTransaction(action);
  }

  WriteBatch batch() {
    return _firestore.batch();
  }

  Stream<List<Map<String, dynamic>>> collectionStream(String path) {
    return collection(path)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<void> createUserProfile(String uid, Map<String, dynamic> data) {
    return setDocument(FirebasePaths.user(uid), data);
  }

  Future<void> createMerchantProfile({
    required String uid,
    required Map<String, dynamic> userData,
    required Map<String, dynamic> merchantData,
    required Map<String, dynamic> publicMerchantData,
  }) {
    final batch = _firestore.batch();
    batch.set(document(FirebasePaths.user(uid)), userData, SetOptions(merge: true));
    batch.set(document(FirebasePaths.merchant(uid)), merchantData, SetOptions(merge: true));
    batch.set(
      document(FirebasePaths.publicMerchant(uid)),
      publicMerchantData,
      SetOptions(merge: true),
    );
    batch.set(
      document(FirebasePaths.merchantFeatureConfig(uid, 'feedPosts')),
      {
        'module': 'feedPosts',
        'isEnabled': true,
        'status': 'enabled',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    return batch.commit();
  }

  Future<Map<String, dynamic>?> getUserProfile(String uid) {
    return readDocument(FirebasePaths.user(uid));
  }

  Future<Map<String, dynamic>?> getMerchantProfile(String uid) {
    return readDocument(FirebasePaths.merchant(uid));
  }

  Future<void> updateEmailVerified(String uid, bool emailVerified) async {
    final data = {
      'emailVerified': emailVerified,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await setDocument(FirebasePaths.user(uid), data);
    final merchant = await getMerchantProfile(uid);
    if (merchant != null) {
      await setDocument(FirebasePaths.merchant(uid), data);
    }
  }

  /// Setzt den Freigabe-Status des Merchants (z. B. nach E-Mail-Verifikation
  /// auf „approved").
  Future<void> setMerchantVerificationStatus(String uid, String status) {
    return setDocument(FirebasePaths.merchant(uid), {
      'verificationStatus': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateUserSession({
    required String uid,
    bool updateLastLogin = false,
    bool updateLastSeen = false,
    String? authProvider,
  }) {
    final data = <String, dynamic>{
      if (updateLastLogin) 'lastLoginAt': FieldValue.serverTimestamp(),
      if (updateLastSeen) 'lastSeenAt': FieldValue.serverTimestamp(),
      'lastAuthProvider': ?authProvider,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (data.length == 1) return Future.value();
    return setDocument(FirebasePaths.user(uid), data);
  }

  Future<List<String>> loadChooserAreas() {
    return _loadChooserList(FirebasePaths.areas);
  }

  Future<List<String>> loadChooserShopTypes() {
    return _loadChooserList(FirebasePaths.shopTypes);
  }

  /// Herkunfts-Küchen/Origins (z. B. „Italienisch", „Türkisch") aus dem
  /// chooser/origins-Dokument, Array-Feld `name` (wie alle Chooser-Listen).
  Future<List<String>> loadChooserOrigins() {
    return _loadChooserList(FirebasePaths.origins);
  }

  Future<void> addShopTypeIfMissing(String value) =>
      addChooserValue(FirebasePaths.shopTypes, value);

  /// Fügt einen selbst getippten Wert im Hintergrund zu einer Chooser-Liste
  /// hinzu (Array `name`), z. B. eine eigene Kategorie oder Herkunft.
  Future<void> addChooserValue(String documentId, String value) async {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return;
    await setDocument(FirebasePaths.chooserDocument(documentId), {
      'name': FieldValue.arrayUnion([cleaned]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<String>> _loadChooserList(String documentId) async {
    final data = await readDocument(FirebasePaths.chooserDocument(documentId));
    if (data == null) return [];

    final raw = data['name'] ?? data['values'] ?? data['items'] ?? data[documentId];
    if (raw is Iterable) {
      return raw.map((item) => item.toString()).where((item) => item.trim().isNotEmpty).toList();
    }
    return [];
  }
}
