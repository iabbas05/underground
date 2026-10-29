import 'package:flutter/material.dart';

/// Same palette as the UNDERGROUND website: black stage, violet accent.
class Palette {
  static const Color bg = Color(0xFF0A090E);
  static const Color panel = Color(0xFF14121B);
  static const Color panel2 = Color(0xFF1B1825);
  static const Color line = Color(0xFF2B2738);
  static const Color text = Color(0xFFF4F2F8);
  static const Color mute = Color(0xFFA29CB4);
  static const Color violet = Color(0xFF8A4DFF);
  static const Color violetSoft = Color(0xFFB79BFF);
  static const Color ok = Color(0xFF34D399);
  static const Color warn = Color(0xFFFBBF24);
  static const Color bad = Color(0xFFF87171);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Palette.bg,
    colorScheme: const ColorScheme.dark(
      primary: Palette.violet,
      secondary: Palette.violetSoft,
      surface: Palette.panel,
      onSurface: Palette.text,
      error: Palette.bad,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: Palette.text,
      displayColor: Palette.text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.bg,
      foregroundColor: Palette.text,
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Palette.panel,
      indicatorColor: Palette.violet.withOpacity(0.28),
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Palette.bg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Palette.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Palette.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Palette.violet, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.violet,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.text,
        minimumSize: const Size.fromHeight(46),
        side: const BorderSide(color: Palette.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    dividerColor: Palette.line,
  );
}
