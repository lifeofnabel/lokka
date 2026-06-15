import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../services/merchantDashboardService.dart';

class MerchantHeroCard extends StatelessWidget {
  const MerchantHeroCard({
    super.key,
    required this.merchant,
    required this.metrics,
    required this.onShopTap,
    required this.onCustomersTap,
    required this.onSettingsTap,
    required this.onTodayTap,
  });

  final Map<String, dynamic> merchant;
  final MerchantDashboardMetrics metrics;
  final VoidCallback onShopTap;
  final VoidCallback onCustomersTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onTodayTap;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final shopName = _text('shopName', fallback: texts.text('merchant.dashboard.yourShop'));
    final logoUrl = _text('logoUrl');
    final coverUrl = _text('coverUrl');
    final shopTypes = merchant['shopTypes'];
    final typeLine = shopTypes is Iterable
        ? shopTypes.map((item) => item.toString()).where((item) => item.isNotEmpty).join(', ')
        : _text('shopType');
    final areaLine = [_text('area'), typeLine].where((value) => value.isNotEmpty).join(' | ');

    return Container(
      constraints: const BoxConstraints(minHeight: 284),
      decoration: BoxDecoration(
        color: MerchantPremiumColors.baseElevated,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: MerchantPremiumShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: coverUrl.isEmpty
                ? const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          MerchantPremiumColors.baseSoft,
                          MerchantPremiumColors.base,
                        ],
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
                    Colors.black.withValues(alpha: 0.10),
                    Colors.black.withValues(alpha: 0.72),
                    Colors.black.withValues(alpha: 0.94),
                  ],
                  stops: const [0, 0.48, 1],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _GlassButton(
                      icon: Icons.remove_red_eye_rounded,
                      label: texts.text('merchant.dashboard.shopPreview'),
                      onTap: onShopTap,
                    ),
                    const Spacer(),
                    _IconGlassButton(icon: Icons.insights_rounded, tooltip: texts.text('merchant.dashboard.today'), onTap: onTodayTap),
                    const SizedBox(width: 8),
                    _IconGlassButton(icon: Icons.tune_rounded, tooltip: 'Shopdaten', onTap: onSettingsTap),
                  ],
                ),
                const SizedBox(height: 50),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _Logo(logoUrl: logoUrl, shopName: shopName),
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
                              color: Colors.white,
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            areaLine.isEmpty ? texts.text('merchant.dashboard.localPartner') : areaLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: MerchantPremiumColors.mutedLight,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _HeroMetric(
                        label: texts.text('merchant.customers.title'),
                        value: metrics.customers.toString(),
                        icon: Icons.groups_rounded,
                        onTap: onCustomersTap,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeroMetric(
                        label: texts.text('merchant.dashboard.feedHub'),
                        value: metrics.feedPosts.toString(),
                        icon: Icons.campaign_rounded,
                        onTap: onSettingsTap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _text(String key, {String fallback = ''}) => merchant[key]?.toString() ?? fallback;
}

class _Logo extends StatelessWidget {
  const _Logo({required this.logoUrl, required this.shopName});

  final String logoUrl;
  final String shopName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        color: MerchantPremiumColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MerchantPremiumColors.gold.withValues(alpha: 0.40), width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: logoUrl.isEmpty
          ? Center(
              child: Text(
                _initials(shopName),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            )
          : CachedNetworkImage(imageUrl: logoUrl, fit: BoxFit.cover),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: MerchantPremiumColors.gold.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: [
            Icon(icon, color: MerchantPremiumColors.gold, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, height: 1)),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: const TextStyle(
                      color: MerchantPremiumColors.mutedLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
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
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: _glassDecoration(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 17),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconGlassButton extends StatelessWidget {
  const _IconGlassButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 42,
          height: 42,
          decoration: _glassDecoration(),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

BoxDecoration _glassDecoration() {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: 0.12),
    borderRadius: BorderRadius.circular(999),
    border: Border.all(color: MerchantPremiumColors.gold.withValues(alpha: 0.28)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.10),
        blurRadius: 14,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return 'L';
  if (parts.length == 1) {
    final end = parts.first.length < 2 ? parts.first.length : 2;
    return parts.first.substring(0, end).toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}
