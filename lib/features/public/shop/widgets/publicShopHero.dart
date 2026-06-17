import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appColors.dart';
import '../../../../core/theme/appSpacing.dart';

class PublicShopHero extends StatelessWidget {
  const PublicShopHero({
    super.key,
    required this.merchant,
    required this.tableLabel,
    required this.darkMode,
    this.footer,
  });

  final Map<String, dynamic> merchant;
  final String tableLabel;
  final bool darkMode;

  /// Optionale Leiste am unteren Cover-Rand (Kontakt/Öffnungszeiten).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final coverUrl = (merchant['coverUrl'] ?? '').toString();
    final logoUrl = (merchant['logoUrl'] ?? '').toString();
    final shopName = (merchant['shopName'] ?? merchant['businessName'] ?? texts.text('public.shop.shop')).toString();
    final description = (merchant['description'] ?? '').toString();
    final meta = [
      (merchant['area'] ?? '').toString(),
      (merchant['shopTypePrimary'] ?? merchant['shopType'] ?? '').toString(),
    ].where((value) => value.trim().isNotEmpty).join(' | ');

    final base = description.trim().isEmpty ? 238.0 : 268.0;
    return Container(
      height: base + (footer != null ? 52 : 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: darkMode ? 0.28 : 0.16),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: coverUrl.isEmpty
                ? const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF282822), Color(0xFF11110F)],
                      ),
                    ),
                  )
                : CachedNetworkImage(imageUrl: coverUrl, fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.16),
                    Colors.black.withValues(alpha: 0.88),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: AppColors.white, width: 2),
                      ),
                      child: logoUrl.isEmpty
                          ? const Icon(Icons.storefront_rounded, color: AppColors.black)
                          : CachedNetworkImage(imageUrl: logoUrl, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            shopName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          if (meta.isNotEmpty) ...[
                            const SizedBox(height: 7),
                            Text(
                              meta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.white.withValues(alpha: 0.74),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (description.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.white.withValues(alpha: 0.68),
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (tableLabel.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _HeroPill(label: texts.text('public.shop.table').replaceAll('{table}', tableLabel)),
                ],
                if (footer != null) ...[
                  const SizedBox(height: 12),
                  footer!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
