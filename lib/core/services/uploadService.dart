import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import '../models/uploadedMediaModel.dart';
import 'cloudinaryService.dart';

enum UploadImageType {
  logo,
  cover,
  item,
  itemWide,
  categoryIcon,
  feedPost,
  stampCard,
  stampCardSide,
  stampCardTop,
  stampCardBackground,
  pointsReward,
  coupon,
  general,
  displayLayout,
}

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
    final result = await FilePicker.platform.pickFiles(
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
    return pickAndUploadOptimizedImage(type: UploadImageType.general);
  }

  Future<UploadedMediaModel?> pickAndUploadOptimizedImage({
    required UploadImageType type,
  }) async {
    final file = await pickImageWithFilePicker();
    if (file == null) return null;
    final prepared = _prepareImage(
      bytes: file.bytes,
      fileName: file.fileName,
      type: type,
    );
    return cloudinaryService.uploadBytes(
      bytes: prepared.bytes,
      fileName: prepared.fileName,
    );
  }

  Future<UploadedMediaModel> uploadOptimizedImageBytes({
    required Uint8List bytes,
    required String fileName,
    required UploadImageType type,
  }) {
    final prepared = _prepareImage(
      bytes: bytes,
      fileName: fileName,
      type: type,
    );
    return cloudinaryService.uploadBytes(
      bytes: prepared.bytes,
      fileName: prepared.fileName,
    );
  }

  PickedUploadFile _prepareImage({
    required Uint8List bytes,
    required String fileName,
    required UploadImageType type,
  }) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return PickedUploadFile(bytes: bytes, fileName: fileName);
    }

    final spec = _specFor(type);
    final cropped = _centerCrop(decoded, spec.aspectWidth, spec.aspectHeight);
    final resized = img.copyResize(
      cropped,
      width: spec.width,
      height: spec.height,
      interpolation: img.Interpolation.average,
    );
    final encoded = _encodeWithinLimit(resized, spec);
    return PickedUploadFile(
      bytes: encoded,
      fileName: _jpgFileName(fileName),
    );
  }

  Uint8List _encodeWithinLimit(img.Image source, _ImageSpec spec) {
    var current = source;
    var quality = spec.quality;

    for (var attempt = 0; attempt < 8; attempt++) {
      final encoded = Uint8List.fromList(
        img.encodeJpg(current, quality: quality),
      );
      if (encoded.lengthInBytes <= spec.maxBytes || attempt == 7) {
        return encoded;
      }

      if (quality > spec.minQuality) {
        quality = (quality - 8)
            .clamp(spec.minQuality, spec.quality)
            .toInt();
      } else {
        current = img.copyResize(
          current,
          width: (current.width * 0.86).round(),
          height: (current.height * 0.86).round(),
          interpolation: img.Interpolation.average,
        );
      }
    }

    return Uint8List.fromList(img.encodeJpg(current, quality: spec.minQuality));
  }

  img.Image _centerCrop(img.Image source, int aspectWidth, int aspectHeight) {
    final targetRatio = aspectWidth / aspectHeight;
    final sourceRatio = source.width / source.height;

    int width = source.width;
    int height = source.height;
    if (sourceRatio > targetRatio) {
      width = (source.height * targetRatio).round();
    } else {
      height = (source.width / targetRatio).round();
    }

    final x = ((source.width - width) / 2).round();
    final y = ((source.height - height) / 2).round();
    return img.copyCrop(source, x: x, y: y, width: width, height: height);
  }

  _ImageSpec _specFor(UploadImageType type) {
    return switch (type) {
      UploadImageType.logo => const _ImageSpec(
          width: 512,
          height: 512,
          aspectWidth: 1,
          aspectHeight: 1,
          quality: 86,
          maxBytes: 650 * 1024,
        ),
      UploadImageType.cover => const _ImageSpec(
          width: 1600,
          height: 900,
          aspectWidth: 16,
          aspectHeight: 9,
          quality: 84,
          maxBytes: 3 * 1024 * 1024,
        ),
      UploadImageType.item => const _ImageSpec(
          width: 1024,
          height: 1024,
          aspectWidth: 1,
          aspectHeight: 1,
          quality: 84,
          maxBytes: 1400 * 1024,
        ),
      UploadImageType.itemWide => const _ImageSpec(
          width: 1280,
          height: 720,
          aspectWidth: 16,
          aspectHeight: 9,
          quality: 84,
          maxBytes: 1400 * 1024,
        ),
      UploadImageType.categoryIcon => const _ImageSpec(
          width: 256,
          height: 256,
          aspectWidth: 1,
          aspectHeight: 1,
          quality: 86,
          maxBytes: 320 * 1024,
        ),
      UploadImageType.feedPost => const _ImageSpec(
          width: 1200,
          height: 1200,
          aspectWidth: 1,
          aspectHeight: 1,
          quality: 84,
          maxBytes: 1600 * 1024,
        ),
      UploadImageType.stampCard => const _ImageSpec(
          width: 1200,
          height: 800,
          aspectWidth: 3,
          aspectHeight: 2,
          quality: 84,
          maxBytes: 1300 * 1024,
        ),
      UploadImageType.stampCardSide => const _ImageSpec(
          width: 800,
          height: 800,
          aspectWidth: 1,
          aspectHeight: 1,
          quality: 84,
          maxBytes: 850 * 1024,
        ),
      UploadImageType.stampCardTop => const _ImageSpec(
          width: 1280,
          height: 720,
          aspectWidth: 16,
          aspectHeight: 9,
          quality: 84,
          maxBytes: 1200 * 1024,
        ),
      UploadImageType.stampCardBackground => const _ImageSpec(
          width: 1280,
          height: 720,
          aspectWidth: 16,
          aspectHeight: 9,
          quality: 82,
          maxBytes: 1100 * 1024,
        ),
      UploadImageType.pointsReward => const _ImageSpec(
          width: 1024,
          height: 1024,
          aspectWidth: 1,
          aspectHeight: 1,
          quality: 84,
          maxBytes: 1200 * 1024,
        ),
      UploadImageType.coupon => const _ImageSpec(
          width: 1200,
          height: 800,
          aspectWidth: 3,
          aspectHeight: 2,
          quality: 84,
          maxBytes: 1300 * 1024,
        ),
      UploadImageType.general => const _ImageSpec(
          width: 1200,
          height: 1200,
          aspectWidth: 1,
          aspectHeight: 1,
          quality: 84,
          maxBytes: 2 * 1024 * 1024,
        ),
      UploadImageType.displayLayout => const _ImageSpec(
          width: 1920,
          height: 1080,
          aspectWidth: 16,
          aspectHeight: 9,
          quality: 86,
          maxBytes: 4 * 1024 * 1024,
        ),
    };
  }

  String _jpgFileName(String fileName) {
    final clean = fileName.trim().isEmpty ? 'lokka-upload' : fileName.trim();
    final dot = clean.lastIndexOf('.');
    final base = dot > 0 ? clean.substring(0, dot) : clean;
    return '$base.jpg';
  }
}

class _ImageSpec {
  const _ImageSpec({
    required this.width,
    required this.height,
    required this.aspectWidth,
    required this.aspectHeight,
    required this.quality,
    required this.maxBytes,
    // ignore: unused_element_parameter — Tuning-Untergrenze, bewusst fix bei 62
    this.minQuality = 62,
  });

  final int width;
  final int height;
  final int aspectWidth;
  final int aspectHeight;
  final int quality;
  final int maxBytes;
  final int minQuality;
}
