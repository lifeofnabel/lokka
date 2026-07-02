import 'package:flutter/material.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/widgets/appPillSwitch.dart' show kAppMaxWidth;

/// Design tokens for the Wallet section.
///
/// Colours are NOT redefined here — they come 1:1 from [AppColors] (brand) or
/// the active `ColorScheme` (theme-aware surfaces/text). This file only holds
/// spacing, radii, shadows, motion and font weights, so every Wallet widget
/// pulls from one source and stays consistent + dark-mode-ready.
class WalletTokens {
  const WalletTokens._();

  /// Mobile-first: on tablet/desktop the content is capped to this width and
  /// centered, the rest of the surface stays neutral (like a phone on a table).
  /// Same value as [kAppMaxWidth] (the shell already caps the whole app to
  /// phone width) – referenced, not duplicated, so the two can't drift apart.
  static const double maxContentWidth = kAppMaxWidth;

  // ── Radii ──────────────────────────────────────────────────────────────────
  static const double cardRadius = 20;
  static const double sheetRadius = 28;
  static const double qrRadius = 16;
  static const double chipRadius = 100;

  // ── Spacing (4-pt scale) ─────────────────────────────────────────────────────
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  // ── Card sizing ──────────────────────────────────────────────────────────────
  static const double cardMinHeight = 160;
  static const double merchantAvatar = 42; // on the card
  static const double merchantAvatarSheet = 52; // in the QR sheet
  static const double badgeDot = 10;

  // ── Motion (only easeOutCubic, ≤ 300ms — no overkill) ───────────────────────
  static const Duration motion = Duration(milliseconds: 280);
  static const Duration motionFast = Duration(milliseconds: 200);
  static const Curve curve = Curves.easeOutCubic;

  // ── Font weights ─────────────────────────────────────────────────────────────
  static const FontWeight wMedium = FontWeight.w500;
  static const FontWeight wSemibold = FontWeight.w600;
  static const FontWeight wBold = FontWeight.w700;
  static const FontWeight wHeavy = FontWeight.w800;

  // ── Shadows (shadow colour referenced from AppColors, not redefined) ────────
  // War alpha 0.28/blur 22 – auf weißem Grund las sich das nicht als weiche
  // Tiefe, sondern als harte graue Umrandung um die Karte. Deutlich weicher.
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: AppColors.black.withValues(alpha: 0.10),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: AppColors.black.withValues(alpha: 0.12),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ];

  /// Story-ring gradient (merchant posted < 24h) — brand colours from AppColors.
  static const Gradient storyRing = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.mintStrong, AppColors.green, AppColors.greenDeep],
  );
}
