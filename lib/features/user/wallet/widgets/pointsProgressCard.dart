import 'package:flutter/material.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/wallet/models/pointsProgressModel.dart';

/// Calm M3 points card: tonal icon, clear current/lifetime hierarchy.
class PointsProgressCard extends StatelessWidget {
  const PointsProgressCard({
    super.key,
    required this.progress,
    this.merchantName,
  });

  final PointsProgressModel progress;
  final String? merchantName;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

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
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.stars_rounded,
                  size: 20,
                  color: cs.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      merchantName ?? 'Punktekonto',
                      style: tt.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Aktuelle Punkte',
                      style: tt.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${progress.currentPoints}',
                style: tt.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1,
                  letterSpacing: -1,
                  color: cs.primary,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 6),
                child: Text(
                  'Punkte',
                  style: tt.titleMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Gesamt',
                    style: tt.labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  Text(
                    '${progress.lifetimePoints}',
                    style: tt.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
          if (progress.resetDay != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceGray,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_repeat_rounded,
                      size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    'Reset am ${progress.resetDay}. jeden Monats',
                    style: tt.labelMedium
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
