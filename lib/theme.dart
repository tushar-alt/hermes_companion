import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── palette ────────────────────────────────────────────────────────────
const Color bg = Color(0xFF0C0A08);
const Color surface = Color(0xFF16120D);
const Color ink2 = Color(0xFF1E1813);
const Color gold = Color(0xFFC9A24B);
const Color goldHi = Color(0xFFE9CE8E);
const Color goldLo = Color(0xFF9A7430);
const Color cream = Color(0xFFF5EFE3);
const Color sand = Color(0xFF9C8F7B);
const Color red = Color(0xFFB33A3A);
const Color green = Color(0xFF4CAF7D);

const LinearGradient goldGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [goldHi, gold, goldLo],
);

/// The app-wide dark "Hermes" theme (Fraunces display + Manrope body).
ThemeData buildCompanionTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  final textTheme = GoogleFonts.manropeTextTheme(base.textTheme).copyWith(
    displayLarge: GoogleFonts.fraunces(
        fontSize: 42, fontWeight: FontWeight.w600, color: cream),
    displayMedium: GoogleFonts.fraunces(
        fontSize: 28, fontWeight: FontWeight.w600, color: cream),
    headlineSmall: GoogleFonts.fraunces(
        fontSize: 21, fontWeight: FontWeight.w600, color: cream),
    titleLarge: GoogleFonts.manrope(
        fontSize: 17, fontWeight: FontWeight.w700, color: cream),
    bodyMedium: GoogleFonts.manrope(fontSize: 14, height: 1.45, color: cream),
    bodySmall: GoogleFonts.manrope(fontSize: 12, color: sand),
  );
  return base.copyWith(
    scaffoldBackgroundColor: bg,
    colorScheme: base.colorScheme.copyWith(
      primary: gold,
      secondary: gold,
      surface: surface,
      onSurface: cream,
    ),
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: bg.withValues(alpha: 0.85),
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.fraunces(
          fontSize: 20, fontWeight: FontWeight.w600, color: cream),
      iconTheme: const IconThemeData(color: sand),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0x22C9A24B))),
    ),
    snackBarTheme: const SnackBarThemeData(backgroundColor: ink2),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: surface),
  );
}
