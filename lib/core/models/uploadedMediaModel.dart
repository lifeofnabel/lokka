import 'package:cloud_firestore/cloud_firestore.dart';

/// Ergebnis eines Bild-Uploads, persistierbar in Firestore.
///
/// Seit der Migration auf Firebase Storage gilt:
/// - [url] / [secureUrl]   = Firebase-Storage-Download-URL des Hauptbilds.
/// - [publicId]            = Storage-Objektpfad (für Delete/Replace).
/// - [thumbUrl] / [thumbSecureUrl] / [thumbPublicId] = optionale Thumbnail-
///   Variante (für Listen/Feed).
///
/// Die Feldnamen bleiben aus Kompatibilitätsgründen erhalten; [fromMap] liest
/// zusätzlich die historischen `secure_url` / `public_id` sowie `imageUrl` /
/// `downloadUrl`, damit alte Dokumente (inkl. evtl. verbliebener Cloudinary-
/// URLs) weiterhin korrekt geladen werden.
class UploadedMediaModel {
  const UploadedMediaModel({
    required this.url,
    required this.secureUrl,
    required this.publicId,
    required this.format,
    required this.width,
    required this.height,
    required this.bytes,
    this.thumbUrl,
    this.thumbSecureUrl,
    this.thumbPublicId,
    this.thumbBytes,
    this.mediaType,
    this.createdAt,
  });

  final String url;
  final String secureUrl;
  final String publicId;
  final String format;
  final int width;
  final int height;
  final int bytes;
  final String? thumbUrl;
  final String? thumbSecureUrl;
  final String? thumbPublicId;
  final int? thumbBytes;
  final String? mediaType;
  final DateTime? createdAt;

  factory UploadedMediaModel.fromMap(Map<String, dynamic> map) {
    return UploadedMediaModel(
      url: map['url'] as String? ??
          map['imageUrl'] as String? ??
          map['downloadUrl'] as String? ??
          '',
      secureUrl: map['secureUrl'] as String? ??
          map['secure_url'] as String? ??
          map['imageUrl'] as String? ??
          map['downloadUrl'] as String? ??
          '',
      publicId: map['publicId'] as String? ?? map['public_id'] as String? ?? '',
      format: map['format'] as String? ?? '',
      width: (map['width'] as num?)?.toInt() ?? 0,
      height: (map['height'] as num?)?.toInt() ?? 0,
      bytes: (map['bytes'] as num?)?.toInt() ?? 0,
      thumbUrl: map['thumbUrl'] as String?,
      thumbSecureUrl:
          map['thumbSecureUrl'] as String? ?? map['thumb_secure_url'] as String?,
      thumbPublicId:
          map['thumbPublicId'] as String? ?? map['thumb_public_id'] as String?,
      thumbBytes: (map['thumbBytes'] as num?)?.toInt(),
      mediaType: map['mediaType'] as String?,
      createdAt: _date(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'secureUrl': secureUrl,
      'publicId': publicId,
      'format': format,
      'width': width,
      'height': height,
      'bytes': bytes,
      'thumbUrl': thumbUrl,
      'thumbSecureUrl': thumbSecureUrl,
      'thumbPublicId': thumbPublicId,
      'thumbBytes': thumbBytes,
      'mediaType': mediaType,
      'createdAt': createdAt,
    };
  }

  UploadedMediaModel copyWith({
    String? url,
    String? secureUrl,
    String? publicId,
    String? format,
    int? width,
    int? height,
    int? bytes,
    String? thumbUrl,
    String? thumbSecureUrl,
    String? thumbPublicId,
    int? thumbBytes,
    String? mediaType,
    DateTime? createdAt,
  }) {
    return UploadedMediaModel(
      url: url ?? this.url,
      secureUrl: secureUrl ?? this.secureUrl,
      publicId: publicId ?? this.publicId,
      format: format ?? this.format,
      width: width ?? this.width,
      height: height ?? this.height,
      bytes: bytes ?? this.bytes,
      thumbUrl: thumbUrl ?? this.thumbUrl,
      thumbSecureUrl: thumbSecureUrl ?? this.thumbSecureUrl,
      thumbPublicId: thumbPublicId ?? this.thumbPublicId,
      thumbBytes: thumbBytes ?? this.thumbBytes,
      mediaType: mediaType ?? this.mediaType,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Beste anzeigbare Volldarstellungs-URL.
  String get displayUrl => secureUrl.isNotEmpty ? secureUrl : url;

  /// Kleinere Vorschau-URL (Thumbnail) für Listen/Feed; fällt auf
  /// [displayUrl] zurück, wenn keine Variante existiert.
  String get previewUrl {
    final thumb = (thumbSecureUrl?.isNotEmpty ?? false)
        ? thumbSecureUrl!
        : (thumbUrl?.isNotEmpty ?? false)
            ? thumbUrl!
            : '';
    return thumb.isNotEmpty ? thumb : displayUrl;
  }

  /// Storage-Objektpfad des Hauptbilds (für Delete/Replace). Leer bei
  /// Altbeständen, die nur als URL gespeichert wurden.
  String get storagePath => publicId;

  /// Storage-Objektpfad des Thumbnails, falls vorhanden.
  String? get thumbStoragePath => thumbPublicId;
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  return DateTime.tryParse(value.toString());
}
