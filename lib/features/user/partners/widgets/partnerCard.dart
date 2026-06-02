import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appShadows.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/discover/models/publicMerchantUserModel.dart';

// ── Horizontal compact card (Netflix-style row) ───────────────────────────────

class PartnerHorizontalCard extends StatelessWidget {
  const PartnerHorizontalCard({
    super.key,
    required this.merchant,
    required this.inWallet,
    this.onTap,
    this.onWalletTap,
  });

  final PublicMerchantUserModel merchant;
  final bool inWallet;
  final VoidCallback? onTap;
  final VoidCallback? onWalletTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.large),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.large),
              ),
              child: Stack(
                children: [
                  merchant.coverUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: merchant.coverUrl,
                          height: 90,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _coverPlaceholder(),
                          errorWidget: (_, __, ___) => _coverPlaceholder(),
                        )
                      : _coverPlaceholder(),
                  // Logo badge bottom-left
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: merchant.logoUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: merchant.logoUrl,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => const Icon(
                                  Icons.store_rounded,
                                  size: 14,
                                  color: AppColors.mintStrong,
                                ),
                              )
                            : const Icon(
                                Icons.store_rounded,
                                size: 14,
                                color: AppColors.mintStrong,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    merchant.shopName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (merchant.area.isNotEmpty || merchant.shopType.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      [merchant.shopType, merchant.area]
                          .where((s) => s.isNotEmpty)
                          .join(' · '),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.gray500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  // Feature icons
                  if (merchant.featuresPublic.isNotEmpty)
                    _FeatureIcons(features: merchant.featuresPublic),
                  const SizedBox(height: 6),
                  // Wallet button
                  GestureDetector(
                    onTap: onWalletTap,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: inWallet
                            ? AppColors.mintSoft
                            : AppColors.mintStrong,
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            inWallet
                                ? Icons.check_rounded
                                : Icons.add_rounded,
                            size: 13,
                            color: inWallet
                                ? AppColors.mintStrong
                                : Colors.white,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            inWallet ? 'In Wallet' : 'Wallet',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: inWallet
                                  ? AppColors.mintStrong
                                  : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
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
      height: 90,
      color: AppColors.mintSoft,
      child: const Center(
        child: Icon(Icons.store_rounded, color: AppColors.mintStrong, size: 28),
      ),
    );
  }
}

// ── Full-width list card ──────────────────────────────────────────────────────

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

// ── Feature icons ─────────────────────────────────────────────────────────────

class _FeatureIcons extends StatelessWidget {
  const _FeatureIcons({required this.features});

  final List<String> features;

  static const _iconMap = <String, IconData>{
    'stamps': Icons.loyalty_rounded,
    'stampCards': Icons.loyalty_rounded,
    'points': Icons.stars_rounded,
    'coupons': Icons.confirmation_num_rounded,
    'orders': Icons.shopping_bag_rounded,
    'delivery': Icons.delivery_dining_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final icons = features
        .map((f) => _iconMap[f])
        .whereType<IconData>()
        .take(4)
        .toList();
    if (icons.isEmpty) return const SizedBox.shrink();
    return Row(
      children: icons
          .map((i) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(i, size: 13, color: AppColors.mintStrong),
              ))
          .toList(),
    );
  }
}

// ── Tag chip ─────────────────────────────────────────────────────────────────

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
