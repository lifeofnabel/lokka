import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../../stamps/widgets/stampCardVisual.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../models/stampCardModel.dart';

/// Eine Stempelkarte in der Übersicht: große Vorschau, Titel + Belohnung,
/// Status. Rein visuell — liegt in der swipebaren Vorschau; alle Aktionen
/// (Veröffentlichen, Stift, Limit, Bearbeiten, Pausieren, Löschen) sitzen fest
/// AUSSERHALB davon (siehe `_ActionPanel` in merchantStampsPage.dart), damit man
/// zum Bedienen nicht erst zur richtigen Karte swipen muss.
class MerchantStampCard extends StatelessWidget {
  const MerchantStampCard({super.key, required this.card});

  final StampCardModel card;

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
