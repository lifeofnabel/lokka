import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../models/stampCardModel.dart';
import 'merchantStampCard.dart';

/// A starter template so the builder never opens blank. Applies design +
/// sensible defaults; the merchant tweaks from there.
class StampTemplate {
  const StampTemplate({
    required this.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.rewardTitle,
    required this.requiredStamps,
    required this.conditionType,
    required this.backgroundColor,
    required this.gradientColor,
    required this.gradientEnabled,
    required this.accentColor,
    required this.textColor,
    required this.styleName,
    required this.stampShape,
    required this.stampIcon,
  });

  final String key;
  final String emoji;
  final String title;
  final String subtitle;
  final String rewardTitle;
  final int requiredStamps;
  final String conditionType;
  final String backgroundColor;
  final String gradientColor;
  final bool gradientEnabled;
  final String accentColor;
  final String textColor;
  final String styleName;
  final String stampShape;
  final String stampIcon;
}

const List<StampTemplate> kStampTemplates = [
  StampTemplate(
    key: 'coffee',
    emoji: '☕',
    title: 'Kaffee-Karte',
    subtitle: '10 Kaffee = 1 gratis',
    rewardTitle: 'Gratis-Kaffee',
    requiredStamps: 10,
    conditionType: StampConditionType.visit,
    backgroundColor: '#2A1C12',
    gradientColor: '#8A5A33',
    gradientEnabled: true,
    accentColor: '#E8C9A0',
    textColor: '#FFF6EC',
    styleName: 'mocha',
    stampShape: 'circle',
    stampIcon: 'coffee',
  ),
  StampTemplate(
    key: 'food',
    emoji: '🥙',
    title: 'Döner-Karte',
    subtitle: 'Sammeln & sparen',
    rewardTitle: 'Gratis-Döner',
    requiredStamps: 8,
    conditionType: StampConditionType.minimumAmount,
    backgroundColor: '#161E16',
    gradientColor: '#3C7A3C',
    gradientEnabled: true,
    accentColor: '#BFE8B0',
    textColor: '#F4FFF0',
    styleName: 'fresh',
    stampShape: 'softSquare',
    stampIcon: 'food',
  ),
  StampTemplate(
    key: 'beauty',
    emoji: '💅',
    title: 'Treue-Karte',
    subtitle: 'Für deine Stammkunden',
    rewardTitle: '20% Rabatt',
    requiredStamps: 6,
    conditionType: StampConditionType.visit,
    backgroundColor: '#1E1622',
    gradientColor: '#7A4D8C',
    gradientEnabled: true,
    accentColor: '#E6C2F0',
    textColor: '#FBF2FF',
    styleName: 'velvet',
    stampShape: 'diamond',
    stampIcon: 'heart',
  ),
  StampTemplate(
    key: 'noir',
    emoji: '⭐',
    title: 'Bonus-Karte',
    subtitle: 'Schlicht & elegant',
    rewardTitle: 'Gratis-Belohnung',
    requiredStamps: 10,
    conditionType: StampConditionType.visit,
    backgroundColor: '#171A18',
    gradientColor: '#45C9A4',
    gradientEnabled: false,
    accentColor: '#9CE8CF',
    textColor: '#FEFFFC',
    styleName: 'noir',
    stampShape: 'circle',
    stampIcon: 'star',
  ),
];

/// Horizontal gallery of starter templates shown at the top of step 1.
class StampTemplateGallery extends StatelessWidget {
  const StampTemplateGallery({super.key, required this.onPick});

  final void Function(StampTemplate) onPick;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          texts.text('merchant.stamps.templatesTitle'),
          style: const TextStyle(
              color: MerchantPremiumColors.ink,
              fontWeight: FontWeight.w900,
              fontSize: 15),
        ),
        const SizedBox(height: 4),
        Text(
          texts.text('merchant.stamps.templatesSubtitle'),
          style: const TextStyle(
              color: MerchantPremiumColors.muted, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kStampTemplates.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final t = kStampTemplates[i];
              return InkWell(
                onTap: () => onPick(t),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 132,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MerchantPremiumColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: MerchantPremiumColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.emoji, style: const TextStyle(fontSize: 26)),
                      const Spacer(),
                      Text(t.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: MerchantPremiumColors.ink,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(t.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: MerchantPremiumColors.muted,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Editor for optional intermediate reward milestones (tiered rewards). The
/// final reward stays in the main reward fields; here the merchant adds earlier
/// milestones like "5 = 10% Rabatt".
class StampTieredRewardsEditor extends StatelessWidget {
  const StampTieredRewardsEditor({
    super.key,
    required this.tiers,
    required this.maxStamps,
    required this.onAdd,
    required this.onRemove,
  });

  final List<StampRewardTier> tiers;
  final int maxStamps;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final sorted = [...tiers]..sort((a, b) => a.atStamp.compareTo(b.atStamp));
    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: MerchantPremiumColors.surfaceAlt,
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.stairs_rounded,
                  color: MerchantPremiumColors.gold, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(texts.text('merchant.stamps.tiersTitle'),
                    style: const TextStyle(
                        color: MerchantPremiumColors.ink,
                        fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(texts.text('merchant.stamps.tiersSubtitle'),
              style: const TextStyle(
                  color: MerchantPremiumColors.muted,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          if (sorted.isEmpty)
            Text(texts.text('merchant.stamps.tiersEmpty'),
                style: const TextStyle(
                    color: MerchantPremiumColors.muted,
                    fontStyle: FontStyle.italic))
          else
            ...List.generate(sorted.length, (i) {
              final t = sorted[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: MerchantPremiumColors.gold.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('${t.atStamp}',
                          style: const TextStyle(
                              color: MerchantPremiumColors.ink,
                              fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(t.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: MerchantPremiumColors.ink,
                              fontWeight: FontWeight.w800)),
                    ),
                    IconButton(
                      onPressed: () => onRemove(tiers.indexOf(t)),
                      icon: const Icon(Icons.close_rounded,
                          color: MerchantPremiumColors.muted, size: 20),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: maxStamps > 1 ? onAdd : null,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(texts.text('merchant.stamps.tiersAdd')),
            style: OutlinedButton.styleFrom(
              foregroundColor: MerchantPremiumColors.ink,
              side: const BorderSide(color: MerchantPremiumColors.line),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog to add an intermediate tier: pick the stamp count (< max) and a label.
Future<StampRewardTier?> showStampTierDialog(
  BuildContext context, {
  required int maxStamps,
}) {
  final texts = context.read<LanguageService>();
  final labelCtrl = TextEditingController();
  int at = (maxStamps / 2).clamp(1, maxStamps - 1).floor();
  if (at < 1) at = 1;

  return showModalBottomSheet<StampRewardTier>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: MerchantPremiumColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: StatefulBuilder(
          builder: (ctx, setLocal) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(texts.text('merchant.stamps.tiersAdd'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: MerchantPremiumColors.ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: AppSpacing.md),
              Text(
                '${texts.text('merchant.stamps.tiersAtStamp')}: $at',
                style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontWeight: FontWeight.w800),
              ),
              Slider(
                value: at.toDouble(),
                min: 1,
                max: (maxStamps - 1).clamp(1, 30).toDouble(),
                divisions: (maxStamps - 1).clamp(1, 29),
                activeColor: MerchantPremiumColors.gold,
                label: '$at',
                onChanged: (v) => setLocal(() => at = v.round()),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: labelCtrl,
                style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: texts.text('merchant.stamps.tiersLabelHint'),
                  hintStyle: const TextStyle(color: MerchantPremiumColors.muted),
                  filled: true,
                  fillColor: MerchantPremiumColors.surfaceAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: MerchantPremiumColors.line),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () {
                  final label = labelCtrl.text.trim();
                  if (label.isEmpty) return;
                  Navigator.of(ctx).pop(StampRewardTier(
                    atStamp: at,
                    type: StampRewardType.custom,
                    label: label,
                  ));
                },
                style: FilledButton.styleFrom(
                  backgroundColor: MerchantPremiumColors.gold,
                  foregroundColor: MerchantPremiumColors.base,
                  minimumSize: const Size.fromHeight(52),
                  shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: Text(texts.text('common.add')),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Preview body with a "card / customer wallet" toggle.
class StampPreviewBody extends StatefulWidget {
  const StampPreviewBody({super.key, required this.card});
  final StampCardModel card;

  @override
  State<StampPreviewBody> createState() => _StampPreviewBodyState();
}

class _StampPreviewBodyState extends State<StampPreviewBody> {
  bool _wallet = false;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card vs customer-wallet toggle.
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: MerchantPremiumColors.surfaceAlt,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                _toggle(texts.text('merchant.stamps.previewCard'), !_wallet,
                    () => setState(() => _wallet = false)),
                _toggle(texts.text('merchant.stamps.previewWallet'), _wallet,
                    () => setState(() => _wallet = true)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Flexible(
            child: SingleChildScrollView(
              child: _wallet
                  ? StampWalletPreview(card: widget.card)
                  : MerchantStampPreview(card: widget.card),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggle(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? MerchantPremiumColors.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                  color:
                      active ? MerchantPremiumColors.base : MerchantPremiumColors.muted,
                  fontWeight: FontWeight.w900,
                  fontSize: 13)),
        ),
      ),
    );
  }
}

/// Frames the card the way a customer sees it in their wallet, with a sample
/// progress line — the "So sieht's im Kunden-Wallet aus" view.
class StampWalletPreview extends StatelessWidget {
  const StampWalletPreview({super.key, required this.card});
  final StampCardModel card;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final max = card.maxStamps;
    final sample = (max * 0.6).round().clamp(0, max);
    final remaining = (max - sample).clamp(0, max);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: MerchantPremiumColors.surfaceAlt,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: MerchantPremiumColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded,
                  color: MerchantPremiumColors.gold, size: 18),
              const SizedBox(width: 6),
              Text(texts.text('merchant.stamps.previewWallet'),
                  style: const TextStyle(
                      color: MerchantPremiumColors.muted,
                      fontWeight: FontWeight.w900,
                      fontSize: 12)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          MerchantStampPreview(card: card),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: max == 0 ? 0 : sample / max,
              minHeight: 10,
              backgroundColor: MerchantPremiumColors.line,
              valueColor: const AlwaysStoppedAnimation(MerchantPremiumColors.gold),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            texts
                .text('merchant.stamps.previewProgress')
                .replaceFirst('{n}', '$remaining'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: MerchantPremiumColors.ink, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
