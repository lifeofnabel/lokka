import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

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
    required this.onShopTap,
    required this.onSettingsTap,
    required this.onTodayTap,
  });

  final Map<String, dynamic> merchant;
  final MerchantDashboardMetrics metrics;
  final VoidCallback onShopTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onTodayTap;

  @override
  Widget build(BuildContext context) {
    final shopName = _text('shopName', fallback: 'Dein Geschaeft');
    final logoUrl = _text('logoUrl');
    final coverUrl = _text('coverUrl');
    final status = _text('verificationStatus', fallback: 'pending');
    final areaLine = [_text('area'), _text('shopType')]
        .where((value) => value.isNotEmpty)
        .join(' - ');
    final rating = merchant['averageRating'] ?? merchant['ratingAvg'];
    final scansToday = merchant['scansToday'];
    final isPublic = merchant['isPublic'] == true;
    final isActive = merchant['isActive'] == true;

    return Container(
      constraints: const BoxConstraints(minHeight: 246),
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
                    Colors.black.withOpacity(0.86),
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
                      icon: Icons.storefront_rounded,
                      label: 'Shop ansehen',
                      onTap: onShopTap,
                    ),
                    const Spacer(),
                    _IconGlassButton(
                      icon: Icons.insights_rounded,
                      tooltip: 'Heute',
                      onTap: onTodayTap,
                    ),
                    const SizedBox(width: 8),
                    _SettingsGlassButton(
                      logoUrl: logoUrl,
                      shopName: shopName,
                      onTap: onSettingsTap,
                    ),
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
                            areaLine.isEmpty ? 'Lokaler Partner' : areaLine,
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
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HeroPill(label: _statusLabel(status), strong: status == 'approved'),
                    if (rating != null) _HeroPill(label: 'Rating ${_ratingText(rating)}'),
                    if (scansToday != null) _HeroPill(label: '$scansToday Scans heute'),
                    if (scansToday == null) _HeroPill(label: '${metrics.customers} Kunden'),
                    _HeroPill(label: isActive ? 'Aktiv' : 'Nicht aktiv'),
                    _HeroPill(label: isPublic ? 'Oeffentlich' : 'Privat'),
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
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
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

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label, this.strong = false});

  final String label;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: strong ? AppColors.mint.withOpacity(0.96) : AppColors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.white.withOpacity(0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: strong ? AppColors.black : AppColors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
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

class _SettingsGlassButton extends StatelessWidget {
  const _SettingsGlassButton({
    required this.logoUrl,
    required this.shopName,
    required this.onTap,
  });

  final String logoUrl;
  final String shopName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Funktionen verwalten',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 46,
          height: 42,
          padding: const EdgeInsets.all(4),
          decoration: _glassDecoration(),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(999),
            ),
            clipBehavior: Clip.antiAlias,
            child: logoUrl.isEmpty
                ? Center(
                    child: Text(
                      _initials(shopName),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                  )
                : CachedNetworkImage(imageUrl: logoUrl, fit: BoxFit.cover),
          ),
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

String _statusLabel(String value) {
  return switch (value) {
    'approved' => 'Freigeschaltet',
    'rejected' => 'Abgelehnt',
    'blocked' => 'Gesperrt',
    'paused' => 'Pausiert',
    _ => 'In Pruefung',
  };
}

String _ratingText(dynamic value) {
  if (value is num) return value.toStringAsFixed(1);
  return value.toString();
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
