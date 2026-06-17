import 'dart:convert';

import 'package:http/http.dart' as http;

/// Live-Übersetzung der Kundensicht über die kostenlose MyMemory-API
/// (ohne API-Key, wie in Qoucher/Fuze). Übersetzt on-demand; das UI cached
/// die Ergebnisse, damit pro Text nur einmal angefragt wird.
class TranslatorService {
  const TranslatorService._();

  static const String _baseUrl = 'https://api.mymemory.translated.net/get';

  /// 'original' = keine Übersetzung (Merchant-Originaltext anzeigen).
  static const Map<String, String> supportedLanguages = {
    'original': 'Original',
    'de': 'Deutsch',
    'en': 'English',
    'ar': 'العربية',
    'tr': 'Türkçe',
    'fr': 'Français',
    'es': 'Español',
    'it': 'Italiano',
    'ru': 'Русский',
  };

  static bool isRtl(String langCode) => langCode == 'ar';

  /// Übersetzt [text] nach [targetLang]. Bei Fehler/leerem Ergebnis bleibt der
  /// Originaltext erhalten (nie ein Crash, nie leere Karte).
  static Future<String> translate({
    required String text,
    required String targetLang,
    String sourceLang = 'de',
  }) async {
    final clean = text.trim();
    if (clean.isEmpty || targetLang == 'original' || targetLang == sourceLang) {
      return text;
    }
    try {
      final uri = Uri.parse(
        '$_baseUrl?q=${Uri.encodeComponent(clean)}&langpair=$sourceLang|$targetLang',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return text;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['responseData'];
      if (data is Map<String, dynamic>) {
        final translated = data['translatedText'];
        if (translated is String && translated.trim().isNotEmpty) {
          return translated;
        }
      }
    } catch (_) {
      // Netz-/Parsing-Fehler: Original behalten.
    }
    return text;
  }
}
