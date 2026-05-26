import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const _primaryColor = Color(0xFF6366F1);
  static const _surfaceDark = Color(0xFF0F0F14);
  static const _cardDark = Color(0xFF16161F);
  static const _borderDark = Color(0xFF1E1E2E);

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: _primaryColor,
      secondary: const Color(0xFF8B5CF6),
      surface: _cardDark,
      surfaceContainerHighest: _borderDark,
      onSurface: const Color.fromARGB(255, 168, 4, 105),
      outline: _borderDark,
    ),
    scaffoldBackgroundColor: _surfaceDark,
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    cardTheme: CardTheme(
      color: _cardDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _borderDark),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: _surfaceDark,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    dividerTheme: const DividerThemeData(color: _borderDark),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _borderDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _borderDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _borderDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _primaryColor),
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Color(0xFFE2E8F0),
      selectionColor: Color(0xFF334155),
      selectionHandleColor: _primaryColor,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: _borderDark,
      labelStyle: const TextStyle(
        fontSize: 12,
        color: Color.fromARGB(255, 6, 21, 41),
      ),
      secondaryLabelStyle: const TextStyle(
        fontSize: 12,
        color: Color.fromARGB(255, 6, 21, 41),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: const BorderSide(color: Color(0xFF2A2A3E)),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(_cardDark),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: _borderDark),
          ),
        ),
      ),
      textStyle: const TextStyle(color: Color(0xFFE2E8F0)),
    ),
  );

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primaryColor,
      brightness: Brightness.light,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
  );
}
