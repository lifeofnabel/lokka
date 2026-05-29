import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/cloudinaryConfig.dart';
import '../models/uploadedMediaModel.dart';

class CloudinaryUploadException implements Exception {
  const CloudinaryUploadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CloudinaryService {
  CloudinaryService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri get uploadUri => CloudinaryConfig.uploadUri();

  bool get isConfigured {
    return CloudinaryConfig.cloudName.isNotEmpty &&
        CloudinaryConfig.uploadPreset.isNotEmpty;
  }

  Future<UploadedMediaModel> uploadBytes({
    required Uint8List bytes,
    required String fileName,
    String? folder,
  }) async {
    if (!isConfigured) {
      throw const CloudinaryUploadException(
        'Cloudinary ist nicht vollständig konfiguriert.',
      );
    }

    final request = http.MultipartRequest('POST', uploadUri)
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
        ),
      );

    final targetFolder = folder ?? CloudinaryConfig.folder;
    if (targetFolder.isNotEmpty) {
      request.fields['folder'] = targetFolder;
    }

    final response = await _client.send(request);
    final body = await response.stream.bytesToString();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudinaryUploadException(
        _readCloudinaryError(body) ??
            'Cloudinary Upload fehlgeschlagen (${response.statusCode}).',
      );
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    return UploadedMediaModel.fromMap({
      ...json,
      'createdAt': DateTime.now(),
    });
  }

  String? _readCloudinaryError(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final error = json['error'];
      if (error is Map<String, dynamic>) {
        return error['message'] as String?;
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
