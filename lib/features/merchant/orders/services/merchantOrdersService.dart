import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firebasePaths.dart';
import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../models/orderModel.dart';

class MerchantOrdersService {
  const MerchantOrdersService({
    required this.authService,
    required this.firestoreService,
  });

  final AuthService authService;
  final FirestoreService firestoreService;

  String get merchantId {
    final uid = authService.currentUser?.uid;
    if (uid == null) throw StateError('auth.error.signInAgain');
    return uid;
  }

  Future<List<OrderModel>> loadOrders() async {
    final snapshot = await firestoreService
        .collection(FirebasePaths.merchantOrders(merchantId))
        .get();
    return _mapOrders(snapshot);
  }

  Stream<List<OrderModel>> watchOrders() {
    return firestoreService
        .collection(FirebasePaths.merchantOrders(merchantId))
        .snapshots()
        .map(_mapOrders);
  }

  Future<OrderModel?> loadOrder(String orderId) async {
    final data = await firestoreService.readDocument(
      FirebasePaths.merchantOrder(merchantId, orderId),
    );
    if (data == null) return null;
    return OrderModel.fromMap({'id': orderId, ...data});
  }

  Future<void> updateStatus(String orderId, String status) {
    return firestoreService.setDocument(
      FirebasePaths.merchantOrder(merchantId, orderId),
      {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        if (status == 'preparing') 'acceptedAt': FieldValue.serverTimestamp(),
        if (status == 'done') 'doneAt': FieldValue.serverTimestamp(),
        if (status == 'cancelled') 'cancelledAt': FieldValue.serverTimestamp(),
      },
    );
  }

  List<OrderModel> _mapOrders(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final orders = snapshot.docs
        .map((doc) => OrderModel.fromMap({'id': doc.id, ...doc.data()}))
        .where((order) => !order.isArchived)
        .toList();
    orders.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return orders;
  }
}
