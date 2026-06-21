import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appColors.dart';
import '../utils/feedFormatters.dart';

/// User-Feed-Vorschau einer geplanten Merchant-Aktion/Beitrags. Bewusst im
/// HELLEN User-Look (AppColors), da sie zeigt, wie der Post in der User-Discover-
/// Liste erscheint. Aus merchantFeedCreatePage.dart ausgelagert (#16).

class MerchantFeedPostPreview extends StatelessWidget {
  const MerchantFeedPostPreview({
    super.key,
    required this.type,
    required this.merchantName,
    required this.merchantLogoUrl,
    required this.merchantCity,
    required this.merchantShopType,
    required this.ratingText,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.oldPrice,
    required this.newPrice,
  });

  final String type;
  final String merchantName;
  final String merchantLogoUrl;
  final String merchantCity;
  final String merchantShopType;
  final String ratingText;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String oldPrice;
  final String newPrice;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final visibleTitle = title.trim().isEmpty ? texts.text('merchant.feedCreate.previewTitle') : title.trim();
    final visibleSubtitle = subtitle.trim().isEmpty ? texts.text('merchant.feedCreate.previewSubtitle') : subtitle.trim();
    final shopName = merchantName.trim().isEmpty ? texts.text('merchant.feedCreate.previewShopName') : merchantName.trim();
    final meta = [merchantCity, merchantShopType].where((value) => value.trim().isNotEmpty).join(' · ');
    final discount = feedDiscountLabel(oldPrice, newPrice, texts);
    // Die Vorschau zeigt, was USER sehen → bewusst helle Karte (1:1 wie
    // _FeedCard in userDiscoverPage.dart), auch im dunklen Merchant-Theme.
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Schlanker Header (wie User-Feedkarte)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
            child: Row(
              children: [
                _PreviewAvatar(
                  logoUrl: merchantLogoUrl,
                  fallback: shopName,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shopName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.onSurfaceDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (meta.isNotEmpty)
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.onSurfaceMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: texts.text('merchant.feedCreate.previewMenu'),
                  onSelected: (_) {},
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'share', child: Text(texts.text('feed.menu.share'))),
                    PopupMenuItem(value: 'why', child: Text(texts.text('feed.menu.why'))),
                    PopupMenuItem(value: 'report', child: Text(texts.text('feed.menu.report'))),
                  ],
                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.onSurfaceMuted),
                ),
              ],
            ),
          ),
          // Bild-Hero mit Titel-Overlay auf Scrim (wie User-Feedkarte)
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1.1,
                child: imageUrl.isEmpty
                    ? Container(
                        color: AppColors.gray100,
                        child: const Icon(
                          Icons.image_rounded,
                          size: 44,
                          color: AppColors.gray500,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(color: AppColors.gray100),
                        errorWidget: (_, _, _) => Container(color: AppColors.gray100),
                      ),
              ),
              // Dunkler Verlauf unten, damit der Titel lesbar bleibt.
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.55),
                        ],
                        stops: const [0.5, 1],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: _PreviewBadge(label: texts.text('feed.type.$type')),
              ),
              if (discount.isNotEmpty)
                Positioned(
                  top: 12,
                  right: 12,
                  child: _PreviewBadge(
                    label: discount,
                    background: AppColors.googleRed,
                  ),
                ),
              // Titel + Untertitel unten links auf dem Bild.
              Positioned(
                left: 16,
                right: 60,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      visibleTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        height: 1.15,
                      ),
                    ),
                    if (visibleSubtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        visibleSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.87),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Herz unten rechts – optisch wie der Like-Button der User-Karte.
              Positioned(
                right: 16,
                bottom: 16,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.92),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_border_rounded,
                    color: AppColors.onSurfaceDark,
                  ),
                ),
              ),
            ],
          ),
          // Eine ruhige Meta-Zeile (wie User-Feedkarte)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: [
                if (ratingText.trim().isNotEmpty) ...[
                  const Icon(Icons.star_rounded,
                      size: 18, color: AppColors.googleYellow),
                  const SizedBox(width: 4),
                  Text(
                    ratingText.trim(),
                    style: const TextStyle(
                      color: AppColors.onSurfaceDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else
                  Text(
                    texts.text('discover.new'),
                    style: const TextStyle(
                      color: AppColors.onSurfaceMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.onSurfaceMuted, size: 22),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewBadge extends StatelessWidget {
  const _PreviewBadge({
    required this.label,
    this.background,
  });

  final String label;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background ?? Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PreviewAvatar extends StatelessWidget {
  const _PreviewAvatar({
    required this.logoUrl,
    required this.fallback,
  });

  final String logoUrl;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    // Heller, runder Avatar – wie das Logo der User-Feedkarte.
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: AppColors.mintSoft,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: logoUrl.trim().isEmpty
          ? Center(
              child: Text(
                feedInitials(fallback),
                style: const TextStyle(
                  color: AppColors.greenDeep,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : CachedNetworkImage(imageUrl: logoUrl, fit: BoxFit.cover),
    );
  }
}
