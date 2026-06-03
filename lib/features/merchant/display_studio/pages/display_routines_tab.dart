import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/appColors.dart';
import '../../../../core/theme/appSpacing.dart';
import '../models/display_routine.dart';
import '../providers/display_studio_provider.dart';
import '../widgets/display_routine_card.dart';
import 'routine_form/routine_form_page.dart';

class DisplayRoutinesTab extends StatelessWidget {
  const DisplayRoutinesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DisplayStudioProvider>();
    final routines = provider.routines;

    if (routines.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                    color: AppColors.black, borderRadius: BorderRadius.circular(24)),
                child: const Icon(Icons.schedule_rounded, color: AppColors.white, size: 34),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text('Noch keine Routinen.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: AppSpacing.sm),
              const Text('Plane automatische Abläufe für deine Displays.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.gray500, fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: () => _openForm(context, provider),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Routine erstellen'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.black,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        ListView.separated(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, 90),
          itemCount: routines.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (ctx, i) {
            final routine = routines[i];
            return DisplayRoutineCard(
              routine: routine,
              onToggle: () => provider.toggleRoutine(routine.id, !routine.isActive),
              onEdit: () => _openForm(context, provider, existing: routine),
              onDelete: () => _confirmDelete(context, provider, routine),
            );
          },
        ),
        Positioned(
          bottom: AppSpacing.md,
          right: AppSpacing.md,
          child: FloatingActionButton.extended(
            onPressed: () => _openForm(context, provider),
            backgroundColor: AppColors.black,
            foregroundColor: AppColors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Routine', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ),
      ],
    );
  }

  void _openForm(BuildContext context, DisplayStudioProvider provider,
      {DisplayRoutine? existing}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RoutineFormPage(
          service: provider.service,
          layouts: provider.layouts,
          devices: provider.devices,
          existing: existing,
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, DisplayStudioProvider provider, DisplayRoutine routine) {
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
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(22)),
              child: const Icon(Icons.delete_outline_rounded, color: AppColors.white),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text('Routine löschen?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: AppSpacing.sm),
            Text('"${routine.title}" wird dauerhaft gelöscht.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.gray700)),
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
                    provider.deleteRoutine(routine.id);
                  },
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444)),
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
