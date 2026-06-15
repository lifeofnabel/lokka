import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/wallet/models/walletCardModel.dart';

/// Calm wallet card (Google Home tone): brand + ONE quiet status line.
/// Whole card is one tap target that opens the detail page. Big radius,
/// generous padding, no raw code dump on the list card.
class WalletCard extends StatelessWidget {
  const WalletCard({
    super.key,
    required this.card,
    this.onTap,
  });

  final WalletCardModel card;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: AppColors.surfaceBg,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: cs.outlineVariant),
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              _buildLogo(cs),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.merchantName,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    _StatusLine(card: card),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurfaceVariant,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(ColorScheme cs) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: card.merchantLogoUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: card.merchantLogoUrl,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => _logoFallback(cs),
              )
            : _logoFallback(cs),
      ),
    );
  }

  Widget _logoFallback(ColorScheme cs) {
    return Icon(Icons.store_rounded, size: 26, color: cs.onSecondaryContainer);
  }
}

/// One quiet meta line: location/type when present, otherwise the active
/// perks (Stempel · Punkte · Coupons). Never renders empty.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.card});

  final WalletCardModel card;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final place = [card.merchantShopType, card.merchantArea]
        .where((s) => s.isNotEmpty)
        .join(' · ');

    final perks = <String>[
      if (card.hasStampCards) 'Stempel',
      if (card.hasPoints) 'Punkte',
      if (card.hasCoupons) 'Coupons',
    ];

    final label = place.isNotEmpty
        ? place
        : (perks.isNotEmpty ? perks.join(' · ') : 'Wallet-Karte');

    return Text(
      label,
      style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
