import 'package:cloud_firestore/cloud_firestore.dart';

class OrderItemModel {
  const OrderItemModel({
    required this.itemId,
    required this.title,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  final String itemId;
  final String title;
  final int quantity;
  final num unitPrice;
  final num totalPrice;

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    return OrderItemModel(
      itemId: (map['itemId'] ?? '').toString(),
      title: (map['title'] ?? map['name'] ?? '').toString(),
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: map['unitPrice'] as num? ?? 0,
      totalPrice: map['totalPrice'] as num? ?? 0,
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
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get itemsText => items.map((item) => '${item.quantity}x ${item.title}').join(', ');

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
