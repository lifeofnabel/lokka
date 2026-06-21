import 'package:cloud_firestore/cloud_firestore.dart';

class PublicMerchantModel {
  const PublicMerchantModel({
    required this.merchantId,
    required this.shopName,
    required this.description,
    required this.shopType,
    this.shopTypePrimary,
    this.shopTypes = const [],
    required this.phone,
    required this.address,
    this.fullAddress,
    this.street,
    this.houseNumber,
    this.postalCode,
    this.city,
    required this.logoUrl,
    required this.coverUrl,
    this.logoThumbUrl,
    this.coverThumbUrl,
    this.lat,
    this.lng,
    this.openingHours = const {},
    this.featuresPublic = const {},
    required this.isPublic,
    required this.isActive,
    this.updatedAt,
  });

  final String merchantId;
  final String shopName;
  final String description;
  final String shopType;
  final String? shopTypePrimary;
  final List<String> shopTypes;
  final String phone;
  final String address;
  final String? fullAddress;
  final String? street;
  final String? houseNumber;
  final String? postalCode;
  final String? city;
  final String logoUrl;
  final String coverUrl;
  final String? logoThumbUrl;
  final String? coverThumbUrl;
  final double? lat;
  final double? lng;
  final Map<String, dynamic> openingHours;
  final Map<String, dynamic> featuresPublic;
  final bool isPublic;
  final bool isActive;
  final DateTime? updatedAt;

  factory PublicMerchantModel.fromMap(Map<String, dynamic> map) {
    return PublicMerchantModel(
      merchantId: map['merchantId'] as String? ?? '',
      shopName: map['shopName'] as String? ?? '',
      description: map['description'] as String? ?? '',
      shopType: map['shopType'] as String? ?? '',
      shopTypePrimary: map['shopTypePrimary'] as String?,
      shopTypes:
          (map['shopTypes'] as Iterable?)?.map((item) => item.toString()).toList() ??
              const [],
      phone: map['phone'] as String? ?? '',
      address: map['address'] as String? ?? '',
      fullAddress: map['fullAddress'] as String?,
      street: map['street'] as String?,
      houseNumber: map['houseNumber'] as String?,
      postalCode: map['postalCode'] as String?,
      city: map['city'] as String?,
      logoUrl: map['logoUrl'] as String? ?? '',
      coverUrl: map['coverUrl'] as String? ?? '',
      logoThumbUrl: map['logoThumbUrl'] as String?,
      coverThumbUrl: map['coverThumbUrl'] as String?,
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      openingHours: Map<String, dynamic>.from(map['openingHours'] as Map? ?? {}),
      featuresPublic:
          Map<String, dynamic>.from(map['featuresPublic'] as Map? ?? {}),
      isPublic: map['isPublic'] as bool? ?? false,
      isActive: map['isActive'] as bool? ?? false,
      updatedAt: _date(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'merchantId': merchantId,
      'shopName': shopName,
      'description': description,
      'shopType': shopType,
      'shopTypePrimary': shopTypePrimary,
      'shopTypes': shopTypes,
      'phone': phone,
      'address': address,
      'fullAddress': fullAddress,
      'street': street,
      'houseNumber': houseNumber,
      'postalCode': postalCode,
      'city': city,
      'logoUrl': logoUrl,
      'coverUrl': coverUrl,
      'logoThumbUrl': logoThumbUrl,
      'coverThumbUrl': coverThumbUrl,
      'lat': lat,
      'lng': lng,
      'openingHours': openingHours,
      'featuresPublic': featuresPublic,
      'isPublic': isPublic,
      'isActive': isActive,
      'updatedAt': updatedAt,
    };
  }
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  return DateTime.tryParse(value.toString());
}
