import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Material 3 theme built from the Fam tokens. The design is light-first;
/// `midnight` is reserved for headers and splash surfaces.
ThemeData buildFamTheme() {
  final base = GoogleFonts.manropeTextTheme();
  final textTheme = base.copyWith(
    displayLarge: GoogleFonts.playfairDisplay(
      textStyle: base.displayLarge,
      fontWeight: FontWeight.w700,
      color: FamColors.navy,
    ),
    displayMedium: GoogleFonts.playfairDisplay(
      textStyle: base.displayMedium,
      fontWeight: FontWeight.w700,
      color: FamColors.navy,
    ),
    headlineSmall: GoogleFonts.playfairDisplay(
      textStyle: base.headlineSmall,
      fontWeight: FontWeight.w700,
      color: FamColors.navy,
    ),
    bodyMedium: GoogleFonts.manrope(textStyle: base.bodyMedium, color: FamColors.text),
    bodySmall: GoogleFonts.manrope(textStyle: base.bodySmall, color: FamColors.textMuted),
    labelLarge: GoogleFonts.manrope(
      textStyle: base.labelLarge,
      fontWeight: FontWeight.w700,
      color: FamColors.text,
    ),
  );

  final scheme = ColorScheme.fromSeed(
    seedColor: FamColors.royal,
    primary: FamColors.royal,
    secondary: FamColors.navy,
    surface: FamColors.white,
    error: FamColors.danger,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: FamColors.background,
    textTheme: textTheme,
    dividerColor: FamColors.border,
    appBarTheme: const AppBarThemeData(
      backgroundColor: FamColors.midnight,
      foregroundColor: FamColors.white,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: FamColors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FamRadius.card),
        side: const BorderSide(color: FamColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: FamColors.royal,
        foregroundColor: FamColors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FamRadius.button)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: FamColors.navy,
        minimumSize: const Size.fromHeight(54),
        side: const BorderSide(color: FamColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FamRadius.button)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: FamColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: FamColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: FamColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: FamColors.royal, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: FamColors.danger),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: FamColors.midnight,
      contentTextStyle: TextStyle(color: FamColors.white),
      behavior: SnackBarBehavior.floating,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: FamColors.white,
      indicatorColor: FamColors.tint,
      labelTextStyle: WidgetStatePropertyAll(
        GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
