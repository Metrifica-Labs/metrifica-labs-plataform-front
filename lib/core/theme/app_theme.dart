import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const _primaryColor = Color(0xFF6366F1);
  static const _secondaryColor = Color(0xFF0EA5A4);

  // ── Dark palette ──────────────────────────────────────────────────────────
  static const _surfaceDark = Color(0xFF0F0F14);
  static const _cardDark = Color(0xFF16161F);
  static const _borderDark = Color(0xFF1E1E2E);

  // ── Light palette ─────────────────────────────────────────────────────────
  static const _surfaceLight = Color(0xFFF1F5F9);
  static const _cardLight = Color(0xFFFFFFFF);
  static const _borderLight = Color(0xFFE2E8F0);
  static const _borderLightSoft = Color(0xFFCBD5E1);
  static const _onSurfaceLight = Color(0xFF0F172A);

  // ── Dark theme ────────────────────────────────────────────────────────────
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: _primaryColor,
          secondary: _secondaryColor,
          surface: _cardDark,
          surfaceContainerHighest: _borderDark,
          onSurface: const Color(0xFFE2E8F0),
          outline: _borderDark,
          outlineVariant: const Color(0xFF2A2A3E),
        ),
        scaffoldBackgroundColor: _surfaceDark,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
            TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          },
        ),
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
        dividerTheme: const DividerThemeData(color: _borderDark, space: 1),
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            animationDuration: const Duration(milliseconds: 180),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            animationDuration: const Duration(milliseconds: 180),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            animationDuration: const Duration(milliseconds: 160),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            animationDuration: const Duration(milliseconds: 160),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: _borderDark,
          labelStyle: const TextStyle(fontSize: 12, color: Color(0xFFE2E8F0)),
          secondaryLabelStyle:
              const TextStyle(fontSize: 12, color: Color(0xFFE2E8F0)),
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

  // ── Light theme ───────────────────────────────────────────────────────────
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: _primaryColor,
          secondary: _secondaryColor,
          surface: _cardLight,
          surfaceContainerHighest: _borderLight,
          onSurface: _onSurfaceLight,
          outline: _borderLight,
          outlineVariant: _borderLightSoft,
        ),
        scaffoldBackgroundColor: _surfaceLight,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
            TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          },
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
        cardTheme: CardTheme(
          color: _cardLight,
          elevation: 0.5,
          shadowColor: const Color(0x330F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: _borderLight),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _surfaceLight,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        dividerTheme: const DividerThemeData(color: _borderLight, space: 1),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _cardLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _borderLight),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _borderLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _primaryColor, width: 1.5),
          ),
          hintStyle: TextStyle(color: _onSurfaceLight.withValues(alpha: 0.4)),
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: _onSurfaceLight,
          selectionColor: Color(0xFFE0E7FF),
          selectionHandleColor: _primaryColor,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            animationDuration: const Duration(milliseconds: 180),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            animationDuration: const Duration(milliseconds: 180),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            animationDuration: const Duration(milliseconds: 160),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            animationDuration: const Duration(milliseconds: 160),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: _borderLight,
          labelStyle: const TextStyle(fontSize: 12, color: _onSurfaceLight),
          secondaryLabelStyle:
              const TextStyle(fontSize: 12, color: _onSurfaceLight),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          side: const BorderSide(color: _borderLightSoft),
        ),
        dropdownMenuTheme: DropdownMenuThemeData(
          menuStyle: MenuStyle(
            backgroundColor: const WidgetStatePropertyAll(_cardLight),
            surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: _borderLight),
              ),
            ),
          ),
          textStyle: const TextStyle(color: _onSurfaceLight),
        ),
      );
}
