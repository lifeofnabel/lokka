import 'package:flutter/material.dart';

/// The Godmode look — a distinct dark theme with a crimson accent so the admin
/// surface never visually blends into the user/merchant app. Applied at the
/// route level and re-applied around any pushed admin sub-page (pushed routes
/// live on the root Navigator and don't inherit the route-level Theme).
final ThemeData godmodeThemeData = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFFFF4D4D),
    brightness: Brightness.dark,
  ),
  scaffoldBackgroundColor: const Color(0xFF0C0D0F),
);

Widget adminThemed(Widget child) => Theme(data: godmodeThemeData, child: child);
