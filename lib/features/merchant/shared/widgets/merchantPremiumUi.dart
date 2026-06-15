import 'package:flutter/material.dart';

class MerchantPremiumColors {
  const MerchantPremiumColors._();

  // ── Soft-Dark – neutral, dunkel, Grün als Akzent ─────────────────────────
  // Token-Namen bleiben gleich (alle Merchant-Seiten erben automatisch).
  // ACHTUNG: surface ist DUNKEL, ink ist HELL (Theme invertiert).
  // Aufgehellt (weiches Anthrazit statt Fast-Schwarz) + helleres Grün für
  // besseren Kontrast/Lesbarkeit – bleibt aber dunkler als der User-Bereich.
  // WICHTIG: Werte mit `AppTheme.merchantDark` (appTheme.dart) synchron halten.
  static const Color base = Color(0xFF1E2126); // Hintergrund (weiches Anthrazit)
  static const Color baseElevated = Color(0xFF262A30);
  static const Color baseSoft = Color(0xFF2F343B);
  static const Color surface = Color(0xFF2C3036); // Karten (klar abgesetzt)
  static const Color surfaceAlt = Color(0xFF373C44);
  static const Color surfaceWarm = Color(0xFF3E434C);
  static const Color ink = Color(0xFFF5F7F9); // Primärtext (hoher Kontrast)
  static const Color muted = Color(0xFFBBC2CA); // Sekundärtext (klar lesbar)
  static const Color mutedLight = Color(0xFFDBDFE4);
  static const Color line = Color(0xFF49505A); // Border/Divider (sichtbar)
  static const Color gold = Color(0xFF55D8B0); // Akzent = Grün (heller)
  static const Color goldSoft = Color(0xFF1D4A3D); // grüner Container
  static const Color mint = Color(0xFF9CEFD4);
  static const Color mintSoft = Color(0xFF1D4A3D);
  static const Color coral = Color(0xFFFF9270);
  static const Color coralSoft = Color(0xFF402720);
  static const Color success = Color(0xFF63D996);
  static const Color successSoft = Color(0xFF173D2F);
  static const Color danger = Color(0xFFF58578);
  static const Color dangerSoft = Color(0xFF40221E);
  static const Color warning = Color(0xFFFBCB73);
  static const Color warningSoft = Color(0xFF40331A);

  // Transparenz / Glas (Google-Home-Feel auf dunklem Grund).
  static const Color glass = Color(0x14FFFFFF); // subtiler heller Overlay
  static const Color glassBorder = Color(0x1FFFFFFF);
}

class MerchantPremiumShadows {
  const MerchantPremiumShadows._();

  static List<BoxShadow> get card => [
        BoxShadow(
          color: const Color(0xFF3B2415).withValues(alpha: 0.18),
          blurRadius: 32,
          offset: const Offset(0, 16),
        ),
      ];

  static List<BoxShadow> get soft => [
        BoxShadow(
          color: const Color(0xFF3B2415).withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ];
}

class MerchantPremiumCard extends StatelessWidget {
  const MerchantPremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.color = MerchantPremiumColors.surface,
    this.borderColor = MerchantPremiumColors.line,
    this.radius = 30,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color color;
  final Color borderColor;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: MerchantPremiumShadows.soft,
      ),
      child: child,
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );
  }
}

class MerchantPremiumIconBox extends StatelessWidget {
  const MerchantPremiumIconBox({
    super.key,
    required this.icon,
    this.dark = false,
    this.size = 48,
    this.iconSize = 22,
  });

  final IconData icon;
  final bool dark;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: dark
            ? MerchantPremiumColors.gold.withValues(alpha: 0.18)
            : MerchantPremiumColors.goldSoft,
        borderRadius: BorderRadius.circular(size * 0.34),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.16)
              : MerchantPremiumColors.gold.withValues(alpha: 0.22),
        ),
      ),
      child: Icon(
        icon,
        color: dark ? MerchantPremiumColors.goldSoft : MerchantPremiumColors.ink,
        size: iconSize,
      ),
    );
  }
}

class MerchantPremiumPill extends StatelessWidget {
  const MerchantPremiumPill({
    super.key,
    required this.label,
    this.icon,
    this.background = MerchantPremiumColors.surfaceAlt,
    this.foreground = MerchantPremiumColors.ink,
    this.borderColor = MerchantPremiumColors.line,
  });

  final String label;
  final IconData? icon;
  final Color background;
  final Color foreground;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: foreground),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration merchantPremiumInputDecoration({
  required String label,
  String? hint,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(22),
    borderSide: const BorderSide(color: MerchantPremiumColors.line),
  );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: MerchantPremiumColors.surface,
    labelStyle: const TextStyle(
      color: MerchantPremiumColors.muted,
      fontWeight: FontWeight.w800,
    ),
    hintStyle: TextStyle(
      color: MerchantPremiumColors.muted.withValues(alpha: 0.72),
      fontWeight: FontWeight.w700,
    ),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: const BorderSide(
        color: MerchantPremiumColors.gold,
        width: 1.4,
      ),
    ),
  );
}
