import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../models/uploadedMediaModel.dart';
import 'cloudinaryService.dart';

class PickedUploadFile {
  const PickedUploadFile({
    required this.bytes,
    required this.fileName,
  });

  final Uint8List bytes;
  final String fileName;
}

class UploadService {
  const UploadService({
    required this.cloudinaryService,
  });

  final CloudinaryService cloudinaryService;

  Future<PickedUploadFile?> pickImageWithFilePicker() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return null;

    return PickedUploadFile(bytes: bytes, fileName: file.name);
  }

  Future<PickedUploadFile?> pickImageWithImagePicker() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return null;

    return PickedUploadFile(
      bytes: await image.readAsBytes(),
      fileName: image.name,
    );
  }

  Future<UploadedMediaModel?> pickAndUploadImage() async {
    final file = await pickImageWithFilePicker();
    if (file == null) return null;
    return cloudinaryService.uploadBytes(
      bytes: file.bytes,
      fileName: file.fileName,
    );
  }
}
