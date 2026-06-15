import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firebasePaths.dart';
import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../models/display_device.dart';
import '../models/display_layout.dart';
import '../models/display_routine.dart';
import '../models/display_studio_config.dart';

class DisplayStudioService {
  const DisplayStudioService({
    required this.firestoreService,
    required this.authService,
  });

  final FirestoreService firestoreService;
  final AuthService authService;

  String? get _merchantId => authService.currentUser?.uid;

  // ── Config ───────────────────────────────────────────────────────────────

  Stream<DisplayStudioConfig?> configStream() {
    final id = _merchantId;
    if (id == null) return const Stream.empty();

    return firestoreService
        .document(FirebasePaths.merchantDisplayStudioMain(id))
        .snapshots()
        .map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return DisplayStudioConfig.fromMap(snap.data()!);
    });
  }

  Future<DisplayStudioConfig?> loadConfig() async {
    final id = _merchantId;
    if (id == null) return null;

    final data = await firestoreService.readDocument(
      FirebasePaths.merchantDisplayStudioMain(id),
    );

    if (data == null) return null;
    return DisplayStudioConfig.fromMap(data);
  }

  Future<void> initConfig() async {
    final id = _merchantId;
    if (id == null) return;

    final path = FirebasePaths.merchantDisplayStudioMain(id);
    final existing = await firestoreService.readDocument(path);

    if (existing == null) {
      await firestoreService.setDocument(
        path,
        DisplayStudioConfig.empty().toInitMap(),
        merge: false,
      );
    }
  }

  // ── Layouts ───────────────────────────────────────────────────────────────

  Stream<List<DisplayLayout>> layoutsStream() {
    final id = _merchantId;
    if (id == null) return const Stream.empty();

    return firestoreService
        .collection(FirebasePaths.merchantDisplayLayouts(id))
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(DisplayLayout.fromFirestore).toList());
  }

  Future<DisplayLayout?> getLayoutById(String layoutId) async {
    final id = _merchantId;
    if (id == null) return null;

    final snap = await firestoreService
        .document(FirebasePaths.merchantDisplayLayout(id, layoutId))
        .get();

    if (!snap.exists) return null;
    return DisplayLayout.fromFirestore(snap);
  }

  Future<String> createLayout(DisplayLayout layout) async {
    final id = _merchantId;
    if (id == null) throw Exception('Kein Benutzer');

    final ref = firestoreService
        .collection(FirebasePaths.merchantDisplayLayouts(id))
        .doc();

    final withId = layout.copyWith(id: ref.id);

    await ref.set(withId.toMap());

    await _writeLog(
      type: 'create',
      deviceId: '',
      layoutId: ref.id,
      message: 'Layout "${layout.title}" erstellt',
    );

    return ref.id;
  }

  Future<void> updateLayout(DisplayLayout layout) async {
    final id = _merchantId;
    if (id == null) return;

    await firestoreService.setDocument(
      FirebasePaths.merchantDisplayLayout(id, layout.id),
      layout.toMap(),
    );
  }

  Future<void> saveLayoutBlocks({
    required String layoutId,
    required List<Map<String, dynamic>> blocks,
    required bool isDraft,
    required List<String> tags,
  }) async {
    final id = _merchantId;
    if (id == null) return;

    await firestoreService.updateDocument(
      FirebasePaths.merchantDisplayLayout(id, layoutId),
      {
        'blocks': blocks,
        'isDraft': isDraft,
        'tags': tags,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> updateLayoutMeta({
    required String layoutId,
    String? title,
    String? orientation,
    String? screenSizeTarget,
    String? mode,
    String? animation,
    String? backgroundStyle,
  }) async {
    final id = _merchantId;
    if (id == null) return;

    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (title != null) data['title'] = title;
    if (orientation != null) data['orientation'] = orientation;
    if (screenSizeTarget != null) data['screenSizeTarget'] = screenSizeTarget;
    if (mode != null) data['mode'] = mode;
    if (animation != null) data['animation'] = animation;
    if (backgroundStyle != null) data['backgroundStyle'] = backgroundStyle;

    await firestoreService.updateDocument(
      FirebasePaths.merchantDisplayLayout(id, layoutId),
      data,
    );
  }

  Future<void> deleteLayout(String layoutId) async {
    final id = _merchantId;
    if (id == null) return;

    await firestoreService
        .document(FirebasePaths.merchantDisplayLayout(id, layoutId))
        .delete();

    await _writeLog(
      type: 'delete',
      deviceId: '',
      layoutId: layoutId,
      message: 'Layout gelöscht',
    );
  }

  Future<String> duplicateLayout(DisplayLayout layout) async {
    final id = _merchantId;
    if (id == null) throw Exception('Kein Benutzer');

    final copy = layout.copyWith(
      title: 'Kopie von ${layout.title}',
      isDraft: true,
    );

    return createLayout(copy);
  }

  Future<void> renameLayout(String layoutId, String newTitle) async {
    final id = _merchantId;
    if (id == null) return;

    await firestoreService.updateDocument(
      FirebasePaths.merchantDisplayLayout(id, layoutId),
      {
        'title': newTitle,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  // ── Devices ───────────────────────────────────────────────────────────────

  Stream<List<DisplayDevice>> devicesStream() {
    final id = _merchantId;
    if (id == null) return const Stream.empty();

    return firestoreService
        .collection(FirebasePaths.merchantDisplayDevices(id))
        .snapshots()
        .map((snap) => snap.docs.map(DisplayDevice.fromFirestore).toList());
  }

  Future<void> renameDevice(String deviceId, String newName) async {
    final id = _merchantId;
    if (id == null) return;

    await firestoreService.updateDocument(
      FirebasePaths.merchantDisplayDevice(id, deviceId),
      {
        'name': newName,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> stopDevice(String deviceId) async {
    final id = _merchantId;
    if (id == null) return;

    await firestoreService.updateDocument(
      FirebasePaths.merchantDisplayDevice(id, deviceId),
      {
        'command': DisplayDeviceCommand.stopPlayback.name,
        'status': DisplayDeviceStatus.stopped.name,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    await _writeLog(
      type: 'stop',
      deviceId: deviceId,
      layoutId: '',
      message: 'Wiedergabe gestoppt',
    );
  }

  Future<void> unlinkDevice(String deviceId) async {
    final id = _merchantId;
    if (id == null) return;

    await firestoreService.updateDocument(
      FirebasePaths.merchantDisplayDevice(id, deviceId),
      {
        'command': DisplayDeviceCommand.unlink.name,
        'isLinked': false,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    await _writeLog(
      type: 'command',
      deviceId: deviceId,
      layoutId: '',
      message: 'Display entkoppelt',
    );
  }

  Future<void> startLayoutOnDevice({
    required String deviceId,
    required String layoutId,
    required String layoutTitle,
  }) async {
    final id = _merchantId;
    if (id == null) return;

    await firestoreService.updateDocument(
      FirebasePaths.merchantDisplayDevice(id, deviceId),
      {
        'command': DisplayDeviceCommand.startLayout.name,
        'activeLayoutId': layoutId,
        'activeLayoutTitle': layoutTitle,
        'status': DisplayDeviceStatus.playing.name,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    await firestoreService.updateDocument(
      FirebasePaths.merchantDisplayLayout(id, layoutId),
      {
        'lastUsedAt': FieldValue.serverTimestamp(),
      },
    );

    await _writeLog(
      type: 'start',
      deviceId: deviceId,
      layoutId: layoutId,
      message: 'Layout "$layoutTitle" gestartet',
    );
  }

  // ── Routines ──────────────────────────────────────────────────────────────

  Stream<List<DisplayRoutine>> routinesStream() {
    final id = _merchantId;
    if (id == null) return const Stream.empty();

    return firestoreService
        .collection(FirebasePaths.merchantDisplayRoutines(id))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(DisplayRoutine.fromFirestore).toList());
  }

  Future<String> createRoutine(DisplayRoutine routine) async {
    final id = _merchantId;
    if (id == null) throw Exception('Kein Benutzer');

    final ref = firestoreService
        .collection(FirebasePaths.merchantDisplayRoutines(id))
        .doc();

    final withId = DisplayRoutine(
      id: ref.id,
      title: routine.title,
      deviceIds: routine.deviceIds,
      layoutIds: routine.layoutIds,
      days: routine.days,
      startTime: routine.startTime,
      endTime: routine.endTime,
      isActive: routine.isActive,
      animation: routine.animation,
      createdAt: null,
      updatedAt: null,
    );

    await ref.set(withId.toMap());

    await _writeLog(
      type: 'routineCreated',
      deviceId: '',
      layoutId: '',
      message: 'Routine "${routine.title}" erstellt',
    );

    return ref.id;
  }

  Future<void> updateRoutine(DisplayRoutine routine) async {
    final id = _merchantId;
    if (id == null) return;

    await firestoreService.setDocument(
      FirebasePaths.merchantDisplayRoutine(id, routine.id),
      routine.toMap(),
    );

    await _writeLog(
      type: 'routineUpdated',
      deviceId: '',
      layoutId: '',
      message: 'Routine "${routine.title}" aktualisiert',
    );
  }

  Future<void> deleteRoutine(String routineId) async {
    final id = _merchantId;
    if (id == null) return;

    await firestoreService
        .document(FirebasePaths.merchantDisplayRoutine(id, routineId))
        .delete();

    await _writeLog(
      type: 'routineDeleted',
      deviceId: '',
      layoutId: '',
      message: 'Routine gelöscht',
    );
  }

  Future<void> toggleRoutine(String routineId, bool isActive) async {
    final id = _merchantId;
    if (id == null) return;

    await firestoreService.updateDocument(
      FirebasePaths.merchantDisplayRoutine(id, routineId),
      {
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  // ── Pairing ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getPairingSession(String pairingId) async {
    if (pairingId.trim().isEmpty) return null;

    return firestoreService.readDocument(
      FirebasePaths.displayPairingSession(pairingId),
    );
  }

  Future<String> claimPairingAndCreateDevice({
    required String pairingId,
    required String token,
    required String deviceName,
    required String deviceType,
    required String orientation,
    required double screenSizeInch,
    required String resolution,
  }) async {
    final merchantId = _merchantId;

    if (merchantId == null) {
      throw Exception('Kein Benutzer');
    }

    final cleanPairingId = pairingId.trim();
    final cleanToken = token.trim();
    final cleanName = deviceName.trim();

    if (cleanPairingId.isEmpty) {
      throw Exception('Pairing-ID fehlt.');
    }

    if (cleanToken.isEmpty) {
      throw Exception('Sicherheits-Token fehlt.');
    }

    if (cleanName.isEmpty) {
      throw Exception('Display-Name fehlt.');
    }

    final sessionRef = firestoreService.document(
      FirebasePaths.displayPairingSession(cleanPairingId),
    );

    final deviceRef = firestoreService
        .collection(FirebasePaths.merchantDisplayDevices(merchantId))
        .doc();

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final sessionSnap = await transaction.get(sessionRef);

      if (!sessionSnap.exists || sessionSnap.data() == null) {
        throw Exception('Pairing-Session nicht gefunden.');
      }

      final session = Map<String, dynamic>.from(sessionSnap.data()!);

      final sessionType = session['type']?.toString() ?? '';
      if (sessionType.isNotEmpty && sessionType != 'lokkaDisplayPairing') {
        throw Exception('Ungültiger Pairing-Typ.');
      }

      final sessionToken = session['token']?.toString() ?? '';
      if (sessionToken.isEmpty || sessionToken != cleanToken) {
        throw Exception('Sicherheits-Token stimmt nicht überein.');
      }

      final status = session['status']?.toString() ?? '';
      final claimed = session['claimed'] as bool? ?? false;

      if (claimed || status == 'claimed') {
        throw Exception('Dieser Code wurde bereits verwendet.');
      }

      final expiresAt = _parseDateTime(session['expiresAt']);
      if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
        throw Exception(
          'Code ist abgelaufen. Bitte am Fernseher einen neuen QR anzeigen.',
        );
      }

      final deviceData = <String, dynamic>{
        'id': deviceRef.id,
        'name': cleanName,
        'deviceType': deviceType,
        'orientation': orientation,
        'screenSizeInch': screenSizeInch,
        'resolution': resolution,

        // Pairing
        'pairingId': cleanPairingId,
        'merchantId': merchantId,
        'pairedAt': FieldValue.serverTimestamp(),
        'isLinked': true,

        // Playback
        'activeLayoutId': '',
        'activeLayoutTitle': '',
        'status': 'offline',
        'command': null,

        // Presence
        'lastSeenAt': null,

        // Meta
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      transaction.set(deviceRef, deviceData);

      transaction.update(sessionRef, {
        'status': 'claimed',
        'claimed': true,
        'claimedAt': FieldValue.serverTimestamp(),

        // neue saubere Felder
        'claimedByMerchantId': merchantId,
        'claimedDeviceId': deviceRef.id,

        // fallback / alte Kompatibilität
        'claimedByMerchant': merchantId,

        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    await _writeLog(
      type: 'devicePaired',
      deviceId: deviceRef.id,
      layoutId: '',
      message: 'Display "$cleanName" gekoppelt',
    );

    return deviceRef.id;
  }

  // ── Logs ──────────────────────────────────────────────────────────────────

  Future<void> writeLog({
    required String type,
    required String deviceId,
    required String layoutId,
    required String message,
  }) {
    return _writeLog(
      type: type,
      deviceId: deviceId,
      layoutId: layoutId,
      message: message,
    );
  }

  Future<void> _writeLog({
    required String type,
    required String deviceId,
    required String layoutId,
    required String message,
  }) async {
    final id = _merchantId;
    if (id == null) return;

    final ref = firestoreService
        .collection(FirebasePaths.merchantDisplayLogs(id))
        .doc();

    await ref.set({
      'id': ref.id,
      'type': type,
      'deviceId': deviceId,
      'layoutId': layoutId,
      'message': message,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;

  if (value is DateTime) {
    return value;
  }

  if (value is Timestamp) {
    return value.toDate();
  }

  if (value is String) {
    return DateTime.tryParse(value);
  }

  try {
    final dynamic dynamicValue = value;
    final converted = dynamicValue.toDate();

    if (converted is DateTime) {
      return converted;
    }
  } catch (_) {
    return null;
  }

  return null;
}