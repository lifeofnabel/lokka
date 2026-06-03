import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/appColors.dart';
import '../../../../../core/theme/appRadius.dart';
import '../../../../../core/theme/appSpacing.dart';
import '../models/display_block.dart';
import '../models/display_layout.dart';
import '../providers/display_studio_provider.dart';
import '../providers/layout_editor_provider.dart';
import '../pages/layout_editor/display_layout_editor_page.dart';
import '../widgets/layout_preview_widget.dart';

class DisplayLayoutCard extends StatelessWidget {
  const DisplayLayoutCard({
    super.key,
    required this.layout,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    required this.onRename,
  });

  final DisplayLayout layout;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final blocks = layout.blocks.map(DisplayBlock.fromMap).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview
          GestureDetector(
            onTap: onEdit,
            child: SizedBox(
              height: 120,
              child: LayoutPreviewWidget(
                layout: layout,
                blocks: blocks,
              ),
            ),
          ),
          // Info
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        layout.title.isEmpty ? 'Ohne Titel' : layout.title,
                        style:
                            const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _CardMenu(
                      layout: layout,
                      onEdit: onEdit,
                      onDuplicate: onDuplicate,
                      onDelete: onDelete,
                      onRename: onRename,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 3,
                  children: [
                    _Tag(layout.type.label),
                    _Tag(layout.orientation.label),
                    if (layout.isDraft)
                      _Tag('Entwurf', subtle: true),
                  ],
                ),
                if (layout.updatedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _dateLabel(layout.updatedAt!),
                    style: const TextStyle(fontSize: 10, color: AppColors.gray500),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _dateLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Heute';
    if (diff.inDays == 1) return 'Gestern';
    return 'vor ${diff.inDays} T.';
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, {this.subtle = false});
  final String label;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: subtle ? AppColors.gray50 : AppColors.black.withAlpha(12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: subtle ? AppColors.gray500 : AppColors.gray700,
        ),
      ),
    );
  }
}

class _CardMenu extends StatelessWidget {
  const _CardMenu({
    required this.layout,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    required this.onRename,
  });

  final DisplayLayout layout;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, size: 17, color: AppColors.gray500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (v) {
        if (v == 'edit') onEdit();
        if (v == 'duplicate') onDuplicate();
        if (v == 'rename') onRename();
        if (v == 'delete') _confirmDelete(context);
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 17), SizedBox(width: 10), Text('Bearbeiten')])),
        PopupMenuItem(value: 'rename', child: Row(children: [Icon(Icons.drive_file_rename_outline_rounded, size: 17), SizedBox(width: 10), Text('Umbenennen')])),
        PopupMenuItem(value: 'duplicate', child: Row(children: [Icon(Icons.copy_rounded, size: 17), SizedBox(width: 10), Text('Duplizieren')])),
        PopupMenuDivider(),
        PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 17, color: Color(0xFFEF4444)), SizedBox(width: 10), Text('Löschen', style: TextStyle(color: Color(0xFFEF4444)))])),
      ],
    );
  }

  void _confirmDelete(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                  color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(22)),
              child: const Icon(Icons.delete_outline_rounded, color: AppColors.white),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text('Layout löschen?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: AppSpacing.sm),
            const Text(
                'Dieses Layout löschen? Es kann danach nicht wiederhergestellt werden.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.gray700, height: 1.4)),
            const SizedBox(height: AppSpacing.lg),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Abbrechen'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    onDelete();
                  },
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                  child: const Text('Löschen'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Opens the editor for an existing layout
Future<void> openLayoutEditor(BuildContext context, DisplayLayout layout) async {
  final service = context.read<DisplayStudioProvider>().service;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ChangeNotifierProvider(
        create: (_) => LayoutEditorProvider(service: service, initial: layout),
        child: const DisplayLayoutEditorPage(),
      ),
    ),
  );
}
