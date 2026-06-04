import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(
    ThemeMode.dark,
  );

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDarkMode') ?? true; // Default to dark
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  static void toggleTheme(bool isDark) async {
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDark);
  }

  static bool get isDarkMode => themeNotifier.value == ThemeMode.dark;
}

class AppTheme {
  static final lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.white,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF00C3FF), // Slightly darker cyan for light mode
      onPrimary: Colors.white,
      secondary: Color(0xFFFF0055), // Neon Pink
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: Colors.black87,
      error: Colors.redAccent,
      onError: Colors.white,
    ),
    textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme)
        .copyWith(
          bodyLarge: GoogleFonts.outfit(color: Colors.black87, fontSize: 18),
          bodyMedium: GoogleFonts.outfit(color: Colors.black87, fontSize: 16),
          bodySmall: GoogleFonts.outfit(color: Colors.black54, fontSize: 14),
          titleLarge: GoogleFonts.outfit(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          titleMedium: GoogleFonts.outfit(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          titleSmall: GoogleFonts.outfit(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Colors.black,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.black),
    ),
    dividerTheme: const DividerThemeData(color: Colors.black12, space: 1),
    iconTheme: const IconThemeData(color: Colors.black87),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: Color(0xFF00C3FF),
      unselectedItemColor: Colors.black38,
    ),
  );

  static final darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF050510),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF00F0FF), // Neon Cyan
      onPrimary: Colors.black,
      secondary: Color(0xFFFF0055), // Neon Pink
      onSecondary: Colors.white,
      surface: Color(0xFF151525), // Slightly lighter dark for cards
      onSurface: Colors.white,
      error: Colors.redAccent,
      onError: Colors.white,
    ),
    textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
      bodyLarge: GoogleFonts.outfit(color: Colors.white, fontSize: 18),
      bodyMedium: GoogleFonts.outfit(color: Colors.white70, fontSize: 16),
      bodySmall: GoogleFonts.outfit(color: Colors.white54, fontSize: 14),
      titleLarge: GoogleFonts.outfit(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      titleMedium: GoogleFonts.outfit(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: GoogleFonts.outfit(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF050510),
      surfaceTintColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
    ),
    dividerTheme: const DividerThemeData(color: Colors.white12, space: 1),
    iconTheme: const IconThemeData(color: Colors.white70),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF050510),
      selectedItemColor: Color(0xFF00F0FF),
      unselectedItemColor: Colors.white38,
    ),
  );
}
