import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_palette.dart';

class AppTheme {
  static const lightScaffoldColor = Color(0xFFEEEEEE);
  static const darkScaffoldColor = Color(0xFF121212);
  static const darkSurfaceColor = Color(0xFF1E1E1E);

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppPalette.primary,
      brightness: Brightness.light,
      surface: Colors.white,
      primary: AppPalette.primary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: lightScaffoldColor,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        iconTheme: IconThemeData(color: Colors.black87),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        backgroundColor: Colors.white,
        collapsedBackgroundColor: Colors.white,
      ),
    );
  }

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppPalette.primary,
      brightness: Brightness.dark,
      surface: darkSurfaceColor,
      primary: AppPalette.primaryLight,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkScaffoldColor,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: darkSurfaceColor,
        foregroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: darkSurfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        backgroundColor: darkSurfaceColor,
        collapsedBackgroundColor: darkSurfaceColor,
        iconColor: colorScheme.onSurface,
        textColor: colorScheme.onSurface,
        collapsedIconColor: colorScheme.onSurface,
        collapsedTextColor: colorScheme.onSurface,
      ),
    );
  }

  static SystemUiOverlayStyle systemUiOverlayStyle(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final backgroundColor = isDark ? darkScaffoldColor : lightScaffoldColor;

    return SystemUiOverlayStyle(
      systemNavigationBarColor: backgroundColor,
      systemNavigationBarDividerColor: backgroundColor,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    );
  }
}
