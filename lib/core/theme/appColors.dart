import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const black = Color(0xFF171A18);
  static const white = Color(0xFFFEFFFC);
  static const background = Color(0xFFFAFBF7);
  static const surface = Color(0xFFFEFFFC);
  static const mint = Color(0xFF9CE8CF);
  static const mintStrong = Color(0xFF45C9A4);
  static const mintSoft = Color(0xFFE9FAF3);
  static const gray50 = Color(0xFFF5F6F2);
  static const gray100 = Color(0xFFEDEDED);
  static const border = Color(0xFFE5E8E0);
  static const gray300 = Color(0xFFC8C8C8);
  static const gray500 = Color(0xFF808080);
  static const gray700 = Color(0xFF4A4A4A);
  static const gray900 = Color(0xFF1A1A1A);

  // ── Grün/Mint – User-Bereich-Theme (Profil-Redesign) ──────────────────────
  static const greenDeep = Color(0xFF0E4034); // dunkles Grün (Text/Verläufe)
  static const green = Color(0xFF1FA97E); // kräftiges Grün (Akzente)
  static const greenTint = Color(0xFFEFFBF6); // sehr helle Mint-Fläche (Karten/BG)
  static const greenLine = Color(0xFFCFEFE2); // grünliche Trennlinie/Border

  static const LinearGradient mintGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3FD1A7), Color(0xFF12835F)],
  );

  static const LinearGradient mintGradientSoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8FE9CF), Color(0xFF45C9A4)],
  );

  // ── Chromium Experience – Google Material 3 Tokens ────────────────────────
  // Lokka-Grün ist der M3-Seed; diese Semantikfarben folgen der Google-Palette.
  static const seedGreen = Color(0xFF1FA97E); // Marke = M3-Seed/Primary
  static const googleBlue = Color(0xFF1A73E8); // Info/Links (sekundär)
  static const googleGreen = Color(0xFF1E8E3E); // Success
  static const googleYellow = Color(0xFFF9AB00); // Warning
  static const googleRed = Color(0xFFD93025); // Error
  static const surfaceBg = Color(0xFFFFFFFF); // Background
  static const surfaceGray = Color(0xFFF8F9FA); // Surface (Cards/Bars)
  static const surfaceGray2 = Color(0xFFF1F3F4); // Surface-Container
  static const outlineGray = Color(0xFFDADCE0); // Material Outline
  static const onSurfaceDark = Color(0xFF1F1F1F); // Text auf hell
  static const onSurfaceMuted = Color(0xFF5F6368); // Sekundärtext (Google Grey 700)
}
