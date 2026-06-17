import 'package:flutter/material.dart';

/// Farbpalette der öffentlichen Kundensicht. `dark` kommt vom Merchant-Design
/// (Standard) und kann vom Kunden umgeschaltet werden; `accent` ist die vom
/// Merchant gewählte Akzentfarbe (Preise, Buttons, aktive Chips, Highlights).
class PublicShopPalette {
  const PublicShopPalette({required this.dark, required this.accent});

  final bool dark;
  final Color accent;

  Color get background => dark ? const Color(0xFF10110F) : const Color(0xFFF7F5EF);
  Color get card => dark ? const Color(0xFF1A1B18) : const Color(0xFFFFFEFB);
  Color get ink => dark ? const Color(0xFFF8FAF5) : const Color(0xFF171A18);
  Color get muted => dark ? const Color(0xFFB7BEB6) : const Color(0xFF70766F);
  Color get soft => dark ? const Color(0xFF262824) : const Color(0xFFEDEAE1);
  Color get line => dark ? const Color(0xFF30342F) : const Color(0xFFE2DED3);

  /// On-Color für Flächen in Akzentfarbe (Buttons): hell, gut lesbar.
  Color get onAccent => Colors.white;
}
