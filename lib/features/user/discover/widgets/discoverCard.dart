import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appShadows.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/discover/models/publicMerchantUserModel.dart';

class DiscoverCard extends StatelessWidget {
  const DiscoverCard({
    super.key,
    required this.merchant,
    this.onTap,
  });

  final PublicMerchantUserModel merchant;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.large),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.large),
              ),
              child: merchant.coverUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: merchant.coverUrl,
                      height: 90,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _placeholder(),
                      errorWidget: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (merchant.logoUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: CachedNetworkImage(
                            imageUrl: merchant.logoUrl,
                            width: 24,
                            height: 24,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _logoFallback(),
                          ),
                        )
                      else
                        _logoFallback(),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          merchant.shopName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurfaceDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (merchant.area.isNotEmpty)
                    Text(
                      merchant.area,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.gray500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      height: 90,
      width: double.infinity,
      color: AppColors.mintSoft,
      child: const Icon(Icons.store_rounded, color: AppColors.mintStrong, size: 28),
    );
  }

  Widget _logoFallback() {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        color: AppColors.mintSoft,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.store_rounded, size: 12, color: AppColors.mintStrong),
    );
  }
}
