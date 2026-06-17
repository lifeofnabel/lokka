import '../constants/appStrings.dart';

class AppConfig {
  const AppConfig._();

  static const appName = AppStrings.appName;

  /// Öffentliche Datenschutzerklärung. TODO: echte URL eintragen.
  static const privacyPolicyUrl = 'https://lokka.app/datenschutz';

  /// Basis der öffentlichen Shop-/Speisekarte-Links (zum Teilen mit Kunden).
  /// Wird dynamisch aus der aktuellen Web-Adresse gebaut, damit der Link unter
  /// jedem Host stimmt (Produktion: `https://jajehelp.com/lokka/#`, im Dev
  /// `http://localhost:.../#`). Das `#` ist nötig, weil die App Hash-Routing
  /// nutzt (keine Path-URL-Strategie). Voller Link: `$shopLinkBase/shop/<id>`.
  static String get shopLinkBase {
    final base = Uri.base;
    if (base.host.isEmpty) return shopLinkBaseFallback; // native App / keine URL
    var path = base.path; // z.B. /lokka/ oder /lokka/index.html
    final idx = path.indexOf('index.html');
    if (idx != -1) path = path.substring(0, idx);
    if (!path.endsWith('/')) path = '$path/';
    return '${base.origin}$path#';
  }

  /// Fallback-Basis, falls keine Web-URL verfügbar ist (native App). Bei einem
  /// Hosting-Umzug hier anpassen.
  static const shopLinkBaseFallback = 'https://jajehelp.com/lokka/#';

  /// Web-Push VAPID Public Key (Firebase Console → Cloud Messaging → Web Push
  /// certificates). Leer lassen = kein Web-Token. TODO: eintragen.
  static const fcmVapidKey = '';
}
