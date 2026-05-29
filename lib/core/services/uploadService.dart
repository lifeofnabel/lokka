import '../models/uploadedMediaModel.dart';
import 'cloudinaryService.dart';

class UploadService {
  const UploadService({
    this.cloudinaryService = const CloudinaryService(),
  });

  final CloudinaryService cloudinaryService;

  Future<UploadedMediaModel?> uploadImage({
    required Object file,
    String? fileName,
  }) async {
    return null;
  }
}
