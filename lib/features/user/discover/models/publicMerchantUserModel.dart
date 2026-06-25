import '../../../../core/models/menuDesign.dart';

class PublicMerchantUserModel {
  const PublicMerchantUserModel({
    required this.merchantId,
    required this.shopName,
    required this.description,
    required this.shopType,
    required this.address,
    required this.fullAddress,
    required this.logoUrl,
    required this.coverUrl,
    required this.phone,
    required this.isActive,
    required this.isPublic,
    this.lat,
    this.lng,
    this.openingHours,
    this.featuresPublic = const [],
    this.menuExternalUrl,
    this.menuExternalEnabled = false,
    this.menuIntegratedEnabled = false,
    this.menuStyle = const MenuDesign(),
    this.city = '',
    this.socialLinks = const {},
    this.galleryImages = const [],
    this.origins = const [],
    this.handle = '',
    this.updatedAt,
  });

  final String merchantId;
  final String shopName;
  final String description;
  final String shopType;
  final String address;
  final String fullAddress;
  final String logoUrl;
  final String coverUrl;
  final String phone;
  final bool isActive;
  final bool isPublic;
  final double? lat;
  final double? lng;
  final Map<String, dynamic>? openingHours;
  final List<String> featuresPublic;

  /// Externer Speisekarten-Link (z. B. eigene Website / PDF).
  final String? menuExternalUrl;

  /// Merchant zeigt einen externen Speisekarten-Link an.
  final bool menuExternalEnabled;

  /// Merchant hat die in Lokka integrierte Speisekarte aktiviert.
  final bool menuIntegratedEnabled;

  /// Gestaltung der integrierten Kundenkarte (Vorlage, Farbe, Theme, Spalten).
  final MenuDesign menuStyle;

  /// Stadt aus der Adresse – ersetzt das Legacy-„area" in der Anzeige.
  final String city;

  /// Social-Links: website / instagram / tiktok / facebook (nur befüllte).
  final Map<String, String> socialLinks;

  /// Bis zu 5 Laden-Bilder (inkl. Cover) aus den Shopdaten.
  final List<String> galleryImages;

  /// Herkunft/Küchen (z. B. „Italienisch", „Türkisch") aus den Shopdaten.
  final List<String> origins;

  /// Frei wählbarer, eindeutiger Profil-Handle (Slug) für den schönen Link
  /// `<origin>/<handle>` (Insta-Stil). Klein, [a-z0-9-]. Leer = nicht gesetzt.
  final String handle;

  final DateTime? updatedAt;

  factory PublicMerchantUserModel.fromMap(Map<String, dynamic> map) {
    return PublicMerchantUserModel(
      merchantId: map['merchantId'] as String? ?? '',
      shopName: map['shopName'] as String? ?? '',
      description: map['description'] as String? ?? '',
      shopType: map['shopType'] as String? ?? '',
      address: map['address'] as String? ?? '',
      fullAddress: map['fullAddress'] as String? ?? map['address'] as String? ?? '',
      logoUrl: map['logoUrl'] as String? ?? '',
      coverUrl: map['coverUrl'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? false,
      isPublic: map['isPublic'] as bool? ?? false,
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      openingHours: map['openingHours'] as Map<String, dynamic>?,
      featuresPublic: _features(map['featuresPublic']),
      menuExternalUrl: (map['menuExternalUrl'] as String?)?.trim().isNotEmpty == true
          ? (map['menuExternalUrl'] as String).trim()
          : null,
      menuExternalEnabled: map['menuExternalEnabled'] as bool? ?? false,
      menuIntegratedEnabled: map['menuIntegratedEnabled'] as bool? ?? false,
      menuStyle: MenuDesign.fromMap(map),
      city: map['city'] as String? ?? '',
      socialLinks: _stringMap(map['socialLinks']),
      galleryImages: (map['galleryImages'] as List?)
              ?.map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList() ??
          const [],
      origins: (map['origins'] as List?)
              ?.map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList() ??
          const [],
      handle: (map['handle'] as String? ?? '').trim().toLowerCase(),
      updatedAt: _tsToDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'merchantId': merchantId,
      'shopName': shopName,
      'description': description,
      'shopType': shopType,
      'address': address,
      'fullAddress': fullAddress,
      'logoUrl': logoUrl,
      'coverUrl': coverUrl,
      'phone': phone,
      'isActive': isActive,
      'isPublic': isPublic,
      'lat': lat,
      'lng': lng,
      'openingHours': openingHours,
      'featuresPublic': featuresPublic,
      'menuExternalUrl': menuExternalUrl,
      'menuExternalEnabled': menuExternalEnabled,
      'menuIntegratedEnabled': menuIntegratedEnabled,
      ...menuStyle.toMap(),
      'city': city,
      'socialLinks': socialLinks,
      'galleryImages': galleryImages,
      'origins': origins,
      'handle': handle,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Anzeige-Ort: Stadt aus der Adresse.
  String get displayCity => city;

  bool get hasCoordinates => lat != null && lng != null;

  /// Gültiger externer Link vorhanden und aktiviert.
  bool get hasExternalMenu =>
      menuExternalEnabled && (menuExternalUrl?.isNotEmpty ?? false);

  /// Irgendeine Speisekarte (intern oder extern) verfügbar.
  bool get hasMenu => hasExternalMenu || menuIntegratedEnabled;
}

Map<String, String> _stringMap(dynamic value) {
  if (value is Map) {
    final out = <String, String>{};
    value.forEach((k, v) {
      final s = (v ?? '').toString().trim();
      if (s.isNotEmpty) out[k.toString()] = s;
    });
    return out;
  }
  return const {};
}

List<String> _features(dynamic value) {
  if (value is List) {
    return value.map((e) => e.toString()).toList();
  }
  if (value is Map) {
    return value.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key.toString())
        .toList();
  }
  return const [];
}

DateTime? _tsToDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  try {
    return (v as dynamic).toDate() as DateTime;
  } catch (_) {
    return DateTime.tryParse(v.toString());
  }
}
