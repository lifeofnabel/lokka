import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/display_device.dart';
import '../models/display_layout.dart';
import '../models/display_routine.dart';
import '../models/display_studio_config.dart';
import '../services/display_studio_service.dart';

class DisplayStudioProvider extends ChangeNotifier {
  DisplayStudioProvider({required this.service}) {
    _init();
  }

  final DisplayStudioService service;

  // ── Core state ────────────────────────────────────────────────────────────
  bool isLoading = true;
  String? error;
  bool isBusy = false;

  DisplayStudioConfig? config;
  List<DisplayLayout> layouts = [];
  List<DisplayDevice> devices = [];
  List<DisplayRoutine> routines = [];

  // ── Layout filter / search state ─────────────────────────────────────────
  String layoutSearchQuery = '';
  String? filterOrientation; // 'landscape' | 'portrait' | null
  String? filterScreenSize;  // 'klein' | 'mittel' | 'groß' | '4K' | null
  String? filterMode;        // 'day' | 'night' | null
  String? filterType;        // DisplayLayoutType.name | null

  List<DisplayLayout> get filteredLayouts {
    var result = layouts;

    if (layoutSearchQuery.isNotEmpty) {
      final q = layoutSearchQuery.toLowerCase();
      result = result
          .where((l) =>
              l.title.toLowerCase().contains(q) ||
              l.type.label.toLowerCase().contains(q) ||
              l.tags.any((t) => t.toLowerCase().contains(q)))
          .toList();
    }
    if (filterOrientation != null) {
      result = result.where((l) => l.orientation.name == filterOrientation).toList();
    }
    if (filterScreenSize != null) {
      result = result.where((l) => l.screenSizeTarget == filterScreenSize).toList();
    }
    if (filterMode != null) {
      result = result.where((l) => l.mode == filterMode).toList();
    }
    if (filterType != null) {
      result = result.where((l) => l.type.name == filterType).toList();
    }

    return result;
  }

  bool get hasActiveFilter =>
      filterOrientation != null ||
      filterScreenSize != null ||
      filterMode != null ||
      filterType != null;

  int get activeFilterCount {
    var count = 0;
    if (filterOrientation != null) count++;
    if (filterScreenSize != null) count++;
    if (filterMode != null) count++;
    if (filterType != null) count++;
    return count;
  }

  void setLayoutSearch(String query) {
    layoutSearchQuery = query;
    notifyListeners();
  }

  void setFilter({
    String? orientation,
    String? screenSize,
    String? mode,
    String? type,
    bool clear = false,
  }) {
    if (clear) {
      filterOrientation = null;
      filterScreenSize = null;
      filterMode = null;
      filterType = null;
    } else {
      filterOrientation = orientation;
      filterScreenSize = screenSize;
      filterMode = mode;
      filterType = type;
    }
    notifyListeners();
  }

  void clearFilters() => setFilter(clear: true);

  // ── Streams ───────────────────────────────────────────────────────────────
  StreamSubscription<DisplayStudioConfig?>? _configSub;
  StreamSubscription<List<DisplayLayout>>? _layoutsSub;
  StreamSubscription<List<DisplayDevice>>? _devicesSub;
  StreamSubscription<List<DisplayRoutine>>? _routinesSub;

  void _init() {
    _configSub = service.configStream().listen(
      (cfg) {
        config = cfg;
        isLoading = false;
        notifyListeners();
      },
      onError: (_) {
        isLoading = false;
        notifyListeners();
      },
    );

    _layoutsSub = service.layoutsStream().listen(
      (list) {
        layouts = list;
        notifyListeners();
      },
      onError: (_) {},
    );

    _devicesSub = service.devicesStream().listen(
      (list) {
        devices = list;
        notifyListeners();
      },
      onError: (_) {},
    );

    _routinesSub = service.routinesStream().listen(
      (list) {
        routines = list;
        notifyListeners();
      },
      onError: (_) {},
    );
  }

  // ── Config ────────────────────────────────────────────────────────────────
  Future<void> ensureConfig() async {
    try {
      await service.initConfig();
    } catch (_) {}
  }

  // ── Device actions ────────────────────────────────────────────────────────
  Future<void> stopDevice(String deviceId) => _run(() => service.stopDevice(deviceId));
  Future<void> unlinkDevice(String deviceId) => _run(() => service.unlinkDevice(deviceId));
  Future<void> renameDevice(String deviceId, String name) =>
      _run(() => service.renameDevice(deviceId, name));

  Future<void> startLayout({
    required String deviceId,
    required String layoutId,
    required String layoutTitle,
  }) =>
      _run(() => service.startLayoutOnDevice(
            deviceId: deviceId,
            layoutId: layoutId,
            layoutTitle: layoutTitle,
          ));

  // ── Layout actions ────────────────────────────────────────────────────────
  Future<String?> createLayout(DisplayLayout layout) async {
    isBusy = true;
    error = null;
    notifyListeners();
    try {
      final id = await service.createLayout(layout);
      return id;
    } catch (e) {
      error = e.toString();
      return null;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> updateLayout(DisplayLayout layout) => _run(() => service.updateLayout(layout));

  Future<void> deleteLayout(String layoutId) => _run(() => service.deleteLayout(layoutId));

  Future<void> duplicateLayout(DisplayLayout layout) =>
      _run(() => service.duplicateLayout(layout));

  Future<void> renameLayout(String layoutId, String newTitle) =>
      _run(() => service.renameLayout(layoutId, newTitle));

  // ── Routine actions ───────────────────────────────────────────────────────
  Future<void> createRoutine(DisplayRoutine routine) =>
      _run(() => service.createRoutine(routine));

  Future<void> updateRoutine(DisplayRoutine routine) =>
      _run(() => service.updateRoutine(routine));

  Future<void> deleteRoutine(String routineId) =>
      _run(() => service.deleteRoutine(routineId));

  Future<void> toggleRoutine(String routineId, bool isActive) =>
      _run(() => service.toggleRoutine(routineId, isActive));

  // ── Helpers ───────────────────────────────────────────────────────────────
  Future<void> _run(Future<void> Function() action) async {
    isBusy = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } catch (e) {
      error = e.toString();
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _configSub?.cancel();
    _layoutsSub?.cancel();
    _devicesSub?.cancel();
    _routinesSub?.cancel();
    super.dispose();
  }
}
