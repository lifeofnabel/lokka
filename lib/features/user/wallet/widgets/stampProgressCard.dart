import 'package:flutter/material.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/wallet/models/stampProgressModel.dart';

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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: progress.isCompleted ? AppColors.mintSoft : AppColors.gray50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.stamp,
                  size: 18,
                  color: progress.isCompleted ? AppColors.mintStrong : AppColors.gray300,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stempelkarte',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.black,
                      ),
                    ),
                    Text(
                      '${progress.currentStamps} / ${progress.stampsRequired} Stempel',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.gray500,
                      ),
                    ),
                  ],
                ),
              ),
              if (progress.isCompleted && !progress.isClaimed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.mintSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Fertig!',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.mintStrong,
                    ),
                  ),
                ),
            ],
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
              height: 44,
              child: FilledButton(
                onPressed: onClaim,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.mintStrong,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: const Text(
                  'Belohnung einlösen',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ] else if (progress.isClaimed) ...[
            const SizedBox(height: AppSpacing.sm),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded, size: 16, color: AppColors.gray300),
                SizedBox(width: 4),
                Text(
                  'Bereits eingelöst',
                  style: TextStyle(fontSize: 12, color: AppColors.gray300),
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
            color: filled ? AppColors.mintStrong : AppColors.gray50,
            shape: BoxShape.circle,
            border: Border.all(
              color: filled ? AppColors.mintStrong : AppColors.border,
            ),
          ),
          child: Icon(
            filled ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 16,
            color: filled ? Colors.white : AppColors.gray300,
          ),
        );
      }),
    );
  }
}
