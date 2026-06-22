import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lokka/core/utils/locationUtils.dart';
import 'package:lokka/features/user/discover/models/publicMerchantUserModel.dart';
import 'package:lokka/features/user/reviews/models/merchantRating.dart';
import 'package:lokka/features/user/reviews/widgets/reviewWidgets.dart';

// ── Horizontal compact card (Netflix-style row) ───────────────────────────────

class PartnerHorizontalCard extends StatelessWidget {
  const PartnerHorizontalCard({
    super.key,
    required this.merchant,
    required this.inWallet,
    this.rating,
    this.onTap,
    this.onWalletTap,
  });

  final PublicMerchantUserModel merchant;
  final bool inWallet;
  final MerchantRating? rating;
  final VoidCallback? onTap;
  final VoidCallback? onWalletTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          width: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image hero with logo + floating wallet
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1.3,
                    child: merchant.coverUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: merchant.coverUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => _coverPlaceholder(context),
                            errorWidget: (_, __, ___) =>
                                _coverPlaceholder(context),
                          )
                        : _coverPlaceholder(context),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: merchant.logoUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: merchant.logoUrl,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Icon(
                                  Icons.storefront_rounded,
                                  size: 16,
                                  color: cs.onSecondaryContainer,
                                ),
                              )
                            : Icon(
                                Icons.storefront_rounded,
                                size: 16,
                                color: cs.onSecondaryContainer,
                              ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _WalletButton(inWallet: inWallet, onTap: onWalletTap),
                  ),
                ],
              ),
              // Minimal footer: name + one quiet meta row
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      merchant.shopName,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    _MetaRow(merchant: merchant, rating: rating),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _coverPlaceholder(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.secondaryContainer,
      child: Center(
        child: Icon(Icons.storefront_rounded,
            color: cs.onSecondaryContainer, size: 32),
      ),
    );
  }
}

/// One quiet meta line: rating if present, otherwise area · type.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.merchant, this.rating});

  final PublicMerchantUserModel merchant;
  final MerchantRating? rating;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (rating != null && rating!.hasRatings) {
      return ReviewStars(rating: rating!.avg, count: rating!.count, size: 13);
    }

    final meta = [merchant.area, merchant.shopType]
        .where((s) => s.isNotEmpty)
        .join(' · ');
    if (meta.isEmpty) return const SizedBox.shrink();
    return Text(
      meta,
      style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Floating circular wallet action over the image hero.
class _WalletButton extends StatelessWidget {
  const _WalletButton({required this.inWallet, this.onTap});

  final bool inWallet;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = inWallet ? cs.secondaryContainer : cs.surface;
    final fg = inWallet ? cs.onSecondaryContainer : cs.primary;
    return Material(
      color: bg,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            inWallet ? Icons.check_rounded : Icons.add_rounded,
            size: 20,
            color: fg,
          ),
        ),
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
    this.distanceKm,
  });

  final PublicMerchantUserModel merchant;
  final VoidCallback? onTap;

  /// Optionale Entfernung (km) → Distanz-Pille auf dem Cover (für „Näheste").
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1.6,
                    child: merchant.coverUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: merchant.coverUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => _coverPlaceholder(context),
                            errorWidget: (_, __, ___) =>
                                _coverPlaceholder(context),
                          )
                        : _coverPlaceholder(context),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: merchant.logoUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: merchant.logoUrl,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) =>
                                    _logoFallback(context),
                              )
                            : _logoFallback(context),
                      ),
                    ),
                  ),
                  if (distanceKm != null)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.near_me_rounded,
                                size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              LocationUtils.distanceLabel(distanceKm!),
                              style: tt.labelMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      merchant.shopName,
                      style: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (merchant.shopType.isNotEmpty ||
                        merchant.area.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        [merchant.area, merchant.shopType]
                            .where((s) => s.isNotEmpty)
                            .join(' · '),
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _coverPlaceholder(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.secondaryContainer,
      child: Center(
        child: Icon(Icons.storefront_rounded,
            color: cs.onSecondaryContainer, size: 36),
      ),
    );
  }

  Widget _logoFallback(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.secondaryContainer,
      child: Icon(Icons.storefront_rounded,
          size: 22, color: cs.onSecondaryContainer),
    );
  }
}
