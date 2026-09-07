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
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: accent,
        surface: surface,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        elevation: 1,
        color: surface,
        margin: EdgeInsets.all(8),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(primary.withValues(alpha: 0.08)),
        columnSpacing: 20,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: sidebar,
        indicatorColor: primary,
        selectedIconTheme: IconThemeData(color: Colors.white),
        unselectedIconTheme: IconThemeData(color: Colors.white60),
        selectedLabelTextStyle: TextStyle(color: Colors.white, fontSize: 13),
        unselectedLabelTextStyle: TextStyle(color: Colors.white70, fontSize: 13),
      ),
    );
  }
}
