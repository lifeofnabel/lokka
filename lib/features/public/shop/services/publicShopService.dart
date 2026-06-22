import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firebasePaths.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../merchant/catalog/models/itemCategoryData.dart';
import '../../../merchant/catalog/models/itemTagData.dart';
import '../../../merchant/catalog/models/merchantItemData.dart';
import '../../../merchant/orders/models/orderModel.dart';
import '../../../merchant/tables/models/merchantTableData.dart';

class PublicShopService {
  const PublicShopService({
    required this.firestoreService,
  });

  final FirestoreService firestoreService;

  Future<Map<String, dynamic>?> loadMerchant(String merchantId) {
    return firestoreService.readDocument(FirebasePaths.publicMerchant(merchantId));
  }

  Future<TableData?> loadTable(String merchantId, String tableId) async {
    if (tableId.trim().isEmpty) return null;
    final data = await firestoreService.readDocument(
      FirebasePaths.merchantTable(merchantId, tableId),
    );
    if (data == null) return null;
    final table = TableData.fromMap({'tableId': tableId, ...data});
    return table.isActive ? table : null;
  }

  /// Alle aktiven Tische des Betriebs – für die Tisch-/Platzwahl im Warenkorb.
  Future<List<TableData>> loadTables(String merchantId) async {
    final snapshot = await firestoreService
        .collection(FirebasePaths.merchantTables(merchantId))
        .get();
    final tables = snapshot.docs
        .map((doc) => TableData.fromMap({'tableId': doc.id, ...doc.data()}))
        .where((table) => table.isActive)
        .toList();
    tables.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return tables;
  }

  Future<PublicCatalogConfig> loadCatalogConfig(String merchantId) async {
    final data = await firestoreService.readDocument(
      FirebasePaths.merchantFeatureConfig(merchantId, 'menuCatalog'),
    );
    if (data == null) return PublicCatalogConfig.disabled;

    final isEnabled = data['isEnabled'] == true ||
        data['isActive'] == true ||
        data['status'] == 'enabled' ||
        data['status'] == 'active';
    final settings = data['settings'];
    if (!isEnabled || settings is! Map) {
      return PublicCatalogConfig(catalogEnabled: isEnabled);
    }

    bool flag(String key) => settings[key] == true;
    // Neue Modus-Keys, mit Rückwärts-Kompatibilität zu den alten Schaltern.
    var modeRunner = flag('catalogModeRunner') || flag('catalogStaffMode');
    var modeTable = flag('catalogModeTable') ||
        flag('catalogTableOrders') ||
        flag('catalogOrderSendCashier');
    var modeCashier = flag('catalogModeCashier') || flag('catalogOrderQrCashier');
    var modeMenuOnly = flag('catalogModeMenuOnly');
    // Exklusivität defensiv durchsetzen (Runner & Nur-Karte schließen Rest aus).
    if (modeRunner) {
      modeTable = false;
      modeCashier = false;
      modeMenuOnly = false;
    } else if (modeMenuOnly) {
      modeTable = false;
      modeCashier = false;
    }
    // Katalog an, aber kein Modus gesetzt ⇒ reine Speisekarte.
    if (!modeRunner && !modeTable && !modeCashier && !modeMenuOnly) {
      modeMenuOnly = true;
    }
    return PublicCatalogConfig(
      catalogEnabled: isEnabled,
      modeRunner: modeRunner,
      modeTable: modeTable,
      modeCashier: modeCashier,
      modeMenuOnly: modeMenuOnly,
    );
  }

  Future<List<ItemCategoryData>> loadCategories(String merchantId) async {
    final snapshot = await firestoreService
        .collection(FirebasePaths.merchantItemCategories(merchantId))
        .get();
    final categories = snapshot.docs
        .map((doc) => ItemCategoryData.fromMap({'id': doc.id, ...doc.data()}))
        .where((category) => category.isActive && !category.isPrivate && !category.isArchived)
        .toList();
    categories.sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);
      if (order != 0) return order;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return categories;
  }

  Future<List<MerchantItemData>> loadItems(String merchantId) async {
    final snapshot = await firestoreService
        .collection(FirebasePaths.merchantItems(merchantId))
        .get();
    final items = snapshot.docs
        .map((doc) => MerchantItemData.fromMap({'id': doc.id, ...doc.data()}))
        .where((item) => item.isActive && item.isAvailable && !item.isPrivate && !item.isArchived)
        .toList();
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }

  Future<List<ItemTagData>> loadItemTags(String merchantId) async {
    final snapshot = await firestoreService
        .collection(FirebasePaths.merchantItemTags(merchantId))
        .get();
    final customTags = snapshot.docs
        .map((doc) => ItemTagData.fromMap({'id': doc.id, ...doc.data()}))
        .where((tag) => tag.isActive)
        .toList();
    return [...defaultItemTags(merchantId), ...customTags];
  }

  /// Erzeugt eine frische Bestell-ID (clientseitig), bevor geschrieben wird.
  /// Der Aufrufer (Provider) merkt sie sich pro Checkout-Versuch und reicht sie
  /// erneut ein, falls der erste Versuch scheitert → Idempotenz (#1 Doppel-
  /// Bestellung): derselbe Doc-Pfad wird nie zweimal als zwei Bestellungen
  /// angelegt.
  String newOrderId(String merchantId) =>
      firestoreService.collection(FirebasePaths.merchantOrders(merchantId)).doc().id;

  /// Stabiler, menschenlesbarer Bestellcode – deterministisch aus der ID
  /// abgeleitet, damit ein Wiederholungsversuch denselben Code erzeugt (kein
  /// Drift zwischen Original- und Retry-Schreibvorgang).
  static String orderCodeFor(String orderId) {
    final clean = orderId.replaceAll(RegExp('[^A-Za-z0-9]'), '');
    final slug = (clean.isEmpty ? orderId : clean).toUpperCase();
    return 'LK-${slug.length <= 6 ? slug : slug.substring(0, 6)}';
  }

  /// Liest den Code einer evtl. schon angelegten Bestellung – für die
  /// Idempotenz-Wiederherstellung: Wenn der Client den ersten Write für
  /// gescheitert hält (Timeout/Permission beim Retry auf ein bereits
  /// existierendes Doc), prüft er per öffentlichem `get`, ob die Bestellung
  /// in Wahrheit doch angelegt wurde, und behandelt sie dann als Erfolg.
  Future<String?> existingOrderCode(String merchantId, String orderId) async {
    if (orderId.isEmpty) return null;
    final data = await firestoreService.readDocument(
      FirebasePaths.merchantOrder(merchantId, orderId),
    );
    if (data == null) return null;
    return (data['orderCode'] ?? '').toString();
  }

  Future<({String id, String code})> createOrder({
    required String merchantId,
    required String orderId,
    required List<Map<String, dynamic>> items,
    required num totalPrice,
    TableData? table,
    String note = '',
    String customerName = 'Gast',
    String runnerId = '',
    String serviceType = 'vor_ort',
    String pickupTime = '',
    String fulfillment = 'sent',
  }) async {
    final orderCode = orderCodeFor(orderId);
    await firestoreService.setDocument(
      FirebasePaths.merchantOrder(merchantId, orderId),
      {
        'id': orderId,
        'orderId': orderId,
        'merchantId': merchantId,
        'orderCode': orderCode,
        // Vor-Kasse-Bestellungen sind verborgen, bis das Personal den Code an
        // der Kasse bestätigt; alle anderen sind sofort „neu".
        'status': fulfillment == 'qr_cashier' ? 'qr_pending' : 'new',
        'orderType': table == null ? 'catalog' : 'table',
        'placeLabel': table == null ? 'Speisekarte' : table.label,
        'tableId': table?.tableId ?? '',
        'tableLabel': table?.label ?? '',
        'areaId': table?.areaId ?? '',
        'areaName': table?.areaName ?? '',
        'customerName': customerName.trim().isEmpty ? 'Gast' : customerName.trim(),
        'runnerId': runnerId.trim(),
        'customerNote': note,
        'serviceType': serviceType, // vor_ort | mitnehmen
        'pickupTime': pickupTime,
        'fulfillment': fulfillment, // qr_cashier | sent
        'items': items,
        'totalPrice': totalPrice,
        'isDemo': false,
        'isArchived': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
    return (id: orderId, code: orderCode);
  }

  /// Live-Status einer Bestellung – für den Mini-Status auf der
  /// Bestätigungsseite des Kunden. Liefert den `status`-String des Bestell-
  /// Dokuments und aktualisiert sich, sobald der Merchant ihn ändert
  /// (new → preparing → done).
  Stream<String> watchOrderStatus(String merchantId, String orderId) {
    if (merchantId.isEmpty || orderId.isEmpty) {
      return Stream<String>.value('new');
    }
    return firestoreService
        .document(FirebasePaths.merchantOrder(merchantId, orderId))
        .snapshots()
        .map((snapshot) => (snapshot.data()?['status'] ?? 'new').toString());
  }

  /// Alle Bestellungen, die ein Runner (Mitarbeiter) abgegeben hat – für die
  /// „Meine Bestellungen"-Seite. Gefiltert über den Kundennamen (= Runner-Name);
  /// verborgene Vor-Kasse-Bestellungen ausgeblendet, jüngste zuerst.
  Stream<List<OrderModel>> watchRunnerOrders(
      String merchantId, String runnerId) {
    final id = runnerId.trim();
    if (merchantId.isEmpty || id.isEmpty) {
      return Stream<List<OrderModel>>.value(const <OrderModel>[]);
    }
    return firestoreService
        .collection(FirebasePaths.merchantOrders(merchantId))
        .where('runnerId', isEqualTo: id)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => OrderModel.fromMap({'id': doc.id, ...doc.data()}))
          .where((order) => order.status != 'qr_pending')
          .toList();
      list.sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
      return list;
    });
  }
}

class PublicCatalogConfig {
  const PublicCatalogConfig({
    required this.catalogEnabled,
    this.modeRunner = false,
    this.modeTable = false,
    this.modeCashier = false,
    this.modeMenuOnly = false,
  });

  static const disabled = PublicCatalogConfig(catalogEnabled: false);

  final bool catalogEnabled;

  /// Runner sammeln am Tisch & senden an „Bestellungen" (exklusiv).
  final bool modeRunner;

  /// Kunden bestellen selbst am Tisch & senden an „Bestellungen".
  final bool modeTable;

  /// Kunden bestellen, bekommen QR, zeigen ihn an der Kasse (verborgen bis dahin).
  final bool modeCashier;

  /// Reine Speisekarte ohne Warenkorb (exklusiv).
  final bool modeMenuOnly;

  /// Warenkorb/Bestellen überhaupt möglich (Nur-Karte = nein).
  bool get canOrder => catalogEnabled && (modeRunner || modeTable || modeCashier);

  /// „Bestellung senden" (an „Bestellungen") – Tisch- oder Runner-Modus.
  bool get showSend => modeRunner || modeTable;

  /// „QR an Kasse" – Vor-Kasse-Modus.
  bool get showQrCashier => modeCashier;
}
