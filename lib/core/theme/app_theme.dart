import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const bg = Color(0xFF1C1C26);
  static const surface = Color(0xFF22222E);
  static const surface2 = Color(0xFF28283A);
  static const border = Color(0x12FFFFFF);
  static const text = Color(0xFFE4E4F0);
  static const muted = Color(0xFF60607A);
  static const green = Color(0xFF00E87A);
  static const blue = Color(0xFF4488FF);
  static const purple = Color(0xFF9966FF);
  static const amber = Color(0xFFFFAA00);
  static const red = Color(0xFFFF4466);
  static const cyan = Color(0xFF00CCFF);
}

class AppTheme {
  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    primaryColor: AppColors.green,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.green,
      secondary: AppColors.blue,
      surface: AppColors.surface,
      error: AppColors.red,
    ),
    textTheme: GoogleFonts.notoSansTextTheme(
      const TextTheme(
        displayLarge: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800),
        displayMedium: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(color: AppColors.text),
        bodyMedium: TextStyle(color: AppColors.text),
        bodySmall: TextStyle(color: AppColors.muted),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.text,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        side: BorderSide(color: AppColors.border),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.green),
      ),
      labelStyle: const TextStyle(color: AppColors.muted),
      hintStyle: const TextStyle(color: AppColors.muted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.green,
        foregroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.green,
      unselectedItemColor: AppColors.muted,
      type: BottomNavigationBarType.fixed,
    ),
  );
}
