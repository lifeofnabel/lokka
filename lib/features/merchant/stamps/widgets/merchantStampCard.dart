import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appColors.dart';
import '../../../../core/theme/appSpacing.dart';
import '../models/stampCardModel.dart';

class MerchantStampCard extends StatelessWidget {
  const MerchantStampCard({
    super.key,
    required this.card,
    required this.onEdit,
    required this.onPublish,
    required this.onPause,
    required this.onArchive,
    required this.onDeleteDraft,
  });

  final StampCardModel card;
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
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
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
                      card.title.isEmpty ? texts.text('merchant.stamps.untitled') : card.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
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
                        color: AppColors.gray700,
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
              if (!card.isArchivedCard)
                _MiniAction(
                  label: texts.text('merchant.stamps.archive'),
                  icon: Icons.archive_rounded,
                  onTap: onArchive,
                ),
              if (card.isDraft)
                _MiniAction(
                  label: texts.text('common.delete'),
                  icon: Icons.delete_outline_rounded,
                  isDanger: true,
                  onTap: onDeleteDraft,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class MerchantStampPreview extends StatelessWidget {
  const MerchantStampPreview({
    super.key,
    required this.card,
    this.compact = false,
  });

  final StampCardModel card;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final bg = _colorFromHex(card.backgroundColor, AppColors.black);
    final gradient = _colorFromHex(card.gradientColor, AppColors.mintStrong);
    final fg = _colorFromHex(card.textColor, AppColors.white);
    final accent = _colorFromHex(card.accentColor, AppColors.mint);
    final slots = math.min(card.requiredStamps, compact ? 10 : 15);
    final hasBackgroundImage = card.imageUrl.isNotEmpty && card.imagePlacement == 'background';

    return Container(
      constraints: BoxConstraints(minHeight: compact ? 160 : 220),
      decoration: BoxDecoration(
        color: bg,
        gradient: card.gradientEnabled
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [bg, gradient],
              )
            : null,
        borderRadius: BorderRadius.circular(compact ? 26 : 34),
        image: hasBackgroundImage
            ? DecorationImage(
                image: NetworkImage(card.imageUrl),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.42),
                  BlendMode.darken,
                ),
              )
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (card.imageUrl.isNotEmpty && card.imagePlacement == 'top') ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.network(
                  card.imageUrl,
                  width: double.infinity,
                  height: compact ? 76 : 110,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.title.isEmpty ? texts.text('merchant.stamps.previewTitle') : card.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: fg,
                          fontSize: compact ? 22 : 29,
                          height: 1.02,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (card.subtitle.trim().isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(
                          card.subtitle,
                          maxLines: compact ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: fg.withOpacity(0.72),
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              '${texts.text('merchant.stamps.rewardPrefix')} ${card.rewardTitle.isEmpty ? texts.text('merchant.stamps.previewReward') : card.rewardTitle}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: fg.withOpacity(0.82),
                                fontWeight: FontWeight.w900,
                                height: 1.25,
                              ),
                            ),
                          ),
                          if (card.description.trim().isNotEmpty)
                            Tooltip(
                              message: card.description,
                              child: Icon(
                                Icons.info_outline_rounded,
                                color: fg.withOpacity(0.78),
                                size: 19,
                              ),
                            ),
                        ],
                      ),
                      if (card.rewardDescription.trim().isNotEmpty && !compact) ...[
                        const SizedBox(height: 6),
                        Text(
                          card.rewardDescription,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: fg.withOpacity(0.62),
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (card.imageUrl.isNotEmpty && card.imagePlacement == 'side') ...[
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.network(
                      card.imageUrl,
                      width: compact ? 76 : 104,
                      height: compact ? 76 : 104,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...List.generate(
                  slots,
                  (index) => _StampSlot(
                    accent: accent,
                    fg: fg,
                    shape: card.stampShape,
                    iconValue: card.stampIconValue,
                    iconType: card.stampIconType,
                  ),
                ),
                if (slots < card.requiredStamps)
                  Container(
                    width: compact ? 34 : 40,
                    height: compact ? 34 : 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: fg.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '+${card.requiredStamps - slots}',
                      style: TextStyle(color: fg, fontWeight: FontWeight.w900),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StampSlot extends StatelessWidget {
  const _StampSlot({
    required this.accent,
    required this.fg,
    required this.shape,
    required this.iconValue,
    required this.iconType,
  });

  final Color accent;
  final Color fg;
  final String shape;
  final String iconValue;
  final String iconType;

  @override
  Widget build(BuildContext context) {
    final isSquare = shape == 'square';
    final isSoftSquare = shape == 'softSquare';
    final isDiamond = shape == 'diamond';
    return Container(
      width: 40,
      height: 40,
      transform: isDiamond ? (Matrix4.identity()..rotateZ(0.785398)) : null,
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(isSquare ? 8 : isSoftSquare || isDiamond ? 16 : 999),
        border: Border.all(color: fg.withOpacity(0.16)),
      ),
      child: Center(
        child: Transform.rotate(
          angle: isDiamond ? -0.785398 : 0,
          child: iconType == 'char'
              ? Text(
                  _stampText(iconValue),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                )
              : Icon(_iconFor(iconValue), color: AppColors.black, size: 20),
        ),
      ),
    );
  }
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
      avatar: Icon(icon, size: 17, color: isDanger ? Colors.red.shade700 : AppColors.black),
      label: Text(label),
      onPressed: onTap,
      labelStyle: TextStyle(
        color: isDanger ? Colors.red.shade700 : AppColors.black,
        fontWeight: FontWeight.w800,
      ),
      backgroundColor: AppColors.gray50,
      side: BorderSide(color: isDanger ? Colors.red.shade100 : AppColors.border),
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
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
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

Color _colorFromHex(String value, Color fallback) {
  final clean = value.replaceAll('#', '');
  if (clean.length != 6) return fallback;
  final parsed = int.tryParse('FF$clean', radix: 16);
  return parsed == null ? fallback : Color(parsed);
}

IconData _iconFor(String value) {
  return switch (value) {
    'coffee' => Icons.local_cafe_rounded,
    'food' => Icons.fastfood_rounded,
    'gift' => Icons.card_giftcard_rounded,
    'heart' => Icons.favorite_rounded,
    'local' => Icons.storefront_rounded,
    _ => Icons.star_rounded,
  };
}

String _stampText(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '*';
  return String.fromCharCodes(trimmed.runes.take(2));
}
