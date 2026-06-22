import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'appColors.dart';

/// Chromium Experience – Google Material 3 Theme.
/// Lokka-Grün als Seed; Google-Surfaces (#FFFFFF/#F8F9FA), Inter als
/// Google-Sans-Fallback, weiche Elevation, runde Ecken, ruhige Hierarchie.
class AppTheme {
  const AppTheme._();

  static ThemeData get lightTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.seedGreen,
      brightness: Brightness.light,
    ).copyWith(
      surface: AppColors.surfaceBg,
      onSurface: AppColors.onSurfaceDark,
      onSurfaceVariant: AppColors.onSurfaceMuted,
      surfaceContainerLowest: AppColors.surfaceBg,
      surfaceContainerLow: AppColors.surfaceGray,
      surfaceContainer: AppColors.surfaceGray,
      surfaceContainerHigh: AppColors.surfaceGray2,
      outline: AppColors.outlineGray,
      outlineVariant: const Color(0xFFE8EAED),
      error: AppColors.googleRed,
    );

    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.surfaceBg,
      textTheme: _tunedTypography(textTheme),
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: AppColors.surfaceBg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surfaceBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceGray,
        selectedColor: scheme.secondaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
        labelStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceGray,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceBg,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.secondaryContainer,
        elevation: 1,
        labelTextStyle: WidgetStateProperty.all(
          textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceBg,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF202124),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  /// Material-3-Typoskala mit klarer Google-Hierarchie.
  static TextTheme _tunedTypography(TextTheme t) {
    return t.copyWith(
      displaySmall: t.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineMedium: t.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineSmall: t.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  /// Google-Home-Dark Theme für den Merchant-Bereich (dunkel, neutral, Grün-
  /// Akzent). Wird über die Merchant-Routen gelegt, damit Material-Widgets
  /// (Eingabefelder, Dialoge, Sheets) dunkel rendern.
  // WICHTIG: Werte mit `MerchantPremiumColors` (merchantPremiumUi.dart) synchron
  // halten – beide beschreiben dieselbe Merchant-Palette (Material-Widgets hier,
  // direkte Tokens dort). Deep-Green Operator-Look: tiefes, grün-getöntes Dunkel
  // + kräftiger Grün-Akzent (aus dem User-Grün abgeleitet, aber dunkler).
  static ThemeData get merchantDark {
    const base = Color(0xFF181E1A);
    const elevated = Color(0xFF1E2521);
    const surface = Color(0xFF222B26);
    const surfaceAlt = Color(0xFF2B352F);
    const ink = Color(0xFFF2F6F3);
    const muted = Color(0xFFA9B5AD);
    const line = Color(0xFF3A463F);
    const accent = Color(0xFF2FB389);

    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: accent,
      surface: surface,
      onSurface: ink,
      onSurfaceVariant: muted,
      surfaceContainerLowest: base,
      surfaceContainerLow: elevated,
      surfaceContainer: surface,
      surfaceContainerHigh: surfaceAlt,
      outline: line,
      outlineVariant: line,
      error: AppColors.googleRed,
    );

    final baseTheme =
        ThemeData(useMaterial3: true, brightness: Brightness.dark);
    final textTheme = GoogleFonts.interTextTheme(baseTheme.textTheme).apply(
      bodyColor: ink,
      displayColor: ink,
    );

    return baseTheme.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: base,
      textTheme: _tunedTypography(textTheme),
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: base,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: const Color(0xFF06281F),
          minimumSize: const Size.fromHeight(52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: line),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: const TextStyle(color: muted),
        labelStyle: const TextStyle(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: accent, width: 2),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
    );
  }
}
