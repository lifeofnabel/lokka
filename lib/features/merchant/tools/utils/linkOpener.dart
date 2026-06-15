import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Öffnet eine externe URL plattformübergreifend: Web → neuer Tab, Mobile/Native
/// → externe App (Browser/WhatsApp). Ersetzt die vorherige Conditional-Import-
/// Konstruktion, deren Mobile-Variante ein No-Op war (#50) und deren Web-Variante
/// das deprecated `dart:html` nutzte.
Future<void> openExternalUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  try {
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!opened) debugPrint('openExternalUrl: konnte $url nicht öffnen');
  } catch (e) {
    debugPrint('openExternalUrl failed for $url: $e');
  }
}
