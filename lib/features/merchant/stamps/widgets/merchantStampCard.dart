import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../../stamps/widgets/stampCardVisual.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../../tools/widgets/merchantToolUi.dart';
import '../models/stampCardModel.dart';

/// Eine Stempelkarte in der Übersicht: große Vorschau, Titel + Belohnung,
/// Status, und wenige große Knöpfe. Der Hauptknopf hängt vom Zustand ab —
/// „Veröffentlichen" für Entwürfe, „Stempel-Link" für aktive Karten (das, was
/// der Händler wirklich braucht, um zu stempeln).
class MerchantStampCard extends StatelessWidget {
  const MerchantStampCard({
    super.key,
    required this.card,
    required this.onEdit,
    required this.onPublish,
    required this.onPause,
    required this.onDelete,
    required this.onStick,
  });

  final StampCardModel card;
  final VoidCallback onEdit;
  final VoidCallback onPublish;
  final VoidCallback onPause;
  final VoidCallback onDelete;

  /// Öffnet den Stempel-Link / Stift-Einrichtung für diese Karte.
  final VoidCallback onStick;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final reward = card.rewardTitle.trim().isEmpty
        ? card.rewardItemName.trim()
        : card.rewardTitle.trim();

    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      radius: 30,
      borderColor:
          card.isLive ? MerchantPremiumColors.gold : MerchantPremiumColors.line,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MerchantStampPreview(card: card, compact: true),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title.isEmpty
                          ? texts.text('merchant.stamps.untitled')
                          : card.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MerchantPremiumColors.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${card.requiredStamps} Stempel · ${reward.isEmpty ? 'Belohnung' : reward}',
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
              const SizedBox(width: AppSpacing.sm),
              _StatusPill(label: _statusLabel(texts, card.status)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Hauptknopf je nach Zustand ──────────────────────────────────
          if (card.isLive)
            MerchantPrimaryButton(
              label: 'Stempel-Link',
              icon: Icons.ios_share_rounded,
              onPressed: onStick,
            )
          else
            MerchantPrimaryButton(
              label: texts.text('merchant.stamps.publish'),
              icon: Icons.rocket_launch_rounded,
              onPressed: onPublish,
            ),
          const SizedBox(height: AppSpacing.sm),

          // ── Kleinere Aktionen ──────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _CardAction(
                  label: texts.text('common.edit'),
                  icon: Icons.edit_rounded,
                  onTap: onEdit,
                ),
              ),
              if (card.isLive) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _CardAction(
                    label: texts.text('merchant.stamps.pause'),
                    icon: Icons.pause_rounded,
                    onTap: onPause,
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: _CardAction(
                  label: texts.text('common.delete'),
                  icon: Icons.delete_outline_rounded,
                  isDanger: true,
                  onTap: onDelete,
                ),
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

class _CardAction extends StatelessWidget {
  const _CardAction({
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
    final color =
        isDanger ? MerchantPremiumColors.danger : MerchantPremiumColors.ink;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(
          color: isDanger
              ? MerchantPremiumColors.danger.withValues(alpha: 0.5)
              : MerchantPremiumColors.line,
        ),
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
        ],
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

String _statusLabel(LanguageService texts, String status) {
  return switch (status) {
    StampCardStatus.active => texts.text('merchant.stamps.status.active'),
    StampCardStatus.paused => texts.text('merchant.stamps.status.paused'),
    StampCardStatus.archived => texts.text('merchant.stamps.status.archived'),
    _ => texts.text('merchant.stamps.status.draft'),
  };
}
