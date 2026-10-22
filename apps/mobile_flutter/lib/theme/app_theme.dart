import 'package:flutter/material.dart';

import 'tokens.dart';

/// Material 3 theme built from the Fam tokens.
///
/// Typography comes from the two bundled families (`Manrope` for UI text,
/// `PlayfairDisplay` for the wordmark and display headings), declared in
/// `pubspec.yaml`. Bundling them keeps the branding identical offline and in
/// release builds — no runtime font download.
ThemeData buildFamTheme() {
  const manrope = FamFonts.body;
  const playfair = FamFonts.display;

  const textTheme = TextTheme(
    // Display — Playfair wordmark / marquee headings.
    displayLarge: TextStyle(
      fontFamily: playfair,
      fontSize: 52,
      height: 1.05,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.0,
      color: FamColors.navy,
    ),
    displayMedium: TextStyle(
      fontFamily: playfair,
      fontSize: 38,
      height: 1.1,
      fontWeight: FontWeight.w700,
      color: FamColors.navy,
    ),
    displaySmall: TextStyle(
      fontFamily: playfair,
      fontSize: 30,
      height: 1.15,
      fontWeight: FontWeight.w700,
      color: FamColors.navy,
    ),

    // Headlines — screen titles.
    headlineLarge: TextStyle(
      fontFamily: manrope,
      fontSize: 30,
      height: 1.12,
      fontWeight: FontWeight.w800,
      color: FamColors.navy,
    ),
    headlineMedium: TextStyle(
      fontFamily: manrope,
      fontSize: 26,
      height: 1.15,
      fontWeight: FontWeight.w800,
      color: FamColors.navy,
    ),
    headlineSmall: TextStyle(
      fontFamily: manrope,
      fontSize: 22,
      height: 1.2,
      fontWeight: FontWeight.w800,
      color: FamColors.navy,
    ),

    // Titles — cards and sections.
    titleLarge: TextStyle(
      fontFamily: manrope,
      fontSize: 19,
      height: 1.2,
      fontWeight: FontWeight.w800,
      color: FamColors.navy,
    ),
    titleMedium: TextStyle(
      fontFamily: manrope,
      fontSize: 16,
      height: 1.25,
      fontWeight: FontWeight.w800,
      color: FamColors.text,
    ),
    titleSmall: TextStyle(
      fontFamily: manrope,
      fontSize: 15,
      height: 1.3,
      fontWeight: FontWeight.w800,
      color: FamColors.navy,
    ),

    // Body.
    bodyLarge: TextStyle(
      fontFamily: manrope,
      fontSize: 15,
      height: 1.5,
      fontWeight: FontWeight.w600,
      color: FamColors.text,
    ),
    bodyMedium: TextStyle(
      fontFamily: manrope,
      fontSize: 14,
      height: 1.45,
      fontWeight: FontWeight.w600,
      color: FamColors.text,
    ),
    bodySmall: TextStyle(
      fontFamily: manrope,
      fontSize: 13,
      height: 1.4,
      fontWeight: FontWeight.w600,
      color: FamColors.textMuted,
    ),

    // Labels.
    labelLarge: TextStyle(
      fontFamily: manrope,
      fontSize: 13,
      height: 1.3,
      fontWeight: FontWeight.w700,
      color: FamColors.textLabel,
    ),
    labelMedium: TextStyle(
      fontFamily: manrope,
      fontSize: 12,
      height: 1.3,
      fontWeight: FontWeight.w700,
      color: FamColors.textMuted,
    ),
    labelSmall: TextStyle(
      fontFamily: manrope,
      fontSize: 11,
      height: 1.3,
      fontWeight: FontWeight.w700,
      color: FamColors.textMuted,
    ),
  );

  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: FamColors.royal,
    onPrimary: FamColors.white,
    primaryContainer: FamColors.tint,
    onPrimaryContainer: FamColors.royalMid,
    secondary: FamColors.navy,
    onSecondary: FamColors.white,
    secondaryContainer: FamColors.tintDeep,
    onSecondaryContainer: FamColors.navy,
    tertiary: FamColors.royalLift,
    onTertiary: FamColors.white,
    error: FamColors.danger,
    onError: FamColors.white,
    errorContainer: FamColors.dangerBg,
    onErrorContainer: FamColors.danger,
    surface: FamColors.white,
    onSurface: FamColors.text,
    surfaceContainerHighest: FamColors.tintDeep,
    onSurfaceVariant: FamColors.textMuted,
    outline: FamColors.border,
    outlineVariant: FamColors.tintDeep,
    shadow: Color(0x140A2260),
    scrim: Color(0x66061538),
    inverseSurface: FamColors.navy,
    onInverseSurface: FamColors.white,
    inversePrimary: FamColors.ice,
  );

  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(FamRadius.input),
    borderSide: const BorderSide(color: FamColors.border, width: 1.5),
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: manrope,
    colorScheme: scheme,
    scaffoldBackgroundColor: FamColors.background,
    textTheme: textTheme,
    canvasColor: FamColors.background,
    dividerColor: FamColors.border,
    appBarTheme: const AppBarThemeData(
      backgroundColor: FamColors.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: FamColors.navy,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: manrope,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: FamColors.navy,
      ),
    ),
    cardTheme: CardThemeData(
      color: FamColors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FamRadius.card),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: FamColors.royal,
        foregroundColor: FamColors.white,
        disabledBackgroundColor: FamColors.shade,
        disabledForegroundColor: FamColors.white,
        minimumSize: const Size.fromHeight(54),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FamRadius.button)),
        textStyle: const TextStyle(
          fontFamily: manrope,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: FamColors.navy,
        backgroundColor: Colors.transparent,
        minimumSize: const Size.fromHeight(54),
        side: const BorderSide(color: FamColors.border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FamRadius.button)),
        textStyle: const TextStyle(
          fontFamily: manrope,
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: FamColors.royal,
        textStyle: const TextStyle(
          fontFamily: manrope,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: FamColors.white,
      hintStyle: const TextStyle(
        fontFamily: manrope,
        fontWeight: FontWeight.w600,
        fontSize: 15,
        color: FamColors.textFaint,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FamRadius.input),
        borderSide: const BorderSide(color: FamColors.royal, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FamRadius.input),
        borderSide: const BorderSide(color: FamColors.danger, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FamRadius.input),
        borderSide: const BorderSide(color: FamColors.danger, width: 1.5),
      ),
      errorStyle: const TextStyle(
        fontFamily: manrope,
        fontWeight: FontWeight.w600,
        fontSize: 12,
        color: FamColors.danger,
      ),
      prefixIconColor: FamColors.textLabel,
      suffixIconColor: FamColors.textLabel,
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: const BorderSide(color: FamColors.borderStrong, width: 1.5),
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? FamColors.royal : Colors.transparent,
      ),
      checkColor: const WidgetStatePropertyAll(FamColors.white),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(FamColors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? FamColors.royal : FamColors.border,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    dividerTheme: const DividerThemeData(
      color: FamColors.tintDeep,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: FamColors.midnight,
      contentTextStyle: TextStyle(
        fontFamily: manrope,
        fontWeight: FontWeight.w600,
        color: FamColors.white,
      ),
      behavior: SnackBarBehavior.floating,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: FamColors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: FamColors.tint,
      elevation: 0,
      height: 76,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(fontFamily: manrope, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: FamColors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FamRadius.sheet)),
      titleTextStyle: const TextStyle(
        fontFamily: manrope,
        fontSize: 19,
        fontWeight: FontWeight.w800,
        color: FamColors.navy,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: FamColors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: FamColors.border,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: FamColors.white,
      selectedColor: FamColors.royal,
      disabledColor: FamColors.tintDeep,
      labelStyle: const TextStyle(
        fontFamily: manrope,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: FamColors.navy,
      ),
      secondaryLabelStyle: const TextStyle(
        fontFamily: manrope,
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: FamColors.white,
      ),
      side: const BorderSide(color: FamColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FamRadius.pill)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: FamColors.royal,
      linearTrackColor: FamColors.tint,
      linearMinHeight: 8,
      circularTrackColor: Colors.transparent,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: FamColors.royalMid,
      textColor: FamColors.text,
      titleTextStyle: TextStyle(
        fontFamily: manrope,
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: FamColors.text,
      ),
      subtitleTextStyle: TextStyle(
        fontFamily: manrope,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: FamColors.textMuted,
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: FamColors.midnight,
        borderRadius: BorderRadius.circular(FamRadius.sm),
      ),
      textStyle: const TextStyle(
        fontFamily: manrope,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: FamColors.white,
      ),
    ),
  );
}
