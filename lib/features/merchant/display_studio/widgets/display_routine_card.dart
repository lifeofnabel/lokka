import 'package:flutter/material.dart';

import '../../../../../core/theme/appColors.dart';
import '../../../../../core/theme/appRadius.dart';
import '../../../../../core/theme/appSpacing.dart';
import '../models/display_routine.dart';

class DisplayRoutineCard extends StatelessWidget {
  const DisplayRoutineCard({
    super.key,
    required this.routine,
    this.onToggle,
    this.onEdit,
    this.onDelete,
  });

  final DisplayRoutine routine;
  final VoidCallback? onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: routine.isActive ? AppColors.black : AppColors.gray50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.schedule_rounded,
              color: routine.isActive ? AppColors.white : AppColors.gray500,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  routine.title.isEmpty ? 'Routine' : routine.title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _Pill(label: routine.daysLabel),
                    const SizedBox(width: 6),
                    _Pill(label: '${routine.startTime} – ${routine.endTime}'),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _MetaItem(
                      icon: Icons.tv_rounded,
                      label: '${routine.deviceIds.length} Displays',
                    ),
                    const SizedBox(width: 10),
                    _MetaItem(
                      icon: Icons.dashboard_rounded,
                      label: '${routine.layoutIds.length} Layouts',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (onToggle != null || onEdit != null || onDelete != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: AppColors.gray500),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (v) {
                if (v == 'toggle' && onToggle != null) onToggle!();
                if (v == 'edit' && onEdit != null) onEdit!();
                if (v == 'delete' && onDelete != null) onDelete!();
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'toggle',
                    child: Row(children: [
                      Icon(routine.isActive ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 17),
                      const SizedBox(width: 8),
                      Text(routine.isActive ? 'Pausieren' : 'Aktivieren'),
                    ])),
                const PopupMenuItem(value: 'edit',
                    child: Row(children: [Icon(Icons.edit_rounded, size: 17), SizedBox(width: 8), Text('Bearbeiten')])),
                const PopupMenuItem(value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline_rounded, size: 17, color: Color(0xFFEF4444)),
                      SizedBox(width: 8),
                      Text('Löschen', style: TextStyle(color: Color(0xFFEF4444))),
                    ])),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: routine.isActive ? const Color(0xFFDCFCE7) : AppColors.gray50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                routine.isActive ? 'Aktiv' : 'Inaktiv',
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800,
                  color: routine.isActive ? const Color(0xFF16A34A) : AppColors.gray500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.gray700,
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.gray500),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.gray500,
          ),
        ),
      ],
    );
  }
}
