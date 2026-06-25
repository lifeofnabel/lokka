// Web-only Implementierung (conditional import) – nutzt bewusst dart:html.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<String?> readCacheValue(String key) async {
  try {
    return html.window.localStorage[key];
  } catch (_) {
    return null;
  }
}

Future<void> writeCacheValue(String key, String value) async {
  try {
    html.window.localStorage[key] = value;
  } catch (_) {}
}

Future<void> removeCacheValue(String key) async {
  try {
    html.window.localStorage.remove(key);
  } catch (_) {}
}
