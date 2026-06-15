import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firebasePaths.dart';
import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';

/// Speisekarten-Einstellungen des Merchants (externer Link + integrierte Karte).
class MenuSettingsData {
  const MenuSettingsData({
    required this.externalUrl,
    required this.externalEnabled,
    required this.integratedEnabled,
  });

  final String externalUrl;
  final bool externalEnabled;
  final bool integratedEnabled;
}

/// Persistenz der Speisekarten-Einstellungen (publicMerchants/{uid}).
class MerchantMenuSettingsService {
  const MerchantMenuSettingsService({
    required this.authService,
    required this.firestoreService,
  });

  final AuthService authService;
  final FirestoreService firestoreService;

  String get _merchantId {
    final uid = authService.currentUser?.uid;
    if (uid == null) throw StateError('auth.error.signInAgain');
    return uid;
  }

  Future<MenuSettingsData> load() async {
    final data = await firestoreService.readDocument(
      FirebasePaths.publicMerchant(_merchantId),
    );
    return MenuSettingsData(
      externalUrl: data?['menuExternalUrl'] as String? ?? '',
      externalEnabled: data?['menuExternalEnabled'] as bool? ?? false,
      integratedEnabled: data?['menuIntegratedEnabled'] as bool? ?? false,
    );
  }

  Future<void> save(MenuSettingsData settings) {
    return firestoreService.setDocument(
      FirebasePaths.publicMerchant(_merchantId),
      {
        'menuExternalUrl': settings.externalUrl,
        'menuExternalEnabled': settings.externalEnabled,
        'menuIntegratedEnabled': settings.integratedEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }
}
