import 'package:cloud_firestore/cloud_firestore.dart';

class MerchantCustomerModel {
  const MerchantCustomerModel({
    required this.id,
    required this.name,
    required this.usedSystems,
    this.lastVisitAt,
    this.isFollower = false,
    this.followedAt,
    this.profileImageUrl = '',
    this.postalCode = '',
    this.interests = const [],
  });

  /// Echte Firestore-Doc-ID. Wird u. a. als stabiler ListView-Key genutzt.
  final String id;
  final String name;
  final List<String> usedSystems;
  final DateTime? lastVisitAt;

  /// True when this person follows the merchant (added it to their wallet).
  final bool isFollower;

  /// When they started following (added to wallet).
  final DateTime? followedAt;

  /// Avatar URL the user shared by following (may be empty → initials).
  final String profileImageUrl;

  /// Postal code the user shared (rough location; may be empty).
  final String postalCode;

  /// Self-declared interests (cuisine/categories) the user shared by following.
  final List<String> interests;

  factory MerchantCustomerModel.fromMap(Map<String, dynamic> map) {
    final firstName = map['firstName']?.toString() ?? '';
    final lastName = map['lastName']?.toString() ?? '';
    final fallbackName = [firstName, lastName].where((part) => part.trim().isNotEmpty).join(' ');
    final rawSystems = map['usedSystems'] ?? map['systems'] ?? map['activeSystems'];
    // usedSystems (Array) ist autoritativ. Ist es leer ODER fehlt es ganz, aus den
    // Flag-Feldern ableiten – vorher griff der Fallback nur bei fehlendem Key, nicht
    // bei einem vorhandenen, aber leeren Array (inkonsistente Datenquelle).
    final fromArray = rawSystems is Iterable
        ? rawSystems.map((item) => item.toString()).where((item) => item.trim().isNotEmpty).toList()
        : const <String>[];
    final allSystems = fromArray.isNotEmpty ? fromArray : _systemsFromFlags(map);
    final isFollower = map['isFollower'] == true || allSystems.contains('follower');
    // 'follower' is a relationship flag, not a loyalty program → keep it out of
    // the system pills and expose it via [isFollower] instead.
    final systems = allSystems.where((s) => s != 'follower').toList();
    return MerchantCustomerModel(
      id: (map['id'] ?? map['uid'] ?? map['customerId'] ?? '').toString(),
      name: (map['name'] ?? map['displayName'] ?? map['customerName'] ?? fallbackName).toString(),
      usedSystems: systems,
      lastVisitAt: _date(map['lastVisitAt'] ?? map['lastSeenAt'] ?? map['updatedAt']),
      isFollower: isFollower,
      followedAt: _date(map['followedAt'] ?? map['joinedAt']),
      profileImageUrl: (map['profileImageUrl'] ?? map['photoUrl'] ?? '').toString(),
      postalCode: (map['postalCode'] ?? map['city'] ?? '').toString(),
      interests: _interests(map),
    );
  }
}

List<String> _interests(Map<String, dynamic> map) {
  List<String> read(dynamic value) => value is Iterable
      ? value.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList()
      : const <String>[];
  // Merge origins + categories, de-duplicated, order preserved.
  final seen = <String>{};
  return [...read(map['interestOrigins']), ...read(map['interestCategories'])]
      .where((item) => seen.add(item))
      .toList();
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
