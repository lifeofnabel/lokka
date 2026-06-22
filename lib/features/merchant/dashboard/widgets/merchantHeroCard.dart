import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../services/merchantDashboardService.dart';

class MerchantHeroCard extends StatefulWidget {
  const MerchantHeroCard({
    super.key,
    required this.hero,
    required this.metrics,
    required this.onShopTap,
    required this.onCustomersTap,
    required this.onSettingsTap,
    required this.onFeedTap,
    required this.onTodayTap,
    required this.onSaveFocus,
  });

  final MerchantHeroFields hero;
  final MerchantDashboardMetrics metrics;
  final VoidCallback onShopTap;
  final VoidCallback onCustomersTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onFeedTap;
  final VoidCallback onTodayTap;

  /// Speichert den neuen vertikalen Cover-Fokus (0..1).
  final ValueChanged<double> onSaveFocus;

  @override
  State<MerchantHeroCard> createState() => _MerchantHeroCardState();
}

class _MerchantHeroCardState extends State<MerchantHeroCard> {
  bool _repositioning = false;
  late double _focusY = widget.hero.coverFocusY;
  double _cardHeight = 284;

  @override
  void didUpdateWidget(MerchantHeroCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Externe Updates (z.B. neues Cover) übernehmen, solange nicht aktiv gezogen.
    if (!_repositioning && oldWidget.hero.coverFocusY != widget.hero.coverFocusY) {
      _focusY = widget.hero.coverFocusY;
    }
  }

  void _onDrag(DragUpdateDetails details) {
    setState(() {
      // Nach oben ziehen zeigt tieferen Bildausschnitt -> Fokus nach unten.
      _focusY = (_focusY - details.delta.dy / _cardHeight).clamp(0.0, 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hero = widget.hero;
    final metrics = widget.metrics;
    final texts = context.watch<LanguageService>();
    final shopName =
        hero.shopName.isEmpty ? texts.text('merchant.dashboard.yourShop') : hero.shopName;
    final subtitle = [hero.city, hero.typeLine]
        .where((value) => value.isNotEmpty)
        .join(' | ');
    final hasCover = hero.coverUrl.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          // Beim Positionieren wird der Inhalts-Block (der einzige NICHT-
          // positionierte Stack-Child, der die Höhe vorgibt) ausgeblendet. Ohne
          // feste Höhe hätte der Stack dann nur Positioned.fill-Kinder und keine
          // Größe mehr → Layout-Assertions (stack.dart/box.dart). Darum hier die
          // zuletzt gemessene Karten-Höhe fixieren, solange positioniert wird.
          height: _repositioning ? _cardHeight : null,
          constraints: const BoxConstraints(minHeight: 284),
          decoration: BoxDecoration(
            color: MerchantPremiumColors.baseElevated,
            borderRadius: BorderRadius.circular(AppRadius.xxl),
            border: Border.all(
              color: _repositioning
                  ? MerchantPremiumColors.gold
                  : MerchantPremiumColors.glassBorder,
            ),
            boxShadow: MerchantPremiumShadows.card,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, c) {
                    _cardHeight = c.maxHeight.isFinite ? c.maxHeight : _cardHeight;
                    return hero.coverUrl.isEmpty
                        ? const _CoverFallback()
                        : CachedNetworkImage(
                            imageUrl: hero.coverUrl,
                            fit: BoxFit.cover,
                            alignment: Alignment(0, _focusY * 2 - 1),
                            memCacheWidth: 1080,
                            maxWidthDiskCache: 1080,
                            placeholder: (_, _) => const _CoverFallback(),
                            errorWidget: (_, _, _) => const _CoverFallback(),
                          );
                  },
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    // Bild-Scrim: bewusste Ausnahme – schwarzer Verlauf für
                    // Textlesbarkeit über beliebigen Cover-Bildern. Beim
                    // Positionieren abgeschwächt, damit man das Bild sieht.
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: _repositioning
                          ? [
                              Colors.black.withValues(alpha: 0.10),
                              Colors.black.withValues(alpha: 0.20),
                              Colors.black.withValues(alpha: 0.35),
                            ]
                          : [
                              Colors.black.withValues(alpha: 0.10),
                              Colors.black.withValues(alpha: 0.72),
                              Colors.black.withValues(alpha: 0.94),
                            ],
                      stops: const [0, 0.48, 1],
                    ),
                  ),
                ),
              ),
              if (_repositioning)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: _onDrag,
                    child: _RepositionOverlay(
                      hint: texts.text('merchant.dashboard.repositionHint'),
                      saveLabel: texts.text('common.save'),
                      cancelLabel: texts.text('common.cancel'),
                      onSave: () {
                        widget.onSaveFocus(_focusY);
                        setState(() => _repositioning = false);
                      },
                      onCancel: () => setState(() {
                        _focusY = hero.coverFocusY;
                        _repositioning = false;
                      }),
                    ),
                  ),
                ),
              if (!_repositioning)
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
                            onTap: widget.onShopTap,
                          ),
                          const Spacer(),
                          if (hasCover) ...[
                            _IconGlassButton(
                              icon: Icons.open_with_rounded,
                              tooltip: texts.text('merchant.dashboard.reposition'),
                              onTap: () => setState(() {
                                _focusY = hero.coverFocusY;
                                _repositioning = true;
                              }),
                            ),
                            const SizedBox(width: 8),
                          ],
                          _IconGlassButton(
                            icon: Icons.insights_rounded,
                            tooltip: texts.text('merchant.dashboard.today'),
                            onTap: widget.onTodayTap,
                          ),
                          const SizedBox(width: 8),
                          _IconGlassButton(
                            icon: Icons.tune_rounded,
                            tooltip: texts.text('merchant.shop.title'),
                            onTap: widget.onSettingsTap,
                          ),
                        ],
                      ),
                      const SizedBox(height: 50),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _Logo(logoUrl: hero.logoUrl, shopName: shopName),
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
                              color: MerchantPremiumColors.ink,
                              fontSize: 27,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            subtitle.isEmpty
                                ? texts.text('merchant.dashboard.localPartner')
                                : subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: MerchantPremiumColors.mutedLight,
                              fontWeight: FontWeight.w700,
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
                        onTap: widget.onCustomersTap,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeroMetric(
                        label: texts.text('merchant.dashboard.feedHub'),
                        value: metrics.feedPosts.toString(),
                        icon: Icons.campaign_rounded,
                        onTap: widget.onFeedTap,
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
      },
    );
  }
}

class _RepositionOverlay extends StatelessWidget {
  const _RepositionOverlay({
    required this.hint,
    required this.saveLabel,
    required this.cancelLabel,
    required this.onSave,
    required this.onCancel,
  });

  final String hint;
  final String saveLabel;
  final String cancelLabel;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: _glassDecoration(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.swipe_vertical_rounded, color: MerchantPremiumColors.ink, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    hint,
                    style: const TextStyle(
                      color: MerchantPremiumColors.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MerchantPremiumColors.ink,
                    side: BorderSide(color: MerchantPremiumColors.gold.withValues(alpha: 0.4)),
                    backgroundColor: MerchantPremiumColors.glass,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(cancelLabel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onSave,
                  style: FilledButton.styleFrom(
                    backgroundColor: MerchantPremiumColors.gold,
                    foregroundColor: MerchantPremiumColors.base,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(saveLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
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
    );
  }
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
          ? _LogoInitials(shopName: shopName)
          : CachedNetworkImage(
              imageUrl: logoUrl,
              fit: BoxFit.cover,
              memCacheWidth: 200,
              maxWidthDiskCache: 200,
              placeholder: (_, _) => _LogoInitials(shopName: shopName),
              errorWidget: (_, _, _) => _LogoInitials(shopName: shopName),
            ),
    );
  }
}

class _LogoInitials extends StatelessWidget {
  const _LogoInitials({required this.shopName});

  final String shopName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        _initials(shopName),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
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
          color: MerchantPremiumColors.glass,
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
                  Text(
                    value,
                    style: const TextStyle(
                      color: MerchantPremiumColors.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: const TextStyle(
                      color: MerchantPremiumColors.mutedLight,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: _glassDecoration(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: MerchantPremiumColors.ink, size: 17),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  color: MerchantPremiumColors.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
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
          width: 48,
          height: 48,
          decoration: _glassDecoration(),
          child: Icon(icon, color: MerchantPremiumColors.ink, size: 20),
        ),
      ),
    );
  }
}

BoxDecoration _glassDecoration() {
  return BoxDecoration(
    color: MerchantPremiumColors.glass,
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
