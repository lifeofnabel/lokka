import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firebasePaths.dart';
import '../../../core/services/authService.dart';
import '../../../core/services/firestoreService.dart';
import '../models/merchantInviteModel.dart';

class InviteService {
  const InviteService({
    required this.authService,
    required this.firestoreService,
  });

  final AuthService authService;
  final FirestoreService firestoreService;

  String get merchantId {
    final uid = authService.currentUser?.uid;
    if (uid == null) {
      throw StateError('auth.error.signInAgain');
    }
    return uid;
  }

  Future<Map<String, dynamic>?> loadMerchant() {
    return firestoreService.getMerchantProfile(merchantId);
  }

  Future<MerchantInviteModel> getOrCreateInvite(String type) async {
    final existing = await firestoreService
        .collection(FirebasePaths.merchantInvites)
        .where('merchantId', isEqualTo: merchantId)
        .where('type', isEqualTo: type)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      final doc = existing.docs.first;
      return MerchantInviteModel.fromMap({
        'inviteId': doc.id,
        ...doc.data(),
      });
    }

    final merchant = await loadMerchant() ?? {};
    final inviteId =
        firestoreService.collection(FirebasePaths.merchantInvites).doc().id;
    final inviteCode = _inviteCode(type, merchantId);
    final inviteUrl = '${_origin()}/invite/$type/$inviteCode';
    final data = {
      'inviteId': inviteId,
      'merchantId': merchantId,
      'merchantName': merchant['shopName'] ?? '',
      'type': type,
      'inviteCode': inviteCode,
      'inviteUrl': inviteUrl,
      'openedCount': 0,
      'usedCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isActive': true,
    };
    await firestoreService.setDocument(FirebasePaths.merchantInvite(inviteId), data);
    return MerchantInviteModel.fromMap(data);
  }
}

String _inviteCode(String type, String merchantId) {
  final prefix = type == 'merchant' ? 'LM' : 'LC';
  final cleanId = merchantId.replaceAll(RegExp('[^A-Za-z0-9]'), '');
  final shortId = cleanId.padRight(6, 'X').substring(0, 6).toUpperCase();
  final time = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
  return '$prefix-$shortId-$time';
}

String _origin() {
  return Uri.base.host.isEmpty ? 'https://lokka.app' : Uri.base.origin;
}
