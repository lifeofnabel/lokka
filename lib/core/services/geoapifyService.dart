import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/environmentConfig.dart';

/// Ergebnis einer Geoapify-Geokodierung – strukturierte Adresse + Koordinaten.
class GeoResult {
  const GeoResult({
    required this.lat,
    required this.lng,
    required this.formatted,
    required this.street,
    required this.houseNumber,
    required this.postalCode,
    required this.city,
    required this.country,
    required this.district,
  });

  final double lat;
  final double lng;
  final String formatted;
  final String street;
  final String houseNumber;
  final String postalCode;
  final String city;
  final String country;

  /// Stadtteil/Bezirk (Suburb) – nur für Anzeige, ersetzt das Legacy-„area".
  final String district;

  bool get hasCoordinates => lat != 0 || lng != 0;

  factory GeoResult.fromGeoapify(Map<String, dynamic> p) {
    return GeoResult(
      lat: (p['lat'] as num?)?.toDouble() ?? 0,
      lng: (p['lon'] as num?)?.toDouble() ?? 0,
      formatted: (p['formatted'] ?? '').toString(),
      street: (p['street'] ?? '').toString(),
      houseNumber: (p['housenumber'] ?? '').toString(),
      postalCode: (p['postcode'] ?? '').toString(),
      city: (p['city'] ?? p['town'] ?? p['village'] ?? '').toString(),
      country: (p['country'] ?? '').toString(),
      district:
          (p['suburb'] ?? p['district'] ?? p['city_district'] ?? '').toString(),
    );
  }
}

/// Geoapify Geocoding (https://api.geoapify.com/v1/geocode).
/// Wandelt Adressen ↔ Koordinaten. Liefert null, wenn kein Key gesetzt ist oder
/// die Anfrage scheitert (Aufrufer fällt dann auf Bestands-/Offline-Logik zurück).
class GeoapifyService {
  GeoapifyService({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _apiKey = apiKey ?? EnvironmentConfig.geoapifyApiKey;

  final http.Client _client;
  final String _apiKey;

  static const _base = 'https://api.geoapify.com/v1/geocode';

  /// Bounding-Box für Hessen (lon1,lat1,lon2,lat2) – begrenzt Autocomplete.
  static const hessenRect = '7.77,49.39,10.24,51.66';

  bool get isConfigured => _apiKey.isNotEmpty;

  /// Adress-Vorschläge beim Tippen (Autocomplete), optional auf eine Bounding-Box
  /// begrenzt (z. B. [hessenRect]).
  Future<List<GeoResult>> autocomplete(String text, {String? filterRect}) async {
    if (!isConfigured || text.trim().length < 3) return const [];
    final params = {
      'text': text.trim(),
      'lang': 'de',
      'limit': '5',
      'format': 'json',
      'apiKey': _apiKey,
    };
    if (filterRect != null) params['filter'] = 'rect:$filterRect';
    final uri =
        Uri.parse('$_base/autocomplete').replace(queryParameters: params);
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return const [];
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final results = (body['results'] as List?) ?? const [];
      return results
          .map((r) => GeoResult.fromGeoapify(r as Map<String, dynamic>))
          .where((g) => g.hasCoordinates)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Adresse → Koordinaten + normalisierte Adresse.
  Future<GeoResult?> forwardGeocode({
    required String street,
    String houseNumber = '',
    String postalCode = '',
    String city = '',
    String country = 'Deutschland',
  }) async {
    if (!isConfigured) return null;
    final text = [
      '$street $houseNumber'.trim(),
      postalCode.trim(),
      city.trim(),
      country.trim(),
    ].where((s) => s.isNotEmpty).join(', ');
    if (text.isEmpty) return null;

    final uri = Uri.parse('$_base/search').replace(queryParameters: {
      'text': text,
      'lang': 'de',
      'limit': '1',
      'format': 'json',
      'apiKey': _apiKey,
    });
    return _fetch(uri);
  }

  /// Grobe Verortung anhand der Anfrage-IP (Geoapify IP-Geolocation).
  /// Kein Permission-Prompt, keine Adresse nötig – liefert Stadt + ungefähre
  /// Koordinaten. Nur so genau wie die IP (Stadt-/Provider-Ebene). Liefert null
  /// ohne Key oder bei Fehler (Aufrufer fällt auf Default zurück).
  Future<GeoResult?> ipLocate() async {
    if (!isConfigured) return null;
    final uri = Uri.parse('https://api.geoapify.com/v1/ipinfo')
        .replace(queryParameters: {'apiKey': _apiKey, 'lang': 'de'});
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final loc = body['location'] as Map<String, dynamic>?;
      final lat = (loc?['latitude'] as num?)?.toDouble();
      final lng = (loc?['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;
      final city = (body['city'] as Map<String, dynamic>?)?['name']?.toString() ??
          (body['state'] as Map<String, dynamic>?)?['name']?.toString() ??
          '';
      final country =
          (body['country'] as Map<String, dynamic>?)?['name']?.toString() ?? '';
      return GeoResult(
        lat: lat,
        lng: lng,
        formatted: city,
        street: '',
        houseNumber: '',
        postalCode: '',
        city: city,
        country: country,
        district: '',
      );
    } catch (_) {
      return null;
    }
  }

  /// Koordinaten → strukturierte Adresse (für Anzeige des User-Standorts).
  Future<GeoResult?> reverseGeocode(double lat, double lng) async {
    if (!isConfigured) return null;
    final uri = Uri.parse('$_base/reverse').replace(queryParameters: {
      'lat': '$lat',
      'lon': '$lng',
      'lang': 'de',
      'limit': '1',
      'format': 'json',
      'apiKey': _apiKey,
    });
    return _fetch(uri);
  }

  Future<GeoResult?> _fetch(Uri uri) async {
    try {
      // Timeout, damit Registrierung/Speichern nie am Geocoding hängen bleibt.
      final res =
          await _client.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final results = body['results'] as List?;
      if (results == null || results.isEmpty) return null;
      return GeoResult.fromGeoapify(results.first as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
