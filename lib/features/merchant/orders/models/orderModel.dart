import 'package:cloud_firestore/cloud_firestore.dart';

class OrderItemOption {
  const OrderItemOption({required this.name, required this.price});

  final String name;
  final num price;

  factory OrderItemOption.fromMap(Map<String, dynamic> map) {
    return OrderItemOption(
      name: (map['name'] ?? '').toString(),
      price: map['price'] as num? ?? 0,
    );
  }
}

class OrderItemModel {
  const OrderItemModel({
    required this.itemId,
    required this.title,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.note = '',
    this.options = const [],
  });

  final String itemId;
  final String title;
  final int quantity;
  final num unitPrice;
  final num totalPrice;

  /// Pro-Artikel-Notiz des Kunden (z.B. „ohne Zwiebeln").
  final String note;

  /// Gewählte Optionen (Name + Aufpreis) – fürs Personal/Küche sichtbar.
  final List<OrderItemOption> options;

  String get optionsText => options.map((option) => option.name).join(', ');

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    final rawOptions = map['options'];
    return OrderItemModel(
      itemId: (map['itemId'] ?? '').toString(),
      title: (map['title'] ?? map['name'] ?? '').toString(),
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: map['unitPrice'] as num? ?? 0,
      totalPrice: map['totalPrice'] as num? ?? 0,
      note: (map['note'] ?? '').toString(),
      options: rawOptions is Iterable
          ? rawOptions
              .whereType<Map>()
              .map((option) => OrderItemOption.fromMap(Map<String, dynamic>.from(option)))
              .toList()
          : const [],
    );
  }
}

class OrderModel {
  const OrderModel({
    required this.id,
    required this.merchantId,
    required this.orderCode,
    required this.status,
    required this.orderType,
    required this.placeLabel,
    required this.customerName,
    required this.items,
    required this.totalPrice,
    required this.isDemo,
    required this.isArchived,
    this.tableId = '',
    this.tableLabel = '',
    this.areaName = '',
    this.serviceType = 'vor_ort',
    this.pickupTime = '',
    this.fulfillment = 'sent',
    this.customerNote = '',
    this.runnerId = '',
    this.paid = false,
    this.paidAt,
    this.excludeFromDaily = false,
    this.cleared = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String merchantId;
  final String orderCode;
  final String status;
  final String orderType;
  final String placeLabel;
  final String customerName;
  final List<OrderItemModel> items;
  final num totalPrice;
  final bool isDemo;
  final bool isArchived;

  /// Tisch-Kontext (von `publicShopService.createOrder` gesetzt). Leer bei
  /// Speisekarten-/Katalog-Bestellungen.
  final String tableId;
  final String tableLabel;
  final String areaName;

  /// Bestelltyp 'vor_ort' | 'mitnehmen'.
  final String serviceType;

  /// Gewünschte Abholzeit (bei „Mitnehmen", sonst leer).
  final String pickupTime;

  /// Abschluss-Art 'qr_cashier' (an Kasse zeigen) | 'sent' (direkt gesendet).
  final String fulfillment;

  /// Wunschtext/Notiz für die gesamte Bestellung.
  final String customerNote;

  /// Runner-ID (Mitarbeiter), der die Bestellung aufgenommen hat – für die
  /// „Meine Bestellungen"-Zuordnung im Runner-Modus (leer bei Kundenbestellung).
  final String runnerId;

  /// Bezahlt-Status (wird beim „Tisch abschließen" gesetzt) + Zeitpunkt.
  final bool paid;
  final DateTime? paidAt;

  /// Wurde während einer Tagesumsatz-Pause abgeschlossen → zählt NICHT in den
  /// Tageszähler, aber sehr wohl in die Finanzen-Historie.
  final bool excludeFromDaily;

  /// „Aufgeräumt" – der Tisch wurde geleert; die Bestellung verschwindet aus der
  /// Tisch-Einsicht (zählt aber weiter in Tagesumsatz/Finanzen, da bezahlt).
  final bool cleared;

  bool get isTakeaway => serviceType == 'mitnehmen';
  bool get isQrCashier => fulfillment == 'qr_cashier';

  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get itemsText => items.map((item) => '${item.quantity}x ${item.title}').join(', ');

  int get itemCount => items.fold<int>(0, (acc, item) => acc + item.quantity);

  /// Tischbestellung (vs. Speisekarte/Abholung).
  bool get isTableOrder =>
      orderType.toLowerCase() == 'table' ||
      tableId.trim().isNotEmpty ||
      tableLabel.trim().isNotEmpty;

  /// Offen = muss noch bearbeitet werden (für Zähler/Badges).
  bool get isOpen => status == 'new' || status == 'preparing';

  /// Stabiler Gruppierungs-Schlüssel pro Tisch (Tisch-Einsicht).
  String get tableKey =>
      tableId.trim().isNotEmpty ? tableId.trim() : tableLabel.trim().toLowerCase();

  /// Anzuzeigender Tischname (mit Bereich, falls vorhanden).
  String get tableDisplayLabel {
    final label = tableLabel.trim().isNotEmpty ? tableLabel.trim() : placeLabel.trim();
    final area = areaName.trim();
    if (label.isNotEmpty && area.isNotEmpty) return '$area · $label';
    if (label.isNotEmpty) return label;
    return 'Tisch';
  }

  String get timeText {
    final dt = createdAt;
    if (dt == null) return '–';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String get dateText {
    final dt = createdAt;
    if (dt == null) return '–';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'];
    return OrderModel(
      id: (map['id'] ?? map['orderId'] ?? '').toString(),
      merchantId: (map['merchantId'] ?? '').toString(),
      orderCode: (map['orderCode'] ?? '').toString(),
      status: (map['status'] ?? 'new').toString(),
      orderType: (map['orderType'] ?? '').toString(),
      placeLabel: (map['placeLabel'] ?? '').toString(),
      customerName: (map['customerName'] ?? '').toString(),
      items: rawItems is Iterable
          ? rawItems
              .whereType<Map>()
              .map((item) => OrderItemModel.fromMap(Map<String, dynamic>.from(item)))
              .toList()
          : const [],
      totalPrice: map['totalPrice'] as num? ?? 0,
      isDemo: map['isDemo'] as bool? ?? false,
      isArchived: map['isArchived'] as bool? ?? false,
      tableId: (map['tableId'] ?? '').toString(),
      tableLabel: (map['tableLabel'] ?? '').toString(),
      areaName: (map['areaName'] ?? '').toString(),
      serviceType: (map['serviceType'] ?? 'vor_ort').toString(),
      pickupTime: (map['pickupTime'] ?? '').toString(),
      fulfillment: (map['fulfillment'] ?? 'sent').toString(),
      customerNote: (map['customerNote'] ?? '').toString(),
      runnerId: (map['runnerId'] ?? '').toString(),
      paid: map['paid'] as bool? ?? false,
      paidAt: _readDateTime(map['paidAt']),
      excludeFromDaily: map['excludeFromDaily'] as bool? ?? false,
      cleared: map['cleared'] as bool? ?? false,
      createdAt: _readDateTime(map['createdAt']),
      updatedAt: _readDateTime(map['updatedAt']),
    );
  }
}

DateTime? _readDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
