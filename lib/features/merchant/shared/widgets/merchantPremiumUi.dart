import 'package:flutter/material.dart';

class MerchantPremiumColors {
  const MerchantPremiumColors._();

  // ── Google-Home-Dark – neutral, dunkel, Grün als Akzent ──────────────────
  // Token-Namen bleiben gleich (alle Merchant-Seiten erben automatisch).
  // ACHTUNG: surface ist jetzt DUNKEL, ink ist HELL (Theme invertiert).
  // Minimal aufgehellt für besseren Kontrast / klarere Karten-Abgrenzung.
  static const Color base = Color(0xFF17181B); // Hintergrund (dunkel, weicher)
  static const Color baseElevated = Color(0xFF202327);
  static const Color baseSoft = Color(0xFF2A2D32);
  static const Color surface = Color(0xFF24272B); // Karten (heller abgesetzt)
  static const Color surfaceAlt = Color(0xFF2E3137);
  static const Color surfaceWarm = Color(0xFF33373D);
  static const Color ink = Color(0xFFF1F3F5); // Text hell (höherer Kontrast)
  static const Color muted = Color(0xFFAEB4BB); // Sekundärtext (heller)
  static const Color mutedLight = Color(0xFFCDD1D6);
  static const Color line = Color(0xFF3C4047); // Border/Divider (sichtbarer)
  static const Color gold = Color(0xFF45C9A4); // Akzent = Grün
  static const Color goldSoft = Color(0xFF14352C); // grüner Container (dunkel)
  static const Color mint = Color(0xFF8EE8C8);
  static const Color mintSoft = Color(0xFF14352C);
  static const Color coral = Color(0xFFFF8A6A);
  static const Color coralSoft = Color(0xFF3A231D);
  static const Color success = Color(0xFF5BD18E);
  static const Color successSoft = Color(0xFF14352A);
  static const Color danger = Color(0xFFF2776B);
  static const Color dangerSoft = Color(0xFF3A1E1B);
  static const Color warning = Color(0xFFF9C266);
  static const Color warningSoft = Color(0xFF3A2F16);

  // Transparenz / Glas (Google-Home-Feel auf dunklem Grund).
  static const Color glass = Color(0x14FFFFFF); // subtiler heller Overlay
  static const Color glassBorder = Color(0x1FFFFFFF);
}

class MerchantPremiumShadows {
  const MerchantPremiumShadows._();

  static List<BoxShadow> get card => [
        BoxShadow(
          color: const Color(0xFF3B2415).withOpacity(0.18),
          blurRadius: 32,
          offset: const Offset(0, 16),
        ),
      ];

  static List<BoxShadow> get soft => [
        BoxShadow(
          color: const Color(0xFF3B2415).withOpacity(0.08),
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
            ? MerchantPremiumColors.gold.withOpacity(0.18)
            : MerchantPremiumColors.goldSoft,
        borderRadius: BorderRadius.circular(size * 0.34),
        border: Border.all(
          color: dark
              ? Colors.white.withOpacity(0.16)
              : MerchantPremiumColors.gold.withOpacity(0.22),
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
      color: MerchantPremiumColors.muted.withOpacity(0.72),
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
