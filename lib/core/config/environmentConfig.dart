import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvironmentConfig {
  const EnvironmentConfig._();

  static String get aiSuggestionEndpoint =>
      dotenv.env['AI_SUGGESTION_ENDPOINT'] ?? '';

  /// Geoapify Geocoding API-Key.
  /// TEMPORÄR während der Geo-Migration. Kette: .env → --dart-define →
  /// eingebauter Übergangskey. Hintergrund: `.env` ist ein Dotfile und wird
  /// von Firebase Hosting NIE deployt (firebase.json ignoriert `**/.*`) –
  /// ohne Fallback wäre Geoapify auf der Web-App grundsätzlich tot.
  /// TODO: Vor dem echten Release auf Backend-Proxy (Cloudflare Worker)
  /// umstellen und den eingebauten Key entfernen. Siehe docs/GEO_MIGRATION_AUDIT.md.
  static String get geoapifyApiKey {
    final fromEnv = dotenv.env['GEOAPIFY_API_KEY']?.trim() ?? '';
    if (fromEnv.isNotEmpty) return fromEnv;
    const fromDefine = String.fromEnvironment('GEOAPIFY_API_KEY');
    if (fromDefine.isNotEmpty) return fromDefine;
    return 'c2b55e47e79943cb910f3916df12086c'; // Übergangskey (Migration)
  }
}
