import '../config/cloudinaryConfig.dart';

class CloudinaryService {
  const CloudinaryService();

  Uri get uploadUri => CloudinaryConfig.uploadUri();

  bool get isConfigured {
    return CloudinaryConfig.cloudName.isNotEmpty &&
        CloudinaryConfig.uploadPreset.isNotEmpty;
  }
}
