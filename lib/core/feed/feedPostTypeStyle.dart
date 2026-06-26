import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/languageService.dart';

/// Visual marker for a feed post's type. ONE source of truth so the badge looks
/// identical on the user feed, the post page, and the merchant manage grid.
/// Theme-neutral (carries its own colour) → renders the same on the light user
/// app and the dark merchant app, and stays readable on top of photos.
class FeedPostTypeStyle {
  const FeedPostTypeStyle({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

/// Maps a post `type` to its marker. Unknown/empty types get a neutral chip
/// (used for legacy posts and `stampAd`).
FeedPostTypeStyle feedPostTypeStyle(String type) {
  switch (type) {
    // ── General posts ──────────────────────────────────────────────────────
    case 'news':
      return const FeedPostTypeStyle(icon: Icons.campaign_rounded, color: Color(0xFF2E7DD1));
    case 'newProduct':
      return const FeedPostTypeStyle(icon: Icons.fiber_new_rounded, color: Color(0xFF2E9E5B));
    case 'info': // presented as "Warnung"
      return const FeedPostTypeStyle(icon: Icons.warning_amber_rounded, color: Color(0xFFE8902A));
    case 'communityEvent':
      return const FeedPostTypeStyle(icon: Icons.celebration_rounded, color: Color(0xFF8E5BD9));
    case 'hiring':
      return const FeedPostTypeStyle(icon: Icons.group_add_rounded, color: Color(0xFF1FA9A0));
    // ── Actions ────────────────────────────────────────────────────────────
    case 'offer':
      return const FeedPostTypeStyle(icon: Icons.local_offer_rounded, color: Color(0xFFE8762A));
    case 'categoryDiscountPercent':
      return const FeedPostTypeStyle(icon: Icons.percent_rounded, color: Color(0xFFD64545));
    case 'happyHour':
      return const FeedPostTypeStyle(icon: Icons.local_bar_rounded, color: Color(0xFFD94F8E));
    case 'onePlusOneFree':
      return const FeedPostTypeStyle(icon: Icons.exposure_plus_1_rounded, color: Color(0xFF5B6BD9));
    case 'twoPlusOneFree':
      return const FeedPostTypeStyle(icon: Icons.filter_3_rounded, color: Color(0xFF4D58C9));
    case 'rescueMe':
      return const FeedPostTypeStyle(icon: Icons.volunteer_activism_rounded, color: Color(0xFF3FA45C));
    case 'stampAd':
      return const FeedPostTypeStyle(icon: Icons.card_giftcard_rounded, color: Color(0xFF2FB389));
    default:
      return const FeedPostTypeStyle(icon: Icons.push_pin_rounded, color: Color(0xFF6B7280));
  }
}

/// Localised label for a type (reuses the existing `feed.type.*` keys).
String feedPostTypeLabel(LanguageService texts, String type) {
  if (type.isEmpty) return texts.text('merchant.feedManage.post');
  final label = texts.text('feed.type.$type');
  // LanguageService returns the key itself when missing → fall back to a generic.
  return label == 'feed.type.$type' ? texts.text('merchant.feedManage.post') : label;
}

/// The solid colour pill shown on cards/tiles. [onImage] uses white text/icon
/// (for photo backgrounds); otherwise a soft tinted chip with coloured text.
class FeedTypeBadge extends StatelessWidget {
  const FeedTypeBadge({
    super.key,
    required this.type,
    this.onImage = false,
    this.compact = false,
  });

  final String type;
  final bool onImage;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final style = feedPostTypeStyle(type);
    final label = feedPostTypeLabel(texts, type);
    final fg = onImage ? Colors.white : style.color;
    final bg = onImage ? style.color : style.color.withValues(alpha: 0.14);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 4 : 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: onImage ? null : Border.all(color: style.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: compact ? 13 : 15, color: fg),
          SizedBox(width: compact ? 4 : 5),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: compact ? 11 : 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
