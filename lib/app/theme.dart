import 'package:flutter/material.dart';

/// Tema institucional sobrio de EMAP.
class AppTheme {
  static const Color primary = Color(0xFF1B5E20); // verde institucional oscuro
  static const Color primaryDark = Color(0xFF0B3D0F);
  static const Color accent = Color(0xFF558B2F);
  static const Color background = Color(0xFFF4F6F4);
  static const Color sidebar = Color(0xFF12331A);
  static const Color surface = Colors.white;

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: accent,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: const Color(0xFFE1E8E1)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
      ),
      dataTableTheme: const DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(Color(0xFFEAF2E8)),
        headingTextStyle: TextStyle(
          color: Color(0xFF16351C),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        dataTextStyle: TextStyle(color: Color(0xFF253129), fontSize: 12),
        dividerThickness: 0.5,
        columnSpacing: 24,
        horizontalMargin: 16,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE6ECE6),
        thickness: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: sidebar,
        indicatorColor: primary,
        selectedIconTheme: IconThemeData(color: Colors.white),
        unselectedIconTheme: IconThemeData(color: Colors.white60),
        selectedLabelTextStyle: TextStyle(color: Colors.white, fontSize: 13),
        unselectedLabelTextStyle: TextStyle(
          color: Colors.white70,
          fontSize: 13,
        ),
      ),
    );
  }
}
