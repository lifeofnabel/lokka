import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/display_block.dart';
import '../models/display_layout.dart';
import '../services/display_studio_service.dart';

class LayoutEditorProvider extends ChangeNotifier {
  LayoutEditorProvider({
    required this.service,
    required DisplayLayout initial,
  }) {
    _layout = initial;
    _blocks = _blocksFromMaps(initial.blocks);
  }

  final DisplayStudioService service;

  late DisplayLayout _layout;
  late List<DisplayBlock> _blocks;

  bool isSaving = false;
  bool isDirty = false;
  String? error;

  // ── Getters ───────────────────────────────────────────────────────────────
  DisplayLayout get layout => _layout;
  List<DisplayBlock> get blocks => List.unmodifiable(_blocks);
  String get title => _layout.title;
  DisplayOrientation get orientation => _layout.orientation;
  String get screenSizeTarget => _layout.screenSizeTarget;
  String get mode => _layout.mode;
  String get animation => _layout.animation;
  String get backgroundStyle => _layout.backgroundStyle;

  // ── Meta edits ────────────────────────────────────────────────────────────
  void setTitle(String v) {
    _layout = _layout.copyWith(title: v);
    _markDirty();
  }

  void setOrientation(DisplayOrientation v) {
    _layout = _layout.copyWith(orientation: v);
    _markDirty();
  }

  void setScreenSize(String v) {
    _layout = _layout.copyWith(screenSizeTarget: v);
    _markDirty();
  }

  void setMode(String v) {
    _layout = _layout.copyWith(mode: v);
    _markDirty();
  }

  void setAnimation(String v) {
    _layout = _layout.copyWith(animation: v);
    _markDirty();
  }

  void setBackgroundStyle(String v) {
    _layout = _layout.copyWith(backgroundStyle: v);
    _markDirty();
  }

  // ── Block operations ──────────────────────────────────────────────────────
  void addBlock(DisplayBlockType type) {
    final block = DisplayBlock.create(type, order: _blocks.length);
    _blocks = [..._blocks, block];
    _markDirty();
  }

  void updateBlock(String blockId, Map<String, dynamic> newValue) {
    _blocks = _blocks.map((b) {
      if (b.id != blockId) return b;
      return b.copyWith(value: Map<String, dynamic>.from(newValue));
    }).toList();
    _markDirty();
  }

  void updateBlockFull(DisplayBlock updated) {
    _blocks = _blocks.map((b) => b.id == updated.id ? updated : b).toList();
    _markDirty();
  }

  void toggleBlockVisibility(String blockId) {
    _blocks = _blocks.map((b) {
      if (b.id != blockId) return b;
      return b.copyWith(isVisible: !b.isVisible);
    }).toList();
    _markDirty();
  }

  void deleteBlock(String blockId) {
    _blocks = _blocks.where((b) => b.id != blockId).toList();
    _reindex();
    _markDirty();
  }

  void reorderBlocks(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final item = _blocks.removeAt(oldIndex);
    _blocks.insert(newIndex, item);
    _reindex();
    _markDirty();
  }

  void duplicateBlock(String blockId) {
    final idx = _blocks.indexWhere((b) => b.id == blockId);
    if (idx == -1) return;
    final original = _blocks[idx];
    final copy = DisplayBlock(
      id: _shortId(),
      type: original.type,
      value: Map<String, dynamic>.from(original.value),
      sourceType: original.sourceType,
      sourceId: original.sourceId,
      style: Map<String, dynamic>.from(original.style),
      order: idx + 1,
      isVisible: original.isVisible,
    );
    _blocks.insert(idx + 1, copy);
    _reindex();
    _markDirty();
  }

  // ── Save ─────────────────────────────────────────────────────────────────
  Future<bool> save({bool asDraft = true}) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      final tags = _layout.autoTags;
      final blockMaps = _blocks.map((b) => b.toMap()).toList();
      final toSave = _layout.copyWith(
        blocks: blockMaps,
        tags: tags,
        isDraft: asDraft,
      );
      await service.updateLayout(toSave);
      _layout = toSave;
      isDirty = false;
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _markDirty() {
    isDirty = true;
    notifyListeners();
  }

  void _reindex() {
    for (var i = 0; i < _blocks.length; i++) {
      if (_blocks[i].order != i) {
        _blocks[i] = _blocks[i].copyWith(order: i);
      }
    }
  }

  static String _shortId() {
    final rng = Random();
    final ts = DateTime.now().millisecondsSinceEpoch;
    return '${ts.toRadixString(16)}${rng.nextInt(0xFFFF).toRadixString(16)}';
  }

  static List<DisplayBlock> _blocksFromMaps(List<Map<String, dynamic>> maps) {
    final blocks = maps.map(DisplayBlock.fromMap).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return blocks;
  }
}
