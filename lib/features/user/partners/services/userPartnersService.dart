import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/features/user/discover/models/publicMerchantUserModel.dart';

const _publicMerchants = 'publicMerchants';

class UserPartnersService {
  const UserPartnersService({required this.firestoreService});

  final FirestoreService firestoreService;

  Stream<List<PublicMerchantUserModel>> partnersStream({
    String? area,
    String? shopType,
  }) {
    Query<Map<String, dynamic>> query = firestoreService
        .collection(_publicMerchants)
        .where('isActive', isEqualTo: true)
        .where('isPublic', isEqualTo: true)
        .orderBy('shopName');

    return query.snapshots().map((snap) {
      var list = snap.docs
          .map((doc) => PublicMerchantUserModel.fromMap(doc.data()))
          .toList();

      if (area != null && area.isNotEmpty) {
        list = list.where((m) => m.area == area).toList();
      }
      if (shopType != null && shopType.isNotEmpty) {
        list = list.where((m) => m.shopType == shopType).toList();
      }
      return list;
    });
  }
}
