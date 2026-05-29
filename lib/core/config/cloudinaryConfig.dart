import 'environmentConfig.dart';

class CloudinaryConfig {
  const CloudinaryConfig._();

  static String get cloudName => EnvironmentConfig.cloudinaryCloudName;
  static String get uploadPreset => EnvironmentConfig.cloudinaryUploadPreset;
  static String get folder => EnvironmentConfig.cloudinaryFolder;

  static Uri uploadUri() {
    return Uri.https(
      'api.cloudinary.com',
      '/v1_1/$cloudName/image/upload',
    );
  }
}
