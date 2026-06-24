import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../../stamps/widgets/stampCardVisual.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../models/stampCardModel.dart';

class MerchantStampCard extends StatelessWidget {
  const MerchantStampCard({
    super.key,
    required this.card,
    required this.onEdit,
    required this.onPublish,
    required this.onPause,
    required this.onDelete,
  });

  final StampCardModel card;
  final VoidCallback onEdit;
  final VoidCallback onPublish;
  final VoidCallback onPause;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      radius: 30,
      borderColor: card.isLive ? MerchantPremiumColors.ink : MerchantPremiumColors.line,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MerchantStampPreview(card: card, compact: true),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: card.isLive ? MerchantPremiumColors.ink : MerchantPremiumColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: card.isLive ? MerchantPremiumColors.ink : MerchantPremiumColors.line,
                  ),
                ),
                child: Icon(
                  card.isLive ? Icons.check_rounded : Icons.more_horiz_rounded,
                  color: card.isLive ? MerchantPremiumColors.base : MerchantPremiumColors.muted,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title.isEmpty ? texts.text('merchant.stamps.untitled') : card.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MerchantPremiumColors.ink,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${card.requiredStamps} ${texts.text('merchant.stamps.stamps')} | ${_conditionLabel(texts, card)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MerchantPremiumColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(label: _statusLabel(texts, card.status)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _StickBadge(verified: card.stickVerified, bound: card.hasStick),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniAction(
                label: texts.text('common.edit'),
                icon: Icons.edit_rounded,
                onTap: onEdit,
              ),
              if (card.isDraft || card.isPaused)
                _MiniAction(
                  label: texts.text('merchant.stamps.publish'),
                  icon: Icons.rocket_launch_rounded,
                  onTap: onPublish,
                ),
              if (card.isLive)
                _MiniAction(
                  label: texts.text('merchant.stamps.pause'),
                  icon: Icons.pause_rounded,
                  onTap: onPause,
                ),
              _MiniAction(
                label: texts.text('common.delete'),
                icon: Icons.delete_outline_rounded,
                isDanger: true,
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Thin wrapper kept for source/import compatibility — the actual rendering
/// lives in the shared [StampCardVisual] (single source of truth, reused by the
/// wallet and the stamp-card ad generator too).
class MerchantStampPreview extends StatelessWidget {
  const MerchantStampPreview({
    super.key,
    required this.card,
    this.compact = false,
  });

  final StampCardModel card;
  final bool compact;

  @override
  Widget build(BuildContext context) =>
      StampCardVisual(card: card, compact: compact);
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isDanger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 17, color: isDanger ? Colors.red.shade700 : MerchantPremiumColors.ink),
      label: Text(label),
      onPressed: onTap,
      labelStyle: TextStyle(
        color: isDanger ? Colors.red.shade700 : MerchantPremiumColors.ink,
        fontWeight: FontWeight.w800,
      ),
      backgroundColor: MerchantPremiumColors.surfaceAlt,
      side: BorderSide(color: isDanger ? Colors.red.shade100 : MerchantPremiumColors.line),
    );
  }
}

class _StickBadge extends StatelessWidget {
  const _StickBadge({required this.verified, required this.bound});

  /// Stick bound AND passed a Test-Tap → "Stift verbunden ✓".
  final bool verified;

  /// Stick bound but not yet test-tapped → "Test-Tap nötig".
  final bool bound;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final (labelKey, icon, color) = verified
        ? (
            'merchant.stick.connected',
            Icons.check_circle_rounded,
            MerchantPremiumColors.gold
          )
        : bound
            ? (
                'merchant.stick.testNeeded',
                Icons.touch_app_rounded,
                MerchantPremiumColors.muted
              )
            : (
                'merchant.stick.notConnected',
                Icons.link_off_rounded,
                MerchantPremiumColors.muted
              );
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              texts.text(labelKey),
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: MerchantPremiumColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: MerchantPremiumColors.line),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: MerchantPremiumColors.ink,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String _conditionLabel(LanguageService texts, StampCardModel card) {
  return switch (card.conditionType) {
    StampConditionType.minimumAmount => texts.text('merchant.stamps.condition.minimumAmount'),
    StampConditionType.item => card.requiredItemName.isNotEmpty ? card.requiredItemName : texts.text('merchant.stamps.condition.item'),
    StampConditionType.custom => texts.text('merchant.stamps.condition.custom'),
    _ => texts.text('merchant.stamps.condition.visit'),
  };
}

String _statusLabel(LanguageService texts, String status) {
  return switch (status) {
    StampCardStatus.active => texts.text('merchant.stamps.status.active'),
    StampCardStatus.paused => texts.text('merchant.stamps.status.paused'),
    StampCardStatus.archived => texts.text('merchant.stamps.status.archived'),
    _ => texts.text('merchant.stamps.status.draft'),
  };
}

