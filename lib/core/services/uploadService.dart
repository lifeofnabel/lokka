import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

import '../models/uploadedMediaModel.dart';
import 'storageService.dart';

/// Logische Bildarten der App. Jede Art bestimmt Zuschnitt, Zielgröße,
/// Kompression, Thumbnail-Variante sowie den Ziel-Ordner im Storage.
enum UploadImageType {
  userProfile,
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

/// Owner-Scope eines Uploads – steuert den Wurzel-Ordner (`merchants/` vs.
/// `users/`) und damit auch die Security-Rule, die den Schreibzugriff prüft.
enum _OwnerScope { merchant, user }

/// Wählt, bereitet (Crop/Resize/EXIF/Kompression) und lädt Bilder über die
/// zentrale [StorageService]-Schicht hoch. Erzeugt zusätzlich automatisch eine
/// kleine Thumbnail-Variante für Listen-/Feed-Darstellungen.
///
/// Die öffentlichen Methoden sind bewusst stabil gehalten, damit bestehende
/// Aufrufer unverändert weiterlaufen.
class UploadService {
  UploadService({
    required this.storageService,
    FirebaseAuth? auth,
    Uuid? uuid,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _uuid = uuid ?? const Uuid();

  final StorageService storageService;
  final FirebaseAuth _auth;
  final Uuid _uuid;

  /// Sicherheitsgrenze, um sehr große Eingaben gar nicht erst zu dekodieren
  /// (RAM-Schutz, besonders im Web).
  static const int _maxInputBytes = 25 * 1024 * 1024;

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

  /// Max. Eingabegröße für Menü-PDFs (Mehrseiter mit Fotos können größer sein
  /// als ein einzelnes Bild, daher großzügiger als der Bild-Guard).
  static const int _maxPdfBytes = 15 * 1024 * 1024;

  /// Wählt eine PDF-Datei (z. B. gescannte Speisekarte/Katalog) und lädt sie
  /// ROH hoch – ohne Bild-Aufbereitung (kein Crop/Resize/EXIF), da es kein
  /// Bild ist. Gibt die öffentliche Download-URL zurück; sie wird 1:1 wie ein
  /// getippter externer Speisekarten-Link behandelt (`menuExternalUrl`).
  /// Rückgabe null = Nutzer hat die Auswahl abgebrochen.
  Future<String?> pickAndUploadMenuPdf({String? ownerId}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return null;

    if (bytes.lengthInBytes > _maxPdfBytes) {
      throw const StorageException(
        'Die PDF ist zu groß (max. 15 MB). Bitte eine kleinere Datei wählen.',
      );
    }

    final uid = (ownerId?.isNotEmpty ?? false)
        ? ownerId!
        : _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      throw const StorageException(
        'Bitte zuerst anmelden, um eine Datei hochzuladen.',
      );
    }

    final id = _uuid.v4();
    final uploaded = await storageService.uploadBytes(
      path: '${StoragePaths.merchantsRoot}/$uid/menu/$id.pdf',
      bytes: bytes,
      contentType: 'application/pdf',
      customMetadata: {'type': 'menuPdf'},
    );
    return uploaded.downloadUrl;
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
    String? ownerId,
  }) async {
    final file = await pickImageWithFilePicker();
    if (file == null) return null;
    return uploadOptimizedImageBytes(
      bytes: file.bytes,
      fileName: file.fileName,
      type: type,
      ownerId: ownerId,
    );
  }

  /// Bereitet [bytes] auf und lädt Haupt- (+ ggf. Thumbnail-)Bild hoch.
  ///
  /// [ownerId] überschreibt den abgeleiteten Eigentümer (Standard: aktuell
  /// angemeldete UID). Wirft [StorageException] mit nutzerfreundlicher Meldung
  /// bei ungültigem Format, fehlender Anmeldung oder Upload-Fehlern.
  Future<UploadedMediaModel> uploadOptimizedImageBytes({
    required Uint8List bytes,
    required String fileName,
    required UploadImageType type,
    String? ownerId,
    void Function(double progress)? onProgress,
  }) async {
    final uid = (ownerId?.isNotEmpty ?? false)
        ? ownerId!
        : _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      throw const StorageException(
        'Bitte zuerst anmelden, um Bilder hochzuladen.',
      );
    }

    // Bild-Aufbereitung (decode/resize/encode) ist CPU-schwer. Auf Mobile in
    // einen Hintergrund-Isolate auslagern, damit die UI flüssig bleibt. Im Web
    // gibt es keine Isolates → läuft dort inline.
    final prepared = kIsWeb
        ? _prepareImage(bytes: bytes, type: type)
        : await compute(_prepareImageTask, _PrepareRequest(bytes, type));
    final folder = _folderFor(type, uid);
    final id = _uuid.v4();

    final main = await storageService.uploadBytes(
      path: '$folder/$id.jpg',
      bytes: prepared.bytes,
      contentType: 'image/jpeg',
      customMetadata: {
        'type': type.name,
        'width': '${prepared.width}',
        'height': '${prepared.height}',
      },
      onProgress: onProgress,
    );

    String? thumbUrl;
    String? thumbPath;
    int? thumbBytes;
    if (prepared.thumbBytes != null) {
      final thumb = await storageService.uploadBytes(
        path: '$folder/${id}_thumb.jpg',
        bytes: prepared.thumbBytes!,
        contentType: 'image/jpeg',
        customMetadata: {'type': '${type.name}_thumb'},
      );
      thumbUrl = thumb.downloadUrl;
      thumbPath = thumb.path;
      thumbBytes = thumb.bytes;
    }

    return UploadedMediaModel(
      url: main.downloadUrl,
      secureUrl: main.downloadUrl,
      publicId: main.path,
      format: 'jpg',
      width: prepared.width,
      height: prepared.height,
      bytes: main.bytes,
      thumbUrl: thumbUrl,
      thumbSecureUrl: thumbUrl,
      thumbPublicId: thumbPath,
      thumbBytes: thumbBytes,
      mediaType: 'image',
      createdAt: DateTime.now(),
    );
  }

  static _PreparedImage _prepareImage({
    required Uint8List bytes,
    required UploadImageType type,
  }) {
    if (bytes.lengthInBytes > _maxInputBytes) {
      throw const StorageException(
        'Das Bild ist zu groß (max. 25 MB). Bitte ein kleineres Bild wählen.',
      );
    }

    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const StorageException(
        'Dieses Bildformat wird nicht unterstützt. Bitte JPG, PNG oder WebP verwenden.',
      );
    }

    // EXIF-Orientierung anwenden, damit Hochformat-Fotos nicht gedreht landen.
    final oriented = img.bakeOrientation(decoded);

    final spec = _specFor(type);
    final cropped = _centerCrop(oriented, spec.aspectWidth, spec.aspectHeight);
    final resized = img.copyResize(
      cropped,
      width: spec.width,
      height: spec.height,
      interpolation: img.Interpolation.average,
    );
    final encoded = _encodeWithinLimit(resized, spec);

    Uint8List? thumb;
    final thumbEdge = spec.thumbnailEdge;
    if (thumbEdge != null && thumbEdge < spec.width) {
      final thumbHeight =
          (thumbEdge * spec.aspectHeight / spec.aspectWidth).round();
      final thumbImage = img.copyResize(
        resized,
        width: thumbEdge,
        height: thumbHeight,
        interpolation: img.Interpolation.average,
      );
      thumb = Uint8List.fromList(img.encodeJpg(thumbImage, quality: 78));
    }

    return _PreparedImage(
      bytes: encoded,
      width: resized.width,
      height: resized.height,
      thumbBytes: thumb,
    );
  }

  static Uint8List _encodeWithinLimit(img.Image source, _ImageSpec spec) {
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
        quality = (quality - 8).clamp(spec.minQuality, spec.quality).toInt();
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

  static img.Image _centerCrop(img.Image source, int aspectWidth, int aspectHeight) {
    final targetRatio = aspectWidth / aspectHeight;
    final sourceRatio = source.width / source.height;
    // Bereits passendes Seitenverhältnis (z. B. vorab quadratisch zugeschnitten)
    // → keinen unnötigen Kopier-Crop machen.
    if ((sourceRatio - targetRatio).abs() < 0.01) return source;

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

  /// Vollständiger Ziel-Ordner (ohne Dateiname) für [type] und Eigentümer [uid].
  String _folderFor(UploadImageType type, String uid) {
    final category = _categoryFor(type);
    return switch (_scopeFor(type)) {
      _OwnerScope.merchant => '${StoragePaths.merchantsRoot}/$uid/$category',
      _OwnerScope.user => '${StoragePaths.usersRoot}/$uid/$category',
    };
  }

  _OwnerScope _scopeFor(UploadImageType type) {
    return switch (type) {
      UploadImageType.userProfile ||
      UploadImageType.general =>
        _OwnerScope.user,
      _ => _OwnerScope.merchant,
    };
  }

  String _categoryFor(UploadImageType type) {
    return switch (type) {
      UploadImageType.userProfile => 'profile',
      UploadImageType.general => 'uploads',
      UploadImageType.logo => 'profile',
      UploadImageType.cover => 'cover',
      UploadImageType.feedPost => 'offers',
      UploadImageType.coupon => 'offers',
      UploadImageType.item => 'catalog',
      UploadImageType.itemWide => 'catalog',
      UploadImageType.categoryIcon => 'catalog',
      UploadImageType.stampCard => 'wallet',
      UploadImageType.stampCardSide => 'wallet',
      UploadImageType.stampCardTop => 'wallet',
      UploadImageType.stampCardBackground => 'wallet',
      UploadImageType.pointsReward => 'wallet',
      UploadImageType.displayLayout => 'displayStudio',
    };
  }

  static _ImageSpec _specFor(UploadImageType type) {
    return switch (type) {
      UploadImageType.userProfile => const _ImageSpec(
          width: 600,
          height: 600,
          aspectWidth: 1,
          aspectHeight: 1,
          quality: 86,
          maxBytes: 500 * 1024,
        ),
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
          thumbnailEdge: 600,
        ),
      UploadImageType.item => const _ImageSpec(
          width: 1024,
          height: 1024,
          aspectWidth: 1,
          aspectHeight: 1,
          quality: 84,
          maxBytes: 1400 * 1024,
          thumbnailEdge: 500,
        ),
      UploadImageType.itemWide => const _ImageSpec(
          width: 1280,
          height: 720,
          aspectWidth: 16,
          aspectHeight: 9,
          quality: 84,
          maxBytes: 1400 * 1024,
          thumbnailEdge: 500,
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
          thumbnailEdge: 500,
        ),
      UploadImageType.stampCard => const _ImageSpec(
          width: 1200,
          height: 800,
          aspectWidth: 3,
          aspectHeight: 2,
          quality: 84,
          maxBytes: 1300 * 1024,
          thumbnailEdge: 500,
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
          thumbnailEdge: 500,
        ),
      UploadImageType.stampCardBackground => const _ImageSpec(
          width: 1280,
          height: 720,
          aspectWidth: 16,
          aspectHeight: 9,
          quality: 82,
          maxBytes: 1100 * 1024,
          thumbnailEdge: 500,
        ),
      UploadImageType.pointsReward => const _ImageSpec(
          width: 1024,
          height: 1024,
          aspectWidth: 1,
          aspectHeight: 1,
          quality: 84,
          maxBytes: 1200 * 1024,
          thumbnailEdge: 500,
        ),
      UploadImageType.coupon => const _ImageSpec(
          width: 1200,
          height: 800,
          aspectWidth: 3,
          aspectHeight: 2,
          quality: 84,
          maxBytes: 1300 * 1024,
          thumbnailEdge: 500,
        ),
      UploadImageType.general => const _ImageSpec(
          width: 1200,
          height: 1200,
          aspectWidth: 1,
          aspectHeight: 1,
          quality: 84,
          maxBytes: 2 * 1024 * 1024,
          thumbnailEdge: 500,
        ),
      UploadImageType.displayLayout => const _ImageSpec(
          width: 1920,
          height: 1080,
          aspectWidth: 16,
          aspectHeight: 9,
          quality: 86,
          maxBytes: 4 * 1024 * 1024,
          thumbnailEdge: 640,
        ),
    };
  }
}

/// Eingabe für die Bild-Aufbereitung im Hintergrund-Isolate (via `compute`).
class _PrepareRequest {
  const _PrepareRequest(this.bytes, this.type);
  final Uint8List bytes;
  final UploadImageType type;
}

/// Isolate-Einstieg: ruft die (zustandslose) statische Aufbereitung auf.
_PreparedImage _prepareImageTask(_PrepareRequest request) =>
    UploadService._prepareImage(bytes: request.bytes, type: request.type);

class _ImageSpec {
  const _ImageSpec({
    required this.width,
    required this.height,
    required this.aspectWidth,
    required this.aspectHeight,
    required this.quality,
    required this.maxBytes,
    this.thumbnailEdge,
    // ignore: unused_element_parameter — Tuning-Untergrenze, bewusst fix bei 62
    this.minQuality = 62,
  });

  final int width;
  final int height;
  final int aspectWidth;
  final int aspectHeight;
  final int quality;
  final int maxBytes;

  /// Breite der optionalen Thumbnail-Variante. `null` = kein Thumbnail
  /// (z. B. ohnehin kleine Icons/Logos).
  final int? thumbnailEdge;
  final int minQuality;
}

class _PreparedImage {
  const _PreparedImage({
    required this.bytes,
    required this.width,
    required this.height,
    this.thumbBytes,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final Uint8List? thumbBytes;
}
