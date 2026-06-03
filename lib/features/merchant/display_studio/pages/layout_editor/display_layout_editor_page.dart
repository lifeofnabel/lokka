import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/appColors.dart';
import '../../../../../core/theme/appRadius.dart';
import '../../models/display_block.dart';
import '../../models/display_layout.dart';
import '../../providers/layout_editor_provider.dart';
import '../../widgets/block_edit_sheet.dart';
import '../../widgets/layout_preview_widget.dart';
import 'display_layout_preview_page.dart';

class DisplayLayoutEditorPage extends StatelessWidget {
  const DisplayLayoutEditorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _EditorScaffold();
  }
}

class _EditorScaffold extends StatefulWidget {
  const _EditorScaffold();
  @override
  State<_EditorScaffold> createState() => _EditorScaffoldState();
}

class _EditorScaffoldState extends State<_EditorScaffold> {
  bool _showSettings = false;

  @override
  Widget build(BuildContext context) {
    final editor = context.watch<LayoutEditorProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context, editor),
      body: Column(
        children: [
          // ── Canvas Preview ─────────────────────────────────────────────
          _PreviewCanvas(
            editor: editor,
            showSettings: _showSettings,
            onToggleSettings: () => setState(() => _showSettings = !_showSettings),
          ),

          // ── Settings chips (collapsible) ───────────────────────────────
          if (_showSettings) _SettingsRow(editor: editor),

          // ── Block list ─────────────────────────────────────────────────
          Expanded(
            child: _BlockList(editor: editor),
          ),

          // ── Element bar ─────────────────────────────────────────────────
          _ElementBar(onAdd: (type) => editor.addBlock(type)),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, LayoutEditorProvider editor) {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () async {
          if (editor.isDirty) {
            final save = await _showUnsavedDialog(context);
            if (save == true && context.mounted) {
              await editor.save(asDraft: true);
            }
          }
          if (context.mounted) Navigator.of(context).pop();
        },
      ),
      title: _TitleField(
        initial: editor.title,
        onChanged: editor.setTitle,
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.tune_rounded,
            color: _showSettings ? AppColors.black : AppColors.gray500,
          ),
          tooltip: 'Einstellungen',
          onPressed: () => setState(() => _showSettings = !_showSettings),
        ),
        IconButton(
          icon: const Icon(Icons.preview_rounded, color: AppColors.gray500),
          tooltip: 'Vorschau',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ChangeNotifierProvider.value(
                value: editor,
                child: const DisplayLayoutPreviewPage(),
              ),
            ),
          ),
        ),
        if (editor.isSaving)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              child: SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else ...[
          TextButton(
            onPressed: () => _save(context, editor, asDraft: true),
            child: const Text('Entwurf',
                style: TextStyle(color: AppColors.gray500, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => _save(context, editor, asDraft: false),
            child: const Text('Speichern',
                style: TextStyle(color: AppColors.black, fontWeight: FontWeight.w900)),
          ),
        ],
      ],
    );
  }

  Future<void> _save(BuildContext context, LayoutEditorProvider editor, {required bool asDraft}) async {
    final ok = await editor.save(asDraft: asDraft);
    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(asDraft ? 'Als Entwurf gespeichert' : 'Layout gespeichert ✓'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(editor.error ?? 'Fehler beim Speichern')),
      );
    }
  }

  Future<bool?> _showUnsavedDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ungespeicherte Änderungen',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('Möchtest du die Änderungen als Entwurf speichern?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Verwerfen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.black,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }
}

// ── Preview Canvas ─────────────────────────────────────────────────────────

class _PreviewCanvas extends StatelessWidget {
  const _PreviewCanvas({
    required this.editor,
    required this.showSettings,
    required this.onToggleSettings,
  });

  final LayoutEditorProvider editor;
  final bool showSettings;
  final VoidCallback onToggleSettings;

  @override
  Widget build(BuildContext context) {
    final isPortrait = editor.orientation == DisplayOrientation.portrait;
    final h = MediaQuery.of(context).size.height;

    return Container(
      color: const Color(0xFF0D0F0E),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          // Preview
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: h * (isPortrait ? 0.32 : 0.22),
                ),
                child: LayoutPreviewWidget(
                  layout: editor.layout,
                  blocks: editor.blocks,
                ),
              ),
            ),
          ),
          // Quick meta
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PreviewChip(
                icon: Icons.screen_rotation_rounded,
                label: editor.orientation == DisplayOrientation.landscape
                    ? 'Quer' : 'Hoch',
                onTap: () => editor.setOrientation(
                  editor.orientation == DisplayOrientation.landscape
                      ? DisplayOrientation.portrait
                      : DisplayOrientation.landscape,
                ),
              ),
              const SizedBox(height: 6),
              _PreviewChip(
                icon: Icons.animation_rounded,
                label: _animShort(editor.animation),
                onTap: onToggleSettings,
              ),
              const SizedBox(height: 6),
              _PreviewChip(
                icon: Icons.wb_sunny_rounded,
                label: editor.mode == 'night' ? 'Nacht' : 'Tag',
                onTap: () => editor.setMode(
                    editor.mode == 'day' ? 'night' : 'day'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _animShort(String a) {
    switch (a) {
      case 'slide': return 'Slide';
      case 'softZoom': return 'Zoom';
      case 'cardSwitch': return 'Card';
      default: return 'Fade';
    }
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withAlpha(20)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Colors.white70),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

// ── Settings Row ─────────────────────────────────────────────────────────────

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.editor});
  final LayoutEditorProvider editor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: AppColors.surface,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          _DropChip(
            label: 'Größe',
            value: editor.screenSizeTarget.isEmpty ? 'mittel' : editor.screenSizeTarget,
            options: const {'klein': 'Klein', 'mittel': 'Mittel', 'groß': 'Groß', '4K': '4K'},
            onSelect: editor.setScreenSize,
          ),
          const SizedBox(width: 6),
          _DropChip(
            label: 'Animation',
            value: editor.animation,
            options: const {
              'fade': 'Fade', 'slide': 'Slide',
              'softZoom': 'Soft Zoom', 'cardSwitch': 'Card Switch',
            },
            onSelect: editor.setAnimation,
          ),
          const SizedBox(width: 6),
          _DropChip(
            label: 'Hintergrund',
            value: editor.backgroundStyle,
            options: const {'dark': 'Dunkel', 'light': 'Hell', 'image': 'Bild'},
            onSelect: editor.setBackgroundStyle,
          ),
        ],
      ),
    );
  }
}

class _DropChip extends StatelessWidget {
  const _DropChip({required this.label, required this.value,
      required this.options, required this.onSelect});
  final String label;
  final String value;
  final Map<String, String> options;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelect,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (_) => options.entries
          .map((e) => PopupMenuItem(
                value: e.key,
                child: Text(e.value,
                    style: TextStyle(
                        fontWeight: e.key == value
                            ? FontWeight.w900 : FontWeight.normal)),
              ))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.gray50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$label: ${options[value] ?? value}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          const Icon(Icons.expand_more_rounded, size: 14),
        ]),
      ),
    );
  }
}

// ── Block List ────────────────────────────────────────────────────────────────

class _BlockList extends StatelessWidget {
  const _BlockList({required this.editor});
  final LayoutEditorProvider editor;

  @override
  Widget build(BuildContext context) {
    final blocks = editor.blocks;

    if (blocks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.layers_rounded, size: 36, color: AppColors.gray300),
            const SizedBox(height: 10),
            const Text('Noch keine Blöcke.',
                style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.gray500)),
            const SizedBox(height: 4),
            const Text('Element unten antippen → Block hinzufügen',
                style: TextStyle(color: AppColors.gray300, fontSize: 12)),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      itemCount: blocks.length,
      onReorder: editor.reorderBlocks,
      proxyDecorator: (child, index, animation) => Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: child,
      ),
      itemBuilder: (context, index) {
        final block = blocks[index];
        return _BlockTile(
          key: ValueKey(block.id),
          block: block,
          onTap: () => _editBlock(context, block),
          onToggle: () => editor.toggleBlockVisibility(block.id),
          onDelete: () => editor.deleteBlock(block.id),
          onDuplicate: () => editor.duplicateBlock(block.id),
        );
      },
    );
  }

  void _editBlock(BuildContext context, DisplayBlock block) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (_) => BlockEditSheet(
        block: block,
        onSave: (v) => editor.updateBlock(block.id, v),
        onDelete: () => editor.deleteBlock(block.id),
      ),
    );
  }
}

class _BlockTile extends StatelessWidget {
  const _BlockTile({
    super.key,
    required this.block,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
    required this.onDuplicate,
  });

  final DisplayBlock block;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      decoration: BoxDecoration(
        color: block.isVisible ? AppColors.surface : AppColors.gray50,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.fromLTRB(10, 2, 6, 2),
        leading: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: block.isVisible ? AppColors.black : AppColors.gray100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_iconFor(block.type), size: 17,
              color: block.isVisible ? AppColors.white : AppColors.gray500),
        ),
        title: Text(block.type.label,
            style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 13,
                color: block.isVisible ? AppColors.black : AppColors.gray500)),
        subtitle: Text(block.previewText,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppColors.gray500)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                block.isVisible
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                size: 17, color: AppColors.gray500,
              ),
              onPressed: onToggle,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 17, color: AppColors.gray500),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              onSelected: (v) {
                if (v == 'edit') onTap();
                if (v == 'dup') onDuplicate();
                if (v == 'del') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit',
                    child: Row(children: [Icon(Icons.edit_rounded, size: 17), SizedBox(width: 8), Text('Bearbeiten')])),
                const PopupMenuItem(value: 'dup',
                    child: Row(children: [Icon(Icons.copy_rounded, size: 17), SizedBox(width: 8), Text('Duplizieren')])),
                const PopupMenuItem(value: 'del',
                    child: Row(children: [
                      Icon(Icons.delete_outline_rounded, size: 17, color: Color(0xFFEF4444)),
                      SizedBox(width: 8),
                      Text('Löschen', style: TextStyle(color: Color(0xFFEF4444))),
                    ])),
              ],
            ),
            const Icon(Icons.drag_handle_rounded, color: AppColors.gray300, size: 20),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  IconData _iconFor(DisplayBlockType t) {
    switch (t) {
      case DisplayBlockType.text: return Icons.text_fields_rounded;
      case DisplayBlockType.price: return Icons.euro_rounded;
      case DisplayBlockType.image: return Icons.image_rounded;
      case DisplayBlockType.qr: return Icons.qr_code_rounded;
      case DisplayBlockType.badge: return Icons.label_rounded;
      case DisplayBlockType.menuList: return Icons.menu_book_rounded;
      case DisplayBlockType.gallery: return Icons.photo_library_rounded;
      case DisplayBlockType.loyalty: return Icons.stars_rounded;
      case DisplayBlockType.review: return Icons.format_quote_rounded;
      case DisplayBlockType.divider: return Icons.horizontal_rule_rounded;
      case DisplayBlockType.spacer: return Icons.space_bar_rounded;
    }
  }
}

// ── Element Bar ───────────────────────────────────────────────────────────────

class _ElementBar extends StatelessWidget {
  const _ElementBar({required this.onAdd});
  final void Function(DisplayBlockType) onAdd;

  static const _items = [
    (DisplayBlockType.text, Icons.text_fields_rounded, 'Text'),
    (DisplayBlockType.price, Icons.euro_rounded, 'Preis'),
    (DisplayBlockType.image, Icons.image_rounded, 'Bild'),
    (DisplayBlockType.qr, Icons.qr_code_rounded, 'QR'),
    (DisplayBlockType.badge, Icons.label_rounded, 'Badge'),
    (DisplayBlockType.menuList, Icons.menu_book_rounded, 'Menü'),
    (DisplayBlockType.gallery, Icons.photo_library_rounded, 'Galerie'),
    (DisplayBlockType.loyalty, Icons.stars_rounded, 'Loyalty'),
    (DisplayBlockType.review, Icons.format_quote_rounded, 'Review'),
    (DisplayBlockType.divider, Icons.horizontal_rule_rounded, 'Linie'),
    (DisplayBlockType.spacer, Icons.space_bar_rounded, 'Abstand'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final (type, icon, label) = _items[i];
          return GestureDetector(
            onTap: () => onAdd(type),
            child: Container(
              width: 52,
              decoration: BoxDecoration(
                color: AppColors.gray50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: AppColors.black),
                  const SizedBox(height: 3),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w800,
                          color: AppColors.gray700)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Title Field ───────────────────────────────────────────────────────────────

class _TitleField extends StatefulWidget {
  const _TitleField({required this.initial, required this.onChanged});
  final String initial;
  final void Function(String) onChanged;
  @override State<_TitleField> createState() => _TitleFieldState();
}

class _TitleFieldState extends State<_TitleField> {
  late final TextEditingController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
    _ctrl.addListener(() => widget.onChanged(_ctrl.text));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
      decoration: const InputDecoration(
        border: InputBorder.none,
        hintText: 'Layout-Titel',
        hintStyle: TextStyle(color: AppColors.gray300, fontWeight: FontWeight.w700),
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}
