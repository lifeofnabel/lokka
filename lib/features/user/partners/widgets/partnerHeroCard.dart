import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/discover/models/publicMerchantUserModel.dart';

class PartnerHeroCard extends StatelessWidget {
  const PartnerHeroCard({
    super.key,
    required this.merchant,
  });

  final PublicMerchantUserModel merchant;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            _buildCover(),
            Positioned(
              bottom: -28,
              left: AppSpacing.md,
              child: _buildLogo(),
            ),
          ],
        ),
        const SizedBox(height: 36),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                merchant.shopName,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.black,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (merchant.shopType.isNotEmpty)
                    _Tag(merchant.shopType, primary: true),
                  if (merchant.area.isNotEmpty)
                    _Tag(merchant.area),
                ],
              ),
              if (merchant.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  merchant.description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.gray700,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCover() {
    return merchant.coverUrl.isNotEmpty
        ? CachedNetworkImage(
            imageUrl: merchant.coverUrl,
            height: 220,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (_, __) => _coverPlaceholder(),
            errorWidget: (_, __, ___) => _coverPlaceholder(),
          )
        : _coverPlaceholder();
  }

  Widget _coverPlaceholder() {
    return Container(
      height: 220,
      color: AppColors.mintSoft,
      child: const Center(
        child: Icon(Icons.store_rounded, size: 56, color: AppColors.mintStrong),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.medium - 3),
        child: merchant.logoUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: merchant.logoUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _logoFallback(),
              )
            : _logoFallback(),
      ),
    );
  }

  Widget _logoFallback() {
    return Container(
      color: AppColors.mintSoft,
      child: const Icon(Icons.store_rounded, size: 28, color: AppColors.mintStrong),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, {this.primary = false});

  final String label;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: primary ? AppColors.mintSoft : AppColors.gray50,
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: primary ? AppColors.mintStrong : AppColors.gray700,
        ),
      ),
    );
  }
}
