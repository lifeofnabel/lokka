import 'package:flutter/material.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/wallet/models/stampProgressModel.dart';

/// Calm M3 stamp card: tonal accents, clear progress, one primary action.
class StampProgressCard extends StatelessWidget {
  const StampProgressCard({
    super.key,
    required this.progress,
    this.onClaim,
  });

  final StampProgressModel progress;
  final VoidCallback? onClaim;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final ratio = progress.stampsRequired > 0
        ? (progress.currentStamps / progress.stampsRequired).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: progress.isCompleted
                      ? cs.secondaryContainer
                      : AppColors.surfaceGray,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.loyalty_rounded,
                  size: 20,
                  color: progress.isCompleted
                      ? cs.onSecondaryContainer
                      : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stempelkarte',
                      style: tt.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${progress.currentStamps} / ${progress.stampsRequired} Stempel',
                      style: tt.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (progress.isCompleted && !progress.isClaimed)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'Fertig',
                    style: tt.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSecondaryContainer,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: AppColors.surfaceGray,
              valueColor: AlwaysStoppedAnimation(cs.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _StampGrid(
            current: progress.currentStamps,
            required: progress.stampsRequired,
          ),
          if (progress.isCompleted && !progress.isClaimed && onClaim != null) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onClaim,
                child: const Text('Belohnung einlösen'),
              ),
            ),
          ] else if (progress.isClaimed) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded,
                    size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  'Bereits eingelöst',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StampGrid extends StatelessWidget {
  const _StampGrid({required this.current, required this.required});

  final int current;
  final int required;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final count = required.clamp(1, 20);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List.generate(count, (i) {
        final filled = i < current;
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: filled ? cs.primary : AppColors.surfaceGray,
            shape: BoxShape.circle,
          ),
          child: Icon(
            filled ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 16,
            color: filled ? cs.onPrimary : cs.onSurfaceVariant,
          ),
        );
      }),
    );
  }
}
