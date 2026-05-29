import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/authService.dart';
import '../../../core/services/firestoreService.dart';

enum AuthDestination {
  userDiscover,
  merchantDashboard,
  merchantPending,
  chooseRole,
  emailVerificationUser,
  emailVerificationMerchant,
}

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required AuthService authService,
    required FirestoreService firestoreService,
  })  : _authService = authService,
        _firestoreService = firestoreService;

  final AuthService _authService;
  final FirestoreService _firestoreService;

  bool _isLoading = false;
  String? _error;
  String? _message;

  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get message => _message;
  User? get currentUser => _authService.currentUser;

  Future<AuthDestination?> signInUser({
    required String email,
    required String password,
  }) async {
    return _run(() async {
      final credential = await _authService.signInUserWithEmail(
        email: email,
        password: password,
      );
      return _destinationForUser(credential.user!.uid);
    });
  }

  Future<AuthDestination?> signInMerchant({
    required String email,
    required String password,
  }) async {
    return _run(() async {
      final credential = await _authService.signInMerchantWithEmail(
        email: email,
        password: password,
      );
      final uid = credential.user!.uid;
      final user = await _firestoreService.getUserProfile(uid);
      if (user?['role'] != 'merchant') {
        throw AuthFlowException('Dieses Konto ist kein Geschäftskonto.');
      }
      return _destinationForUser(uid);
    });
  }

  Future<AuthDestination?> registerUser({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    return _run(() async {
      final credential = await _authService.registerUserWithEmail(
        email: email,
        password: password,
      );
      final user = credential.user!;
      await _authService.sendEmailVerification();
      await _firestoreService.createUserProfile(user.uid, {
        'uid': user.uid,
        'role': 'user',
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'email': email.trim(),
        'emailLowercase': email.trim().toLowerCase(),
        'customerCode': _customerCode(user.uid),
        'emailVerified': false,
        'acceptedTerms': true,
        'acceptedPrivacy': true,
        'marketingConsent': true,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return AuthDestination.emailVerificationUser;
    });
  }

  Future<AuthDestination?> registerMerchant({
    required String shopName,
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String phone,
    required String street,
    required String houseNumber,
    required String postalCode,
    required String city,
    required String shopType,
    required String area,
    String? customShopType,
  }) async {
    return _run(() async {
      final credential = await _authService.registerMerchantWithEmail(
        email: email,
        password: password,
      );
      final user = credential.user!;
      await _authService.sendEmailVerification();
      await _createMerchantDocuments(
        uid: user.uid,
        shopName: shopName,
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
        street: street,
        houseNumber: houseNumber,
        postalCode: postalCode,
        city: city,
        shopType: shopType,
        area: area,
        customShopType: customShopType,
      );
      if ((customShopType ?? '').trim().isNotEmpty) {
        await _firestoreService.addShopTypeIfMissing(customShopType!);
      }
      return AuthDestination.emailVerificationMerchant;
    });
  }

  Future<AuthDestination?> signInWithGoogle() async {
    return _run(() async {
      final credential = await _authService.signInWithGoogle();
      final uid = credential.user!.uid;
      final profile = await _firestoreService.getUserProfile(uid);
      if (profile == null) return AuthDestination.chooseRole;
      return _destinationForUser(uid);
    });
  }

  Future<AuthDestination?> createGoogleUserProfile({
    required bool acceptedTerms,
    required bool acceptedPrivacy,
    required bool marketingConsent,
  }) async {
    return _run(() async {
      final user = _authService.currentUser;
      if (user == null) {
        throw AuthFlowException('Bitte melde dich zuerst mit Google an.');
      }
      if (!acceptedTerms || !acceptedPrivacy || !marketingConsent) {
        throw AuthFlowException('Bitte bestätige alle Zustimmungen.');
      }

      final parts = _splitDisplayName(user.displayName ?? '');
      await _firestoreService.createUserProfile(user.uid, {
        'uid': user.uid,
        'role': 'user',
        'firstName': parts.$1,
        'lastName': parts.$2,
        'email': user.email ?? '',
        'emailLowercase': (user.email ?? '').toLowerCase(),
        'customerCode': _customerCode(user.uid),
        'emailVerified': user.emailVerified,
        'acceptedTerms': true,
        'acceptedPrivacy': true,
        'marketingConsent': true,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return AuthDestination.userDiscover;
    });
  }

  Future<AuthDestination?> createGoogleMerchantProfile({
    required String shopName,
    required String firstName,
    required String lastName,
    required String phone,
    required String street,
    required String houseNumber,
    required String postalCode,
    required String city,
    required String shopType,
    required String area,
    String? customShopType,
  }) async {
    return _run(() async {
      final user = _authService.currentUser;
      if (user == null) {
        throw AuthFlowException('Bitte melde dich zuerst mit Google an.');
      }
      await _createMerchantDocuments(
        uid: user.uid,
        shopName: shopName,
        firstName: firstName,
        lastName: lastName,
        email: user.email ?? '',
        phone: phone,
        street: street,
        houseNumber: houseNumber,
        postalCode: postalCode,
        city: city,
        shopType: shopType,
        area: area,
        customShopType: customShopType,
        emailVerified: user.emailVerified,
      );
      if ((customShopType ?? '').trim().isNotEmpty) {
        await _firestoreService.addShopTypeIfMissing(customShopType!);
      }
      return AuthDestination.emailVerificationMerchant;
    });
  }

  Future<void> sendVerificationAgain() {
    return _runVoid(() async {
      await _authService.sendEmailVerification();
      _message = 'Bestätigung wurde erneut gesendet.';
    });
  }

  Future<bool> reloadAndUpdateEmailVerified() async {
    final user = await _authService.reloadCurrentUser();
    if (user == null) return false;
    if (user.emailVerified) {
      await _firestoreService.updateEmailVerified(user.uid, true);
    }
    return user.emailVerified;
  }

  Future<AuthDestination?> reloadVerifyAndResolveDestination() async {
    return _run<AuthDestination?>(() async {
      final user = await _authService.reloadCurrentUser();
      if (user == null) {
        throw const AuthFlowException('Bitte melde dich erneut an.');
      }
      if (!user.emailVerified) {
        return null;
      }
      await _firestoreService.updateEmailVerified(user.uid, true);
      return _destinationForUser(user.uid);
    });
  }

  Future<void> resetPassword(String email) {
    return _runVoid(() async {
      await _authService.sendPasswordResetEmail(email);
      _message = 'Wir haben dir eine Email zum Zurücksetzen gesendet.';
    });
  }

  Future<void> signOut() => _authService.signOut();

  Future<List<String>> loadAreas() async {
    try {
      final values = await _firestoreService.loadChooserAreas();
      if (values.isNotEmpty) return values;
    } catch (_) {}
    return const [
      'Westend',
      'Ostend',
      'Innenstadt',
      'Bahnhofsviertel',
      'Sachsenhausen',
      'Bornheim',
    ];
  }

  Future<List<String>> loadShopTypes() async {
    try {
      final values = await _firestoreService.loadChooserShopTypes();
      if (values.isNotEmpty) return values;
    } catch (_) {}
    return const ['Food', 'Cafe', 'Kiosk', 'Beauty', 'Barber', 'Fitness', 'Retail', 'Service'];
  }

  Future<AuthDestination> roleGateDestination() async {
    final user = _authService.currentUser;
    if (user == null) {
      throw AuthRedirectException(AuthDestination.chooseRole, '/auth/userLogin');
    }
    return _destinationForUser(user.uid);
  }

  Future<AuthDestination> _destinationForUser(String uid) async {
    final profile = await _firestoreService.getUserProfile(uid);
    if (profile == null) return AuthDestination.chooseRole;

    if (profile['role'] == 'user') {
      return AuthDestination.userDiscover;
    }

    if (profile['role'] == 'merchant') {
      final merchant = await _firestoreService.getMerchantProfile(uid);
      if (merchant == null) return AuthDestination.emailVerificationMerchant;

      return switch (merchant['verificationStatus'] as String? ?? 'pending') {
        'approved' => AuthDestination.merchantDashboard,
        _ => AuthDestination.merchantPending,
      };
    }

    return AuthDestination.chooseRole;
  }

  Future<void> _createMerchantDocuments({
    required String uid,
    required String shopName,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String street,
    required String houseNumber,
    required String postalCode,
    required String city,
    required String shopType,
    required String area,
    String? customShopType,
    bool emailVerified = false,
  }) {
    final now = FieldValue.serverTimestamp();
    final cleanedShopType = (customShopType ?? '').trim().isNotEmpty
        ? customShopType!.trim()
        : shopType.trim();
    final address = [
      '${street.trim()} ${houseNumber.trim()}'.trim(),
      '${postalCode.trim()} ${city.trim()}'.trim(),
    ].where((part) => part.isNotEmpty).join(', ');

    return _firestoreService.createMerchantProfile(
      uid: uid,
      userData: {
        'uid': uid,
        'role': 'merchant',
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'email': email.trim(),
        'emailLowercase': email.trim().toLowerCase(),
        'emailVerified': emailVerified,
        'acceptedTerms': true,
        'acceptedPrivacy': true,
        'marketingConsent': true,
        'isActive': true,
        'createdAt': now,
        'updatedAt': now,
      },
      merchantData: {
        'merchantId': uid,
        'ownerUid': uid,
        'role': 'merchant',
        'verificationStatus': 'pending',
        'shopName': shopName.trim(),
        'businessName': shopName.trim(),
        'ownerFirstName': firstName.trim(),
        'ownerLastName': lastName.trim(),
        'email': email.trim(),
        'emailLowercase': email.trim().toLowerCase(),
        'phone': phone.trim(),
        'street': street.trim(),
        'houseNumber': houseNumber.trim(),
        'postalCode': postalCode.trim(),
        'city': city.trim(),
        'address': address,
        'fullAddress': address,
        'area': area.trim(),
        'country': 'Deutschland',
        'shopType': cleanedShopType,
        'customShopType': customShopType?.trim() ?? '',
        'description': '',
        'logoUrl': '',
        'coverUrl': '',
        'lat': null,
        'lng': null,
        'emailVerified': emailVerified,
        'isPublic': false,
        'isActive': false,
        'createdAt': now,
        'updatedAt': now,
      },
      publicMerchantData: {
        'merchantId': uid,
        'shopName': shopName.trim(),
        'description': '',
        'area': area.trim(),
        'shopType': cleanedShopType,
        'street': street.trim(),
        'houseNumber': houseNumber.trim(),
        'postalCode': postalCode.trim(),
        'city': city.trim(),
        'address': address,
        'fullAddress': address,
        'phone': phone.trim(),
        'logoUrl': '',
        'coverUrl': '',
        'featuresPublic': <String, bool>{},
        'isPublic': false,
        'isActive': false,
        'updatedAt': now,
      },
    );
  }

  Future<T?> _run<T>(Future<T> Function() action) async {
    _setLoading(true);
    _error = null;
    _message = null;
    try {
      return await action();
    } catch (error) {
      _error = _humanError(error);
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _runVoid(Future<void> Function() action) async {
    await _run(() async {
      await action();
      return true;
    });
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  String _humanError(Object error) {
    if (error is AuthFlowException) return error.message;
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'user-not-found' || 'wrong-password' || 'invalid-credential' =>
          'Email oder Passwort ist nicht korrekt.',
        'email-already-in-use' => 'Diese Email wird bereits verwendet.',
        'weak-password' => 'Das Passwort muss mindestens 6 Zeichen haben.',
        'popup-closed-by-user' || 'google-cancelled' =>
          'Google Anmeldung wurde abgebrochen.',
        _ => error.message ?? 'Anmeldung fehlgeschlagen.',
      };
    }
    return error.toString();
  }
}

class AuthFlowException implements Exception {
  const AuthFlowException(this.message);

  final String message;
}

class AuthRedirectException implements Exception {
  const AuthRedirectException(this.destination, this.path);

  final AuthDestination destination;
  final String path;
}

String _customerCode(String uid) {
  final random = Random(uid.hashCode ^ DateTime.now().millisecondsSinceEpoch);
  return 'LK-${10000 + random.nextInt(90000)}';
}

(String, String) _splitDisplayName(String displayName) {
  final parts = displayName.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return ('', '');
  if (parts.length == 1) return (parts.first, '');
  return (parts.first, parts.sublist(1).join(' '));
}
