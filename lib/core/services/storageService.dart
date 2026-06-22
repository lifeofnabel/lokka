import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// Wird geworfen, wenn ein Firebase-Storage-Vorgang scheitert.
///
/// Trägt eine bereits nutzerfreundliche, anzeigbare Meldung ([message]) sowie
/// optional die technische Ursache ([cause]) für Logging.
class StorageException implements Exception {
  const StorageException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

/// Ergebnis eines Storage-Uploads – Pfad (für Delete/Replace) + Download-URL.
class StorageUploadResult {
  const StorageUploadResult({
    required this.path,
    required this.downloadUrl,
    required this.bytes,
    required this.contentType,
  });

  /// Vollständiger Objekt-Pfad im Bucket, z. B. `merchants/<uid>/cover/<id>.jpg`.
  final String path;

  /// Öffentlich abrufbare Download-URL (mit Token).
  final String downloadUrl;

  /// Größe der hochgeladenen Bytes.
  final int bytes;

  /// MIME-Typ des Objekts.
  final String contentType;
}

/// Kanonische Pfad-Bausteine. Es gibt keine zufälligen Upload-Pfade –
/// alle Uploads laufen über diese Helfer.
///
/// ```
/// merchants/{uid}/profile|cover|offers|catalog|wallet|displayStudio/{file}
/// users/{uid}/profile|uploads/{file}
/// system/{category}/{file}            // nur Admin/Console
/// ```
class StoragePaths {
  const StoragePaths._();

  static const String merchantsRoot = 'merchants';
  static const String usersRoot = 'users';
  static const String systemRoot = 'system';

  static String merchant(String uid, String category, String fileName) =>
      '$merchantsRoot/$uid/$category/$fileName';

  static String user(String uid, String category, String fileName) =>
      '$usersRoot/$uid/$category/$fileName';

  static String system(String category, String fileName) =>
      '$systemRoot/$category/$fileName';
}

/// Zentrale Firebase-Storage-Schicht.
///
/// Verantwortlich für Upload, Delete, Replace, Download-URLs, Metadaten und
/// Pfadverwaltung. Außerhalb dieser Klasse darf keine direkte Firebase-Storage-
/// Logik existieren (keine `FirebaseStorage.instance`-Aufrufe in UI/anderen
/// Services). Funktioniert identisch auf Mobile und Web (`putData`).
class StorageService {
  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  /// Bricht hängende Uploads nach dieser Zeit ab (langsame/instabile Netze).
  static const Duration _uploadTimeout = Duration(seconds: 60);

  /// Lädt [bytes] nach [path] hoch und liefert Pfad + Download-URL.
  ///
  /// Setzt einen langen, immutable Cache-Header – die Dateinamen sind
  /// eindeutig (UUID), daher ist aggressives Caching gefahrlos und macht die
  /// Auslieferung (vor allem im Web) deutlich schneller.
  Future<StorageUploadResult> uploadBytes({
    required String path,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
    Map<String, String>? customMetadata,
    void Function(double progress)? onProgress,
  }) async {
    final ref = _storage.ref(path);
    final metadata = SettableMetadata(
      contentType: contentType,
      cacheControl: 'public, max-age=31536000, immutable',
      customMetadata: customMetadata,
    );

    final UploadTask task = ref.putData(bytes, metadata);
    StreamSubscription<TaskSnapshot>? progressSub;
    if (onProgress != null) {
      progressSub = task.snapshotEvents.listen((snapshot) {
        final total = snapshot.totalBytes;
        if (total > 0) onProgress(snapshot.bytesTransferred / total);
      });
    }
    try {
      await task.timeout(_uploadTimeout);
      final url = await ref.getDownloadURL();
      return StorageUploadResult(
        path: path,
        downloadUrl: url,
        bytes: bytes.lengthInBytes,
        contentType: contentType,
      );
    } on TimeoutException {
      await task.cancel().catchError((_) => false);
      throw const StorageException(
        'Zeitüberschreitung beim Hochladen. Bitte Verbindung prüfen und erneut versuchen.',
      );
    } on FirebaseException catch (e) {
      throw StorageException(_friendlyMessage(e), cause: e);
    } finally {
      await progressSub?.cancel();
    }
  }

  /// Löscht das Objekt unter [path]. Idempotent: ein bereits fehlendes Objekt
  /// gilt als erfolgreich gelöscht.
  Future<void> delete(String path) async {
    if (path.isEmpty) return;
    try {
      await _storage.ref(path).delete();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return;
      throw StorageException(_friendlyMessage(e), cause: e);
    }
  }

  /// Löscht ein Objekt anhand seiner Download-URL.
  ///
  /// Verarbeitet ausschließlich Firebase-Storage-URLs. Fremde URLs (z. B. noch
  /// vorhandene alte Cloudinary-Links) werden bewusst ignoriert, damit
  /// Replace-Flows daran nicht scheitern.
  Future<void> deleteByDownloadUrl(String url) async {
    if (url.isEmpty || !isFirebaseStorageUrl(url)) return;
    try {
      await _storage.refFromURL(url).delete();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return;
      throw StorageException(_friendlyMessage(e), cause: e);
    } catch (_) {
      // refFromURL kann bei unerwartetem URL-Format werfen – still ignorieren.
    }
  }

  /// Lädt [bytes] nach [path] hoch und entfernt anschließend ein altes Objekt
  /// (per [previousUrl]). Das Aufräumen ist „best effort" und lässt den
  /// Replace nicht scheitern.
  Future<StorageUploadResult> replace({
    required String path,
    required Uint8List bytes,
    String? previousUrl,
    String contentType = 'image/jpeg',
    Map<String, String>? customMetadata,
  }) async {
    final result = await uploadBytes(
      path: path,
      bytes: bytes,
      contentType: contentType,
      customMetadata: customMetadata,
    );
    if (previousUrl != null &&
        previousUrl.isNotEmpty &&
        previousUrl != result.downloadUrl) {
      try {
        await deleteByDownloadUrl(previousUrl);
      } catch (_) {
        // Verwaiste Datei ist unkritisch – Replace bleibt erfolgreich.
      }
    }
    return result;
  }

  /// Erzeugt eine frische Download-URL für [path].
  Future<String> getDownloadUrl(String path) async {
    try {
      return await _storage.ref(path).getDownloadURL();
    } on FirebaseException catch (e) {
      throw StorageException(_friendlyMessage(e), cause: e);
    }
  }

  /// Liest die Metadaten eines Objekts.
  Future<FullMetadata> getMetadata(String path) async {
    try {
      return await _storage.ref(path).getMetadata();
    } on FirebaseException catch (e) {
      throw StorageException(_friendlyMessage(e), cause: e);
    }
  }

  /// Ob [url] auf Firebase Storage zeigt (und nicht z. B. auf Cloudinary).
  static bool isFirebaseStorageUrl(String url) {
    return url.contains('firebasestorage.googleapis.com') ||
        url.contains('firebasestorage.app') ||
        url.contains('storage.googleapis.com');
  }

  String _friendlyMessage(FirebaseException e) {
    return switch (e.code) {
      'unauthorized' => 'Keine Berechtigung für diesen Upload.',
      'canceled' => 'Upload abgebrochen.',
      'retry-limit-exceeded' =>
        'Upload fehlgeschlagen – instabile Verbindung. Bitte erneut versuchen.',
      'quota-exceeded' =>
        'Speicherkontingent erreicht. Bitte später erneut versuchen.',
      'object-not-found' => 'Die Datei wurde nicht gefunden.',
      'unauthenticated' => 'Bitte zuerst anmelden, um Bilder hochzuladen.',
      _ => 'Upload fehlgeschlagen (${e.code}). Bitte erneut versuchen.',
    };
  }
}
