import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/firebasePaths.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> collection(String path) {
    return _firestore.collection(path);
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

  Stream<List<Map<String, dynamic>>> collectionStream(String path) {
    return collection(path)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<void> createUserProfile(String uid, Map<String, dynamic> data) {
    return setDocument('${FirebasePaths.users}/$uid', data);
  }

  Future<void> createMerchantProfile({
    required String uid,
    required Map<String, dynamic> userData,
    required Map<String, dynamic> merchantData,
    required Map<String, dynamic> publicMerchantData,
  }) {
    final batch = _firestore.batch();
    batch.set(document('${FirebasePaths.users}/$uid'), userData, SetOptions(merge: true));
    batch.set(document('${FirebasePaths.merchants}/$uid'), merchantData, SetOptions(merge: true));
    batch.set(
      document('${FirebasePaths.publicMerchants}/$uid'),
      publicMerchantData,
      SetOptions(merge: true),
    );
    return batch.commit();
  }

  Future<Map<String, dynamic>?> getUserProfile(String uid) {
    return readDocument('${FirebasePaths.users}/$uid');
  }

  Future<Map<String, dynamic>?> getMerchantProfile(String uid) {
    return readDocument('${FirebasePaths.merchants}/$uid');
  }

  Future<void> updateEmailVerified(String uid, bool emailVerified) async {
    final data = {
      'emailVerified': emailVerified,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await setDocument('${FirebasePaths.users}/$uid', data);
    final merchant = await getMerchantProfile(uid);
    if (merchant != null) {
      await setDocument('${FirebasePaths.merchants}/$uid', data);
    }
  }

  Future<List<String>> loadChooserAreas() {
    return _loadChooserList(FirebasePaths.areas);
  }

  Future<List<String>> loadChooserShopTypes() {
    return _loadChooserList(FirebasePaths.shopTypes);
  }

  Future<void> addShopTypeIfMissing(String value) async {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return;

    await setDocument('${FirebasePaths.chooser}/${FirebasePaths.shopTypes}', {
      'values': FieldValue.arrayUnion([cleaned]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<String>> _loadChooserList(String documentId) async {
    final data = await readDocument('${FirebasePaths.chooser}/$documentId');
    if (data == null) return [];

    final raw = data['values'] ?? data['items'] ?? data[documentId];
    if (raw is Iterable) {
      return raw.map((item) => item.toString()).where((item) => item.trim().isNotEmpty).toList();
    }
    return [];
  }
}
