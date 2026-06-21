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

  /// Schließt eine Bestellung ab: fertig + bezahlt (für „Tisch abschließen" und
  /// das Nachbuchen offener Bestellungen). [excludeFromDaily] = während einer
  /// Tagesumsatz-Pause abgeschlossen → zählt nicht in den Tageszähler.
  Future<void> closeOrderPaid(String orderId, {bool excludeFromDaily = false}) {
    return firestoreService.setDocument(
      FirebasePaths.merchantOrder(merchantId, orderId),
      {
        'status': 'done',
        'paid': true,
        'paidAt': FieldValue.serverTimestamp(),
        'excludeFromDaily': excludeFromDaily,
        'doneAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  /// „Tisch aufräumen": Bestellung aus der Tisch-Einsicht entfernen (cleared).
  /// [markPaid] = falls noch unbezahlt → jetzt als bezahlt zählen (fertig).
  Future<void> clearOrder(String orderId,
      {required bool markPaid, bool excludeFromDaily = false}) {
    return firestoreService.setDocument(
      FirebasePaths.merchantOrder(merchantId, orderId),
      {
        'cleared': true,
        'updatedAt': FieldValue.serverTimestamp(),
        if (markPaid) 'status': 'done',
        if (markPaid) 'paid': true,
        if (markPaid) 'paidAt': FieldValue.serverTimestamp(),
        if (markPaid) 'excludeFromDaily': excludeFromDaily,
      },
    );
  }

  /// Tagesumsatz-Pause (pro Konto) – liegt im privaten Merchant-Doc.
  Future<bool> loadRevenuePaused() async {
    final data = await firestoreService.readDocument(
      FirebasePaths.merchant(merchantId),
    );
    return data?['revenuePaused'] as bool? ?? false;
  }

  Future<void> setRevenuePaused(bool paused) {
    return firestoreService.setDocument(
      FirebasePaths.merchant(merchantId),
      {'revenuePaused': paused, 'updatedAt': FieldValue.serverTimestamp()},
    );
  }

  /// Bestätigt eine verborgene Vor-Kasse-Bestellung anhand ihres Codes
  /// (Personal an der Kasse). Gibt true zurück, wenn eine passende offene
  /// QR-Bestellung gefunden und auf „neu" gesetzt wurde.
  Future<bool> confirmPendingByCode(String code) async {
    final wanted = code.trim().toUpperCase();
    if (wanted.isEmpty) return false;
    // Nur die (wenigen) verborgenen Vor-Kasse-Bestellungen abfragen – nicht die
    // ganze Collection bis zum Limit scannen (sonst kann eine Bestellung
    // jenseits des Limits nie bestätigt werden).
    final snapshot = await firestoreService
        .collection(FirebasePaths.merchantOrders(merchantId))
        .where('status', isEqualTo: 'qr_pending')
        .get();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final matches = (data['orderCode']?.toString() ?? '').trim().toUpperCase() == wanted;
      if (matches) {
        await firestoreService.setDocument(
          FirebasePaths.merchantOrder(merchantId, doc.id),
          {
            'status': 'new',
            'confirmedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
        return true;
      }
    }
    return false;
  }

  /// Bezahlte Bestellungen ab [since] (optional bis < [until]) – für die
  /// Finanzen-Auswertung. Einzelfeld-Range auf `paidAt` (kein Composite-Index
  /// nötig); `paid` wird clientseitig gefiltert.
  Future<List<OrderModel>> loadPaidOrdersBetween(
      DateTime since, DateTime? until) async {
    Query<Map<String, dynamic>> query = firestoreService
        .collection(FirebasePaths.merchantOrders(merchantId))
        .where('paidAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since));
    if (until != null) {
      query = query.where('paidAt', isLessThan: Timestamp.fromDate(until));
    }
    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => OrderModel.fromMap({'id': doc.id, ...doc.data()}))
        .where((order) => order.paid)
        .toList();
  }

  List<OrderModel> _mapOrders(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final orders = snapshot.docs
        .map((doc) => OrderModel.fromMap({'id': doc.id, ...doc.data()}))
        // Vor-Kasse-Bestellungen erst nach Kassen-Bestätigung sichtbar (#Modi).
        .where((order) => !order.isArchived && order.status != 'qr_pending')
        .toList();
    orders.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return orders;
  }
}
