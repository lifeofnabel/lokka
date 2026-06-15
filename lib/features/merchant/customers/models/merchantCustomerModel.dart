import 'package:cloud_firestore/cloud_firestore.dart';

class MerchantCustomerModel {
  const MerchantCustomerModel({
    required this.id,
    required this.name,
    required this.usedSystems,
    this.lastVisitAt,
  });

  final String id;
  final String name;
  final List<String> usedSystems;
  final DateTime? lastVisitAt;

  factory MerchantCustomerModel.fromMap(Map<String, dynamic> map) {
    final firstName = map['firstName']?.toString() ?? '';
    final lastName = map['lastName']?.toString() ?? '';
    final fallbackName = [firstName, lastName].where((part) => part.trim().isNotEmpty).join(' ');
    final rawSystems = map['usedSystems'] ?? map['systems'] ?? map['activeSystems'];
    return MerchantCustomerModel(
      id: (map['id'] ?? map['uid'] ?? map['customerId'] ?? '').toString(),
      name: (map['name'] ?? map['displayName'] ?? map['customerName'] ?? fallbackName).toString(),
      usedSystems: rawSystems is Iterable
          ? rawSystems.map((item) => item.toString()).where((item) => item.trim().isNotEmpty).toList()
          : _systemsFromFlags(map),
      lastVisitAt: _date(map['lastVisitAt'] ?? map['lastSeenAt'] ?? map['updatedAt']),
    );
  }
}

List<String> _systemsFromFlags(Map<String, dynamic> map) {
  return [
    if (map['usesStamps'] == true || map['stampCardsCount'] is num) 'stampCards',
    if (map['usesPoints'] == true || map['pointsBalance'] is num) 'pointsSystems',
    if (map['usesCoupons'] == true || map['couponsCount'] is num) 'coupons',
    if (map['ordersCount'] is num || map['usesOrders'] == true) 'orders',
  ];
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  return DateTime.tryParse(value.toString());
}
