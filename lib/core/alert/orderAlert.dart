import 'orderAlertStub.dart'
    if (dart.library.html) 'orderAlertWeb.dart' as platform;

/// Neu-Bestellung-Alarm für die Merchant-POS-Ansicht.
///
/// Im Web: kurzer Hinweiston (WebAudio) + System-Benachrichtigung, wenn der
/// Tab im Hintergrund ist. Auf Mobile/Desktop: System-Alarmton; Browser-
/// spezifische Teile (Benachrichtigung/Tab-Sichtbarkeit) sind dort No-Ops.
///
/// Plattform-spezifika stecken in `orderAlertStub.dart` (Default) und
/// `orderAlertWeb.dart` (bei `dart.library.html`) – gleiches Muster wie
/// [LocalCacheStorage].
class OrderAlert {
  const OrderAlert._();

  /// Aus einer User-Geste aufrufen: macht Autoplay-Audio und
  /// Benachrichtigungen „scharf" (Browser-Policy verlangt eine Interaktion).
  static void prime() => platform.prime();

  /// Fragt – sofern nötig – die Benachrichtigungserlaubnis an (Web).
  static void ensurePermission() => platform.ensurePermission();

  /// Ob die Seite/der Tab aktuell verborgen ist (Hintergrund). Mobile: false.
  static bool isPageHidden() => platform.isPageHidden();

  /// Setzt die Lautstärke für Hinweistöne (0.0–1.0; Web only, No-Op auf nativ).
  static void setVolume(double v) => platform.setVolume(v);

  /// Spielt einen kurzen Hinweiston.
  static void playTone() => platform.playTone();

  /// Zeigt eine System-Benachrichtigung (Web, nur bei erteilter Erlaubnis).
  static void showNotification(String title, String body) =>
      platform.showNotification(title, body);
}
