import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appColors.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';
import '../models/pointsSystemModel.dart';

class PointsSystemCard extends StatelessWidget {
  const PointsSystemCard({
    super.key,
    required this.system,
    required this.onEdit,
    required this.onPublish,
    required this.onPause,
    required this.onArchive,
    required this.onDeleteDraft,
  });

  final PointsSystemModel system;
  final VoidCallback onEdit;
  final VoidCallback onPublish;
  final VoidCallback onPause;
  final VoidCallback onArchive;
  final VoidCallback onDeleteDraft;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final isActive = system.isLive;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isActive ? AppColors.black : AppColors.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: isActive ? AppColors.black : AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isActive ? 0.14 : 0.05),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.mint : AppColors.gray50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.stars_rounded, color: AppColors.black),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      system.title.isEmpty ? texts.text('merchant.points.defaultSystem') : system.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isActive ? AppColors.white : AppColors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${system.pointsPerEuro} ${texts.text('merchant.points.pointsPerEuro')}',
                      style: TextStyle(
                        color: isActive ? AppColors.white.withOpacity(0.70) : AppColors.gray700,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(
                label: _statusLabel(texts, system.status),
                dark: isActive,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniAction(label: texts.text('common.edit'), icon: Icons.edit_rounded, onTap: onEdit, dark: isActive),
              if (system.isDraft || system.isPaused)
                _MiniAction(label: texts.text('merchant.points.activate'), icon: Icons.rocket_launch_rounded, onTap: onPublish, dark: isActive),
              if (system.isLive)
                _MiniAction(label: texts.text('merchant.points.pause'), icon: Icons.pause_rounded, onTap: onPause, dark: isActive),
              if (!system.isArchivedSystem)
                _MiniAction(label: texts.text('merchant.points.archive'), icon: Icons.archive_rounded, onTap: onArchive, dark: isActive),
              if (system.isDraft)
                _MiniAction(label: texts.text('common.delete'), icon: Icons.delete_outline_rounded, onTap: onDeleteDraft, isDanger: true, dark: isActive),
            ],
          ),
        ],
      ),
    );
  }
}

class PointsRewardCard extends StatelessWidget {
  const PointsRewardCard({
    super.key,
    required this.reward,
    required this.onEdit,
    required this.onPublish,
    required this.onPause,
    required this.onArchive,
    required this.onDeleteDraft,
  });

  final PointsRewardModel reward;
  final VoidCallback onEdit;
  final VoidCallback onPublish;
  final VoidCallback onPause;
  final VoidCallback onArchive;
  final VoidCallback onDeleteDraft;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              PointsRewardPreview(reward: reward, size: 70),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reward.title.isEmpty ? texts.text('merchant.points.rewardUntitled') : reward.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${reward.requiredPoints} ${texts.text('merchant.points.points')} | ${_rewardTypeLabel(texts, reward.rewardType)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.gray700, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 7),
                    _StatusPill(label: _statusLabel(texts, reward.status), dark: false),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniAction(label: texts.text('common.edit'), icon: Icons.edit_rounded, onTap: onEdit),
              if (reward.isDraft || reward.isPaused)
                _MiniAction(label: texts.text('merchant.points.activate'), icon: Icons.rocket_launch_rounded, onTap: onPublish),
              if (reward.isLive)
                _MiniAction(label: texts.text('merchant.points.pause'), icon: Icons.pause_rounded, onTap: onPause),
              if (!reward.isArchivedReward)
                _MiniAction(label: texts.text('merchant.points.archive'), icon: Icons.archive_rounded, onTap: onArchive),
              if (reward.isDraft)
                _MiniAction(label: texts.text('common.delete'), icon: Icons.delete_outline_rounded, onTap: onDeleteDraft, isDanger: true),
            ],
          ),
        ],
      ),
    );
  }
}

class PointsRewardPreview extends StatelessWidget {
  const PointsRewardPreview({
    super.key,
    required this.reward,
    this.size = 120,
  });

  final PointsRewardModel reward;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(size > 90 ? 30 : 22),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: reward.imageUrl.isEmpty
          ? const Icon(Icons.card_giftcard_rounded, color: AppColors.black)
          : Image.network(reward.imageUrl, fit: BoxFit.cover),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isDanger = false,
    this.dark = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDanger;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final color = isDanger ? Colors.red.shade700 : dark ? AppColors.white : AppColors.black;
    return ActionChip(
      avatar: Icon(icon, size: 17, color: color),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: dark ? AppColors.white.withOpacity(0.10) : AppColors.gray50,
      side: BorderSide(color: dark ? AppColors.white.withOpacity(0.14) : AppColors.border),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w800),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.dark});

  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: dark ? AppColors.white.withOpacity(0.12) : AppColors.gray50,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: dark ? AppColors.white.withOpacity(0.16) : AppColors.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: dark ? AppColors.white : AppColors.black,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String _statusLabel(LanguageService texts, String status) {
  return switch (status) {
    PointsStatus.active => texts.text('merchant.points.status.active'),
    PointsStatus.paused => texts.text('merchant.points.status.paused'),
    PointsStatus.archived => texts.text('merchant.points.status.archived'),
    _ => texts.text('merchant.points.status.draft'),
  };
}

String _rewardTypeLabel(LanguageService texts, String type) {
  return switch (type) {
    PointsRewardType.item => texts.text('merchant.points.reward.item'),
    PointsRewardType.discount => texts.text('merchant.points.reward.discount'),
    _ => texts.text('merchant.points.reward.custom'),
  };
}
