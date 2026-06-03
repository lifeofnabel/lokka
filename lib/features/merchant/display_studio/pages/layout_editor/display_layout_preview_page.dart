import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/appColors.dart';
import '../../providers/layout_editor_provider.dart';
import '../../widgets/layout_preview_widget.dart';

class DisplayLayoutPreviewPage extends StatelessWidget {
  const DisplayLayoutPreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final editor = context.watch<LayoutEditorProvider>();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          editor.title.isEmpty ? 'Vorschau' : editor.title,
          style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.white),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final ok = await editor.save(asDraft: false);
              if (!context.mounted) return;
              if (ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Layout gespeichert ✓'),
                    backgroundColor: Color(0xFF1A2A1A),
                    duration: Duration(seconds: 2),
                  ),
                );
                Navigator.of(context).pop();
              }
            },
            child: const Text('Speichern',
                style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.white)),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LayoutPreviewWidget(
                  layout: editor.layout,
                  blocks: editor.blocks,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _InfoChip(Icons.tv_rounded,
                        editor.orientation.name == 'portrait' ? 'Hochformat' : 'Querformat'),
                    const SizedBox(width: 8),
                    _InfoChip(Icons.wb_sunny_rounded,
                        editor.mode == 'night' ? 'Nacht' : 'Tag'),
                    const SizedBox(width: 8),
                    _InfoChip(Icons.animation_rounded,
                        _animLabel(editor.animation)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _animLabel(String anim) {
    switch (anim) {
      case 'slide': return 'Slide';
      case 'softZoom': return 'Soft Zoom';
      case 'cardSwitch': return 'Card Switch';
      default: return 'Fade';
    }
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2A1E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.mint),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.white)),
        ],
      ),
    );
  }
}
