import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appShadows.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/discover/models/publicMerchantUserModel.dart';

class PartnerCard extends StatelessWidget {
  const PartnerCard({
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
                      height: 110,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _coverPlaceholder(),
                      errorWidget: (_, __, ___) => _coverPlaceholder(),
                    )
                  : _coverPlaceholder(),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.mintSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: merchant.logoUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: merchant.logoUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _logoFallback(),
                            )
                          : _logoFallback(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          merchant.shopName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (merchant.shopType.isNotEmpty) ...[
                              _Tag(merchant.shopType),
                              const SizedBox(width: 6),
                            ],
                            if (merchant.area.isNotEmpty)
                              _Tag(merchant.area, muted: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.gray300,
                    size: 20,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverPlaceholder() {
    return Container(
      height: 110,
      color: AppColors.mintSoft,
      child: const Center(
        child: Icon(Icons.store_rounded, color: AppColors.mintStrong, size: 36),
      ),
    );
  }

  Widget _logoFallback() {
    return const Icon(Icons.store_rounded, size: 20, color: AppColors.mintStrong);
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, {this.muted = false});

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: muted ? AppColors.gray50 : AppColors.mintSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: muted ? AppColors.gray500 : AppColors.mintStrong,
        ),
      ),
    );
  }
}
