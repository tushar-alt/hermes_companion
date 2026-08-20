import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── palette (Hermes Companion design system) ────────────────────────────
// GitHub-dark inspired: #0D1117 canvas, #161B22/#1C2128 surface levels,
// #30363D borders, #58A6FF primary. Legacy names (gold/cream/sand) are kept
// so every widget keeps compiling — they now map to the new tokens.
const Color bg = Color(0xFF0D1117); // page background
const Color surface = Color(0xFF161B22); // level-1 card
const Color ink2 = Color(0xFF1C2128); // level-2 (docked bars, code)
const Color surfaceHigh = Color(0xFF262A31); // hover / active
const Color surfaceLow = Color(0xFF181C22);
const Color borderColor = Color(0xFF30363D); // subtle border
const Color gold = Color(0xFF58A6FF); // primary
const Color goldHi = Color(0xFFA2C9FF); // primary-fixed
const Color goldLo = Color(0xFF2D6DA8); // primary gradient low
const Color cream = Color(0xFFDFE2EB); // on-surface
const Color sand = Color(0xFFC0C7D4); // on-surface-variant
const Color outline = Color(0xFF8B919D);
const Color red = Color(0xFFF85149);
const Color redDeep = Color(0xFF93000A);
const Color onRed = Color(0xFFFFDAD6);
const Color green = Color(0xFF238636);
const Color greenBright = Color(0xFF7BDB80);
const Color onPrimary = Color(0xFF0D1117); // text on primary buttons

/// Monospace family used for labels + code (JetBrains Mono via google_fonts).
const String monoFamily = 'JetBrains Mono';

const LinearGradient goldGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [goldHi, gold, goldLo],
);

/// The app-wide dark "Hermes Companion" theme (Geist display + Inter body +
/// JetBrains Mono labels/code).
ThemeData buildCompanionTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
    displayLarge: GoogleFonts.geist(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: cream,
        letterSpacing: -0.02),
    displayMedium: GoogleFonts.geist(
        fontSize: 24, fontWeight: FontWeight.w600, color: cream),
    headlineSmall: GoogleFonts.geist(
        fontSize: 20, fontWeight: FontWeight.w500, color: cream),
    titleLarge: GoogleFonts.geist(
        fontSize: 17, fontWeight: FontWeight.w600, color: cream),
    titleMedium: GoogleFonts.inter(
        fontSize: 16, fontWeight: FontWeight.w500, color: cream),
    bodyLarge: GoogleFonts.inter(fontSize: 16, height: 1.6, color: cream),
    bodyMedium: GoogleFonts.inter(fontSize: 14, height: 1.5, color: cream),
    bodySmall: GoogleFonts.inter(fontSize: 12, height: 1.4, color: sand),
    labelSmall: GoogleFonts.jetBrainsMono(
        fontSize: 11,
        height: 1,
        letterSpacing: 0.05,
        fontWeight: FontWeight.w700,
        color: sand),
    labelMedium: GoogleFonts.jetBrainsMono(
        fontSize: 13, height: 1.4, color: sand),
  );
  return base.copyWith(
    scaffoldBackgroundColor: bg,
    canvasColor: bg,
    colorScheme: base.colorScheme.copyWith(
      primary: gold,
      onPrimary: onPrimary,
      primaryContainer: gold,
      onPrimaryContainer: onPrimary,
      secondary: greenBright,
      onSecondary: onPrimary,
      secondaryContainer: green,
      onSecondaryContainer: const Color(0xFF91F294),
      surface: surface,
      onSurface: cream,
      surfaceContainerHighest: surfaceHigh,
      error: red,
      onError: onPrimary,
      errorContainer: redDeep,
      onErrorContainer: onRed,
      outline: outline,
      outlineVariant: borderColor,
    ),
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      elevation: 0,
      centerTitle: false,
      scrolledUnderElevation: 0,
      titleTextStyle:
          GoogleFonts.geist(fontSize: 20, fontWeight: FontWeight.w600, color: cream),
      iconTheme: const IconThemeData(color: sand),
    ),
    cardColor: surface,
    dividerColor: borderColor,
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderColor)),
      titleTextStyle: GoogleFonts.inter(fontSize: 17, color: cream),
      contentTextStyle: GoogleFonts.inter(fontSize: 13, color: sand),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surfaceHigh,
      contentTextStyle: GoogleFonts.inter(fontSize: 13, color: cream),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: borderColor)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? Colors.white : outline),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? green : surfaceHigh),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: bg,
      hintStyle: GoogleFonts.inter(fontSize: 14, color: outline),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: gold, width: 1.2),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: gold,
      foregroundColor: onPrimary,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: sand,
      textColor: cream,
      subtitleTextStyle: TextStyle(color: sand, fontSize: 12),
    ),
  );
}
