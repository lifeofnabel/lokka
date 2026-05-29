import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/wallet/models/walletCardModel.dart';

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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 190,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _cardColor(card.merchantShopType),
              _cardColorEnd(card.merchantShopType),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: _cardColor(card.merchantShopType).withOpacity(0.4),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            _buildPattern(),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildLogo(),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              card.merchantName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (card.merchantShopType.isNotEmpty ||
                                card.merchantArea.isNotEmpty)
                              Text(
                                [card.merchantShopType, card.merchantArea]
                                    .where((s) => s.isNotEmpty)
                                    .join(' · '),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white60,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    card.walletCode,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      _StatusDot(active: card.hasStampCards, icon: Icons.loyalty_rounded, label: 'Stempel'),
                      const SizedBox(width: AppSpacing.sm),
                      _StatusDot(active: card.hasPoints, icon: Icons.stars_rounded, label: 'Punkte'),
                      const SizedBox(width: AppSpacing.sm),
                      _StatusDot(active: card.hasCoupons, icon: Icons.local_offer_rounded, label: 'Coupons'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(color: Colors.white24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.small - 1),
        child: card.merchantLogoUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: card.merchantLogoUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _logoFallback(),
              )
            : _logoFallback(),
      ),
    );
  }

  Widget _logoFallback() {
    return Container(
      color: Colors.white.withOpacity(0.1),
      child: const Icon(Icons.store_rounded, size: 22, color: Colors.white70),
    );
  }

  Widget _buildPattern() {
    return Positioned(
      right: -30,
      top: -30,
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.05),
        ),
      ),
    );
  }

  Color _cardColor(String shopType) {
    const map = {
      'Food': Color(0xFF1A2B3C),
      'Café': Color(0xFF2C1A0E),
      'Kiosk': Color(0xFF0E2C1A),
      'Beauty': Color(0xFF2C0E2C),
      'Fitness': Color(0xFF0E1A2C),
      'Bakery': Color(0xFF2C2010),
      'Drinks': Color(0xFF1A0E2C),
    };
    return map[shopType] ?? const Color(0xFF171A18);
  }

  Color _cardColorEnd(String shopType) {
    const map = {
      'Food': Color(0xFF2E4A64),
      'Café': Color(0xFF4A2E18),
      'Kiosk': Color(0xFF184A2E),
      'Beauty': Color(0xFF4A184A),
      'Fitness': Color(0xFF182E4A),
      'Bakery': Color(0xFF4A3620),
      'Drinks': Color(0xFF2E184A),
    };
    return map[shopType] ?? const Color(0xFF2A2D2A);
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({
    required this.active,
    required this.icon,
    required this.label,
  });

  final bool active;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? Colors.white38 : Colors.white12,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: active ? Colors.white : Colors.white30,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : Colors.white30,
            ),
          ),
        ],
      ),
    );
  }
}
