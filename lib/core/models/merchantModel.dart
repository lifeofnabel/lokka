import 'package:cloud_firestore/cloud_firestore.dart';

import '../enums/userRole.dart';
import '../enums/verificationStatus.dart';

class MerchantModel {
  const MerchantModel({
    required this.merchantId,
    required this.ownerUid,
    required this.role,
    required this.verificationStatus,
    required this.shopName,
    required this.businessName,
    required this.description,
    required this.email,
    required this.phone,
    required this.address,
    required this.city,
    required this.area,
    required this.country,
    required this.shopType,
    required this.logoUrl,
    required this.coverUrl,
    this.lat,
    this.lng,
    required this.isPublic,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  final String merchantId;
  final String ownerUid;
  final UserRole role;
  final VerificationStatus verificationStatus;
  final String shopName;
  final String businessName;
  final String description;
  final String email;
  final String phone;
  final String address;
  final String city;
  final String area;
  final String country;
  final String shopType;
  final String logoUrl;
  final String coverUrl;
  final double? lat;
  final double? lng;
  final bool isPublic;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory MerchantModel.fromMap(Map<String, dynamic> map) {
    return MerchantModel(
      merchantId: map['merchantId'] as String? ?? '',
      ownerUid: map['ownerUid'] as String? ?? '',
      role: UserRole.values.byName(map['role'] as String? ?? UserRole.merchant.name),
      verificationStatus: VerificationStatus.values.byName(
        map['verificationStatus'] as String? ?? VerificationStatus.pending.name,
      ),
      shopName: map['shopName'] as String? ?? '',
      businessName: map['businessName'] as String? ?? '',
      description: map['description'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      address: map['address'] as String? ?? '',
      city: map['city'] as String? ?? '',
      area: map['area'] as String? ?? '',
      country: map['country'] as String? ?? '',
      shopType: map['shopType'] as String? ?? '',
      logoUrl: map['logoUrl'] as String? ?? '',
      coverUrl: map['coverUrl'] as String? ?? '',
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      isPublic: map['isPublic'] as bool? ?? false,
      isActive: map['isActive'] as bool? ?? true,
      createdAt: _date(map['createdAt']),
      updatedAt: _date(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'merchantId': merchantId,
      'ownerUid': ownerUid,
      'role': role.name,
      'verificationStatus': verificationStatus.name,
      'shopName': shopName,
      'businessName': businessName,
      'description': description,
      'email': email,
      'phone': phone,
      'address': address,
      'city': city,
      'area': area,
      'country': country,
      'shopType': shopType,
      'logoUrl': logoUrl,
      'coverUrl': coverUrl,
      'lat': lat,
      'lng': lng,
      'isPublic': isPublic,
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  MerchantModel copyWith({
    String? merchantId,
    String? ownerUid,
    UserRole? role,
    VerificationStatus? verificationStatus,
    String? shopName,
    String? businessName,
    String? description,
    String? email,
    String? phone,
    String? address,
    String? city,
    String? area,
    String? country,
    String? shopType,
    String? logoUrl,
    String? coverUrl,
    double? lat,
    double? lng,
    bool? isPublic,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MerchantModel(
      merchantId: merchantId ?? this.merchantId,
      ownerUid: ownerUid ?? this.ownerUid,
      role: role ?? this.role,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      shopName: shopName ?? this.shopName,
      businessName: businessName ?? this.businessName,
      description: description ?? this.description,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      city: city ?? this.city,
      area: area ?? this.area,
      country: country ?? this.country,
      shopType: shopType ?? this.shopType,
      logoUrl: logoUrl ?? this.logoUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      isPublic: isPublic ?? this.isPublic,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  return DateTime.tryParse(value.toString());
}
