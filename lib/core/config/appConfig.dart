import '../constants/appStrings.dart';

class AppConfig {
  const AppConfig._();

  static const appName = AppStrings.appName;

  /// Öffentliche Datenschutzerklärung. TODO: echte URL eintragen.
  static const privacyPolicyUrl = 'https://lokka.app/datenschutz';

  /// Web-Push VAPID Public Key (Firebase Console → Cloud Messaging → Web Push
  /// certificates). Leer lassen = kein Web-Token. TODO: eintragen.
  static const fcmVapidKey = '';
}
