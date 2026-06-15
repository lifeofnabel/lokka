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

  /// Obergrenze pro Laden/Stream – verhindert unbeschränkte Reads auf einer
  /// wachsenden Collection (#4). KEIN server-seitiges orderBy('createdAt'), weil
  /// das Feld nullable ist und Bestellungen ohne createdAt sonst still
  /// ausgeblendet würden; die Sortierung (jüngste zuerst) passiert clientseitig
  /// in _mapOrders. Für >200 Bestellungen ist echte Pagination der Folgeschritt.
  static const int ordersPageLimit = 200;

  String get merchantId {
    final uid = authService.currentUser?.uid;
    if (uid == null) throw StateError('auth.error.signInAgain');
    return uid;
  }

  Future<List<OrderModel>> loadOrders() async {
    final snapshot = await firestoreService
        .collection(FirebasePaths.merchantOrders(merchantId))
        .limit(ordersPageLimit)
        .get();
    return _mapOrders(snapshot);
  }

  Stream<List<OrderModel>> watchOrders() {
    return firestoreService
        .collection(FirebasePaths.merchantOrders(merchantId))
        .limit(ordersPageLimit)
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

  /// Einzelnes Bestell-Dokument live beobachten – für die Detailseite (#5),
  /// statt die ganze orders-Collection zu streamen.
  Stream<OrderModel?> watchOrder(String orderId) {
    return firestoreService
        .document(FirebasePaths.merchantOrder(merchantId, orderId))
        .snapshots()
        .map((doc) {
      final data = doc.data();
      if (data == null) return null;
      return OrderModel.fromMap({'id': doc.id, ...data});
    });
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
