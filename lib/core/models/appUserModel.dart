import 'package:cloud_firestore/cloud_firestore.dart';

import '../enums/userRole.dart';

class AppUserModel {
  const AppUserModel({
    required this.uid,
    required this.role,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.emailLowercase,
    required this.customerCode,
    required this.isActive,
    this.postalCode,
    this.phone,
    this.phoneVerified = false,
    this.emailVerified = false,
    this.acceptedTerms = false,
    this.acceptedPrivacy = false,
    this.marketingConsent = false,
    this.lastLoginAt,
    this.lastSeenAt,
    this.lastAuthProvider,
    this.birthday,
    this.profileImageUrl,
    this.profileCoverGradient = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final UserRole role;
  final String firstName;
  final String lastName;
  final String email;
  final String emailLowercase;
  final String customerCode;
  final bool isActive;
  final String? postalCode;
  final String? phone;
  final bool phoneVerified;
  final bool emailVerified;
  final bool acceptedTerms;
  final bool acceptedPrivacy;
  final bool marketingConsent;
  final DateTime? lastLoginAt;
  final DateTime? lastSeenAt;
  final String? lastAuthProvider;
  final DateTime? birthday;
  final String? profileImageUrl;
  final int profileCoverGradient;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory AppUserModel.fromMap(Map<String, dynamic> map) {
    return AppUserModel(
      uid: map['uid'] as String? ?? '',
      role: UserRole.values.byName(map['role'] as String? ?? UserRole.user.name),
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      emailLowercase: map['emailLowercase'] as String? ?? '',
      customerCode: map['customerCode'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? true,
      postalCode: map['postalCode'] as String?,
      phone: map['phone'] as String?,
      phoneVerified: map['phoneVerified'] as bool? ?? false,
      emailVerified: map['emailVerified'] as bool? ?? false,
      acceptedTerms: map['acceptedTerms'] as bool? ?? false,
      acceptedPrivacy: map['acceptedPrivacy'] as bool? ?? false,
      marketingConsent: map['marketingConsent'] as bool? ?? false,
      lastLoginAt: _date(map['lastLoginAt']),
      lastSeenAt: _date(map['lastSeenAt']),
      lastAuthProvider: map['lastAuthProvider'] as String?,
      birthday: _date(map['birthday']),
      profileImageUrl: map['profileImageUrl'] as String?,
      profileCoverGradient: map['profileCoverGradient'] as int? ?? 0,
      createdAt: _date(map['createdAt']),
      updatedAt: _date(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'role': role.name,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'emailLowercase': emailLowercase,
      'customerCode': customerCode,
      'isActive': isActive,
      'postalCode': postalCode,
      'phone': phone,
      'phoneVerified': phoneVerified,
      'emailVerified': emailVerified,
      'acceptedTerms': acceptedTerms,
      'acceptedPrivacy': acceptedPrivacy,
      'marketingConsent': marketingConsent,
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'lastSeenAt': lastSeenAt?.toIso8601String(),
      'lastAuthProvider': lastAuthProvider,
      'birthday': birthday?.toIso8601String(),
      'profileImageUrl': profileImageUrl,
      'profileCoverGradient': profileCoverGradient,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  AppUserModel copyWith({
    String? uid,
    UserRole? role,
    String? firstName,
    String? lastName,
    String? email,
    String? emailLowercase,
    String? customerCode,
    bool? isActive,
    String? postalCode,
    String? phone,
    bool? phoneVerified,
    bool? emailVerified,
    bool? acceptedTerms,
    bool? acceptedPrivacy,
    bool? marketingConsent,
    DateTime? lastLoginAt,
    DateTime? lastSeenAt,
    String? lastAuthProvider,
    DateTime? birthday,
    String? profileImageUrl,
    int? profileCoverGradient,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppUserModel(
      uid: uid ?? this.uid,
      role: role ?? this.role,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      emailLowercase: emailLowercase ?? this.emailLowercase,
      customerCode: customerCode ?? this.customerCode,
      isActive: isActive ?? this.isActive,
      postalCode: postalCode ?? this.postalCode,
      phone: phone ?? this.phone,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      emailVerified: emailVerified ?? this.emailVerified,
      acceptedTerms: acceptedTerms ?? this.acceptedTerms,
      acceptedPrivacy: acceptedPrivacy ?? this.acceptedPrivacy,
      marketingConsent: marketingConsent ?? this.marketingConsent,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      lastAuthProvider: lastAuthProvider ?? this.lastAuthProvider,
      birthday: birthday ?? this.birthday,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      profileCoverGradient: profileCoverGradient ?? this.profileCoverGradient,
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
