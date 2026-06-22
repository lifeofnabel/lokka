import 'package:flutter/material.dart';

/// Drei Vorlagen, mit denen ein Merchant das Aussehen seiner öffentlichen
/// Speisekarte (Kundenansicht) bestimmt. Diese Liste ist die EINZIGE
/// Wahrheit – Auswahl-UI und Renderer leiten sich daraus ab. Hier eine
/// Vorlage hinzufügen/entfernen ändert beides automatisch.
///
/// Wird vom Merchant-Setting geschrieben und von der `UserMenuPage` gerendert.
enum MenuLayoutStyle {
  /// Bildliste: Foto links, Text rechts (Standard, bisheriges Verhalten).
  list,

  /// Klassische Speisekarte: Name · · · Preis mit Führungspunkten, ohne Bilder.
  compact,

  /// Magazin: große Hero-Karten mit Bild-Overlay.
  magazine;

  /// Kurzer Hinweis, für welchen Shop die Vorlage gedacht ist.
  String get tagline => switch (this) {
        MenuLayoutStyle.list => 'Der Allrounder',
        MenuLayoutStyle.compact => 'Schnörkellos & schnell',
        MenuLayoutStyle.magazine => 'Maximaler Appetit',
      };

  String get label => switch (this) {
        MenuLayoutStyle.list => 'Liste',
        MenuLayoutStyle.compact => 'Klassisch',
        MenuLayoutStyle.magazine => 'Magazin',
      };

  String get description => switch (this) {
        MenuLayoutStyle.list => 'Foto links, Text rechts',
        MenuLayoutStyle.compact => 'Name · · · Preis, ohne Bilder',
        MenuLayoutStyle.magazine => 'Große Hero-Karten mit Foto',
      };

  static MenuLayoutStyle fromId(String? id) => MenuLayoutStyle.values.firstWhere(
        (style) => style.name == id,
        orElse: () => MenuLayoutStyle.list,
      );
}

/// Gestaltung der Kundenkarte: Vorlage + Akzentfarbe + Theme + Artikel pro
/// Reihe. Persistiert als flache Felder in `publicMerchants/{uid}`.
class MenuDesign {
  const MenuDesign({
    this.layout = MenuLayoutStyle.list,
    this.accentColor = defaultAccent,
    this.darkMode = false,
    this.columns = 1,
  });

  final MenuLayoutStyle layout;

  /// ARGB-Wert der Akzentfarbe (Preise, Header-Verlauf, Highlights).
  final int accentColor;

  final bool darkMode;

  /// 1 = ein Artikel pro Reihe, 2 = zwei Artikel pro Reihe.
  final int columns;

  static const int defaultAccent = 0xFF1FA97E; // Lokka-Grün

  /// Kuratierte Akzentfarben zur Auswahl im Merchant-Setting.
  static const List<int> palette = [
    0xFF1FA97E, // Grün (Standard)
    0xFF2563EB, // Blau
    0xFF7C3AED, // Violett
    0xFFE11D48, // Pink
    0xFFF97316, // Orange
    0xFFEAB308, // Gelb
    0xFF0EA5E9, // Hellblau
    0xFF111827, // Anthrazit
  ];

  Color get accent => Color(accentColor);

  /// Genau zwei Spalten, sonst eine – schützt vor ungültigen Werten.
  int get safeColumns => columns == 2 ? 2 : 1;

  MenuDesign copyWith({
    MenuLayoutStyle? layout,
    int? accentColor,
    bool? darkMode,
    int? columns,
  }) =>
      MenuDesign(
        layout: layout ?? this.layout,
        accentColor: accentColor ?? this.accentColor,
        darkMode: darkMode ?? this.darkMode,
        columns: columns ?? this.columns,
      );

  factory MenuDesign.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const MenuDesign();
    return MenuDesign(
      layout: MenuLayoutStyle.fromId(map['menuLayoutStyle'] as String?),
      accentColor: (map['menuAccentColor'] as num?)?.toInt() ?? defaultAccent,
      darkMode: map['menuDarkMode'] as bool? ?? false,
      columns: (map['menuColumns'] as num?)?.toInt() == 2 ? 2 : 1,
    );
  }

  Map<String, dynamic> toMap() => {
        'menuLayoutStyle': layout.name,
        'menuAccentColor': accentColor,
        'menuDarkMode': darkMode,
        'menuColumns': safeColumns,
      };
}
