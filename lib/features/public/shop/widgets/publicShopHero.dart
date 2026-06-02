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
  });

  final Map<String, dynamic> merchant;
  final String tableLabel;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final coverUrl = (merchant['coverUrl'] ?? '').toString();
    final logoUrl = (merchant['logoUrl'] ?? '').toString();
    final shopName = (merchant['shopName'] ?? merchant['businessName'] ?? texts.text('public.shop.shop')).toString();
    final meta = [
      (merchant['area'] ?? '').toString(),
      (merchant['shopType'] ?? merchant['shopTypePrimary'] ?? '').toString(),
    ].where((value) => value.trim().isNotEmpty).join(' · ');

    return Container(
      height: 230,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: coverUrl.isEmpty
                ? const DecoratedBox(
                    decoration: BoxDecoration(color: AppColors.black),
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
                    Colors.black.withOpacity(0.18),
                    Colors.black.withOpacity(0.72),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: 66,
                  height: 66,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(26),
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
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.white.withOpacity(0.72),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      if (tableLabel.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _HeroPill(label: texts.text('public.shop.table').replaceAll('{table}', tableLabel)),
                      ],
                    ],
                  ),
                ),
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
        color: AppColors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.white.withOpacity(0.16)),
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
