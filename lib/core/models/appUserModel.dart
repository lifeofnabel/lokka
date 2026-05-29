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
      'createdAt': createdAt,
      'updatedAt': updatedAt,
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
