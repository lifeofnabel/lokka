// Web-only Implementierung (conditional import) – nutzt bewusst dart:html.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<bool> openExternalLink(String url) async {
  final cleanUrl = url.trim();
  if (cleanUrl.isEmpty) return false;
  html.window.open(cleanUrl, '_blank');
  return true;
}
