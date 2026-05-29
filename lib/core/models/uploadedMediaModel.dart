import 'package:cloud_firestore/cloud_firestore.dart';

class UploadedMediaModel {
  const UploadedMediaModel({
    required this.url,
    required this.secureUrl,
    required this.publicId,
    required this.format,
    required this.width,
    required this.height,
    required this.bytes,
    this.createdAt,
  });

  final String url;
  final String secureUrl;
  final String publicId;
  final String format;
  final int width;
  final int height;
  final int bytes;
  final DateTime? createdAt;

  factory UploadedMediaModel.fromMap(Map<String, dynamic> map) {
    return UploadedMediaModel(
      url: map['url'] as String? ?? '',
      secureUrl: map['secureUrl'] as String? ?? map['secure_url'] as String? ?? '',
      publicId: map['publicId'] as String? ?? map['public_id'] as String? ?? '',
      format: map['format'] as String? ?? '',
      width: (map['width'] as num?)?.toInt() ?? 0,
      height: (map['height'] as num?)?.toInt() ?? 0,
      bytes: (map['bytes'] as num?)?.toInt() ?? 0,
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
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  return DateTime.tryParse(value.toString());
}
