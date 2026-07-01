import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/languageService.dart';
import '../../../core/theme/appSpacing.dart';
import '../../merchant/stamps/models/stampCardModel.dart';

/// THE single source-of-truth renderer for a stamp card's visual face.
///
/// Reused everywhere a card is shown to look identical: the merchant manage
/// carousel, the builder live preview, the customer wallet, and the
/// auto-generated stamp-card ad image (captured via `RepaintBoundary`). One
/// renderer, many uses — change it once, it is right everywhere.
///
/// It is theme-agnostic (colours come from the card itself) so it renders the
/// same in the light user app and the dark merchant app.
class StampCardVisual extends StatelessWidget {
  const StampCardVisual({
    super.key,
    required this.card,
    this.compact = false,
    this.filledStamps,
  });

  final StampCardModel card;

  /// Tighter sizing for list/carousel tiles (smaller title, fewer slots,
  /// reward description hidden). Off = full size (wallet / ad / detail).
  final bool compact;

  /// When set, renders real progress: the first [filledStamps] slots are stamped
  /// and the rest are hollow (the customer wallet). When null the card is a
  /// design preview and every slot is shown filled (merchant builder/carousel).
  final int? filledStamps;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final bg = _colorFromHex(card.backgroundColor, const Color(0xFF171A18));
    final gradient = _colorFromHex(card.gradientColor, const Color(0xFF45C9A4));
    final fg = _colorFromHex(card.textColor, const Color(0xFFFEFFFC));
    final accent = _colorFromHex(card.accentColor, const Color(0xFF9CE8CF));
    final slots = math.min(card.requiredStamps, compact ? 10 : 15);
    final hasBackgroundImage =
        card.imageUrl.isNotEmpty && card.imagePlacement == 'background';

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
                  Colors.black.withValues(alpha: 0.42),
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
                        card.title.isEmpty
                            ? texts.text('merchant.stamps.previewTitle')
                            : card.title,
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
                            color: fg.withValues(alpha: 0.72),
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
                                color: fg.withValues(alpha: 0.82),
                                fontWeight: FontWeight.w900,
                                height: 1.25,
                              ),
                            ),
                          ),
                          if (card.description.trim().isNotEmpty)
                            Tooltip(
                              message: card.description,
                              // Ohne das hier: Tooltip löst auf Touch nur bei
                              // Long-Press (Default), nicht bei normalem Tap –
                              // fühlt sich auf dem Handy/Touchscreen kaputt an.
                              // Tap-Trigger wie beim geteilten
                              // MerchantInfoTooltip.
                              triggerMode: TooltipTriggerMode.tap,
                              showDuration: const Duration(seconds: 6),
                              child: Icon(
                                Icons.info_outline_rounded,
                                color: fg.withValues(alpha: 0.78),
                                size: 19,
                              ),
                            ),
                        ],
                      ),
                      if (card.rewardDescription.trim().isNotEmpty &&
                          !compact) ...[
                        const SizedBox(height: 6),
                        Text(
                          card.rewardDescription,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: fg.withValues(alpha: 0.62),
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (card.imageUrl.isNotEmpty &&
                    card.imagePlacement == 'side') ...[
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
            _StampGrid(
              count: slots,
              overflow: card.requiredStamps - slots,
              filled: filledStamps == null
                  ? slots
                  : filledStamps!.clamp(0, slots),
              accent: accent,
              fg: fg,
              shape: card.stampShape,
              iconValue: card.stampIconValue,
              iconType: card.stampIconType,
            ),
          ],
        ),
      ),
    );
  }
}

/// Lays the stamp slots out in balanced, full-width rows so the card looks like
/// a real stamp card (evenly spread) instead of clustering to the left.
class _StampGrid extends StatelessWidget {
  const _StampGrid({
    required this.count,
    required this.overflow,
    required this.filled,
    required this.accent,
    required this.fg,
    required this.shape,
    required this.iconValue,
    required this.iconType,
  });

  final int count;
  final int overflow;
  final int filled;
  final Color accent;
  final Color fg;
  final String shape;
  final String iconValue;
  final String iconType;

  int _perRow(int total) {
    if (total <= 5) return total < 1 ? 1 : total;
    if (total <= 10) return (total / 2).ceil();
    return 5;
  }

  @override
  Widget build(BuildContext context) {
    final total = count + (overflow > 0 ? 1 : 0);
    if (total < 1) return const SizedBox.shrink();
    final perRow = _perRow(total);

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final maxW = constraints.maxWidth;
        double size = (maxW - gap * (perRow - 1)) / perRow;
        size = size.clamp(34.0, 64.0);

        Widget slot(int index) {
          if (overflow > 0 && index == count) {
            return Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fg.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('+$overflow',
                  style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w900,
                      fontSize: size * 0.34)),
            );
          }
          return _StampSlot(
            accent: accent,
            fg: fg,
            shape: shape,
            iconValue: iconValue,
            iconType: iconType,
            size: size,
            filled: index < filled,
          );
        }

        final rows = <Widget>[];
        for (var i = 0; i < total; i += perRow) {
          final end = (i + perRow) < total ? i + perRow : total;
          final children = <Widget>[];
          for (var j = i; j < end; j++) {
            if (j > i) children.add(const SizedBox(width: gap));
            children.add(slot(j));
          }
          rows.add(Row(
              mainAxisAlignment: MainAxisAlignment.center, children: children));
        }

        return Column(
          children: [
            for (var r = 0; r < rows.length; r++) ...[
              if (r > 0) const SizedBox(height: gap),
              rows[r],
            ],
          ],
        );
      },
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
    this.size = 40,
    this.filled = true,
  });

  final Color accent;
  final Color fg;
  final String shape;
  final String iconValue;
  final String iconType;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final isSquare = shape == 'square';
    final isSoftSquare = shape == 'softSquare';
    final isDiamond = shape == 'diamond';
    final onAccent = accent.computeLuminance() > 0.5
        ? const Color(0xFF171A18)
        : const Color(0xFFFEFFFC);
    // Hollow (not-yet-earned) slots: faint fill, dimmed outline icon.
    final slotColor = filled ? accent : fg.withValues(alpha: 0.10);
    final iconColor = filled ? onAccent : fg.withValues(alpha: 0.34);
    return Container(
      width: size,
      height: size,
      transform: isDiamond ? (Matrix4.identity()..rotateZ(0.785398)) : null,
      decoration: BoxDecoration(
        color: slotColor,
        borderRadius: BorderRadius.circular(
            isSquare ? size * 0.2 : isSoftSquare || isDiamond ? size * 0.4 : 999),
        border: Border.all(
            color: fg.withValues(alpha: filled ? 0.16 : 0.24)),
      ),
      child: Center(
        child: Transform.rotate(
          angle: isDiamond ? -0.785398 : 0,
          child: iconType == 'char'
              ? Text(
                  _stampText(iconValue),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: iconColor,
                    fontWeight: FontWeight.w900,
                    fontSize: size * 0.45,
                  ),
                )
              : Icon(_iconFor(iconValue), color: iconColor, size: size * 0.5),
        ),
      ),
    );
  }
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
