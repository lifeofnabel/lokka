import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appColors.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appShadows.dart';
import '../../../../core/theme/appSpacing.dart';
import '../services/merchantDashboardService.dart';

class MerchantHeroCard extends StatelessWidget {
  const MerchantHeroCard({
    super.key,
    required this.merchant,
    required this.metrics,
    required this.weekCredits,
    required this.hasBillingData,
    required this.onShopTap,
    required this.onEditTap,
    required this.onBillingTap,
    required this.onCustomersTap,
    required this.onSettingsTap,
    required this.onTodayTap,
  });

  final Map<String, dynamic> merchant;
  final MerchantDashboardMetrics metrics;
  final int weekCredits;
  final bool hasBillingData;
  final VoidCallback onShopTap;
  final VoidCallback onEditTap;
  final VoidCallback onBillingTap;
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
        color: AppColors.black,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        boxShadow: AppShadows.card,
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
                        colors: [Color(0xFF252A26), Color(0xFF111312)],
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
                    Colors.black.withOpacity(0.14),
                    Colors.black.withOpacity(0.9),
                  ],
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
                    _IconGlassButton(icon: Icons.tune_rounded, tooltip: texts.text('merchant.features.title'), onTap: onSettingsTap),
                  ],
                ),
                const SizedBox(height: 56),
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
                              color: AppColors.white,
                              fontSize: 26,
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
                              color: Color(0xFFE3E9E1),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _EditButton(onTap: onEditTap),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _HeroMetric(
                        label: texts.text('merchant.dashboard.credits'),
                        value: hasBillingData ? weekCredits.toString() : '0',
                        icon: Icons.credit_score_rounded,
                        onTap: onBillingTap,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeroMetric(
                        label: texts.text('merchant.customers.title'),
                        value: metrics.customers.toString(),
                        icon: Icons.groups_rounded,
                        onTap: onCustomersTap,
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
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.white.withOpacity(0.9), width: 3),
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
          color: AppColors.white.withOpacity(0.13),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.white.withOpacity(0.18)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.mint, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.w900, height: 1)),
                  const SizedBox(height: 3),
                  Text(label, style: const TextStyle(color: Color(0xFFDDE4DE), fontSize: 12, fontWeight: FontWeight.w800)),
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
            Icon(icon, color: AppColors.white, size: 17),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.white,
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

class _EditButton extends StatelessWidget {
  const _EditButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return FilledButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.edit_rounded, size: 16),
      label: Text(texts.text('common.edit')),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.black,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
          child: Icon(icon, color: AppColors.white, size: 20),
        ),
      ),
    );
  }
}

BoxDecoration _glassDecoration() {
  return BoxDecoration(
    color: AppColors.white.withOpacity(0.14),
    borderRadius: BorderRadius.circular(999),
    border: Border.all(color: AppColors.white.withOpacity(0.22)),
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
