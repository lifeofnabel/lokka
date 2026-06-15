import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/discover/models/publicMerchantUserModel.dart';

/// Ruhiger M3-Hero für die Partner-Detailseite:
/// Cover, Logo, Name, Typ/Gebiet als Chips, optionale Beschreibung.
class PartnerHeroCard extends StatelessWidget {
  const PartnerHeroCard({
    super.key,
    required this.merchant,
  });

  final PublicMerchantUserModel merchant;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            _buildCover(context),
            Positioned(
              bottom: -28,
              left: AppSpacing.md,
              child: _buildLogo(context),
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
                style: tt.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: cs.onSurface,
                ),
              ),
              if (merchant.shopType.isNotEmpty || merchant.area.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (merchant.shopType.isNotEmpty)
                      _Tag(merchant.shopType, primary: true),
                    if (merchant.area.isNotEmpty)
                      _Tag(merchant.area, icon: Icons.place_outlined),
                  ],
                ),
              ],
              if (merchant.description.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  merchant.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
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

  Widget _buildCover(BuildContext context) {
    return merchant.coverUrl.isNotEmpty
        ? CachedNetworkImage(
            imageUrl: merchant.coverUrl,
            height: 248,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (_, __) => _coverPlaceholder(context),
            errorWidget: (_, __, ___) => _coverPlaceholder(context),
          )
        : _coverPlaceholder(context);
  }

  Widget _coverPlaceholder(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 248,
      color: cs.secondaryContainer,
      child: Center(
        child: Icon(Icons.storefront_rounded,
            size: 56, color: cs.onSecondaryContainer),
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.surfaceBg, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: merchant.logoUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: merchant.logoUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _logoFallback(context),
              )
            : _logoFallback(context),
      ),
    );
  }

  Widget _logoFallback(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.secondaryContainer,
      child: Icon(Icons.storefront_rounded,
          size: 30, color: cs.onSecondaryContainer),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, {this.primary = false, this.icon});

  final String label;
  final bool primary;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fg = primary ? cs.onSecondaryContainer : cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: primary ? cs.secondaryContainer : AppColors.surfaceGray,
        borderRadius: BorderRadius.circular(100),
        border: primary ? null : Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: tt.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
