import 'dart:math';

/// Geteilte Standort-Helfer. Ersetzt die früher in Discover- und Partners-
/// Provider doppelt vorhandene Haversine-Implementierung.
class LocationUtils {
  const LocationUtils._();

  /// Großkreis-Distanz in km zwischen zwei Koordinaten (Haversine).
  static double distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * (sin(dLng / 2) * sin(dLng / 2));
    return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _rad(double degree) => degree * pi / 180;

  /// Menschlich lesbares Distanz-Label: „350 m", „1,2 km", „12 km".
  static String distanceLabel(double km) {
    if (km < 0) return '';
    if (km < 1) return '${(km * 1000).round()} m';
    if (km < 10) return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
    return '${km.round()} km';
  }
}
