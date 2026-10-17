import 'package:flutter/widgets.dart';

/// Design tokens from the approved design (section 6 of the brief).
/// Mirrors `apps/mobile/theme/tokens.ts` so both clients render identically.
abstract final class FamColors {
  static const midnight = Color(0xFF061538);
  static const navy = Color(0xFF0A2260);
  static const royal = Color(0xFF1D4ED8);
  static const royalMid = Color(0xFF123A9C);
  static const ice = Color(0xFFBFD4FF);
  static const tint = Color(0xFFE6EEFF);
  static const background = Color(0xFFF4F7FE);
  static const white = Color(0xFFFFFFFF);
  static const border = Color(0xFFDDE5F5);
  static const text = Color(0xFF0B1B3F);
  static const textMuted = Color(0xFF4A5B82);
  static const danger = Color(0xFFB42318);
  static const dangerBg = Color(0xFFFDECEC);
  static const chip = Color(0xFF3D4E78);
  static const chipBg = Color(0xFFEEF1F8);
}

abstract final class FamRadius {
  static const card = 20.0;
  static const button = 16.0;
  static const pill = 999.0;
}

/// Matches `spacing()` in the RN client: n * 4.
double famSpacing(double n) => n * 4;

abstract final class FamFonts {
  static const display = 'PlayfairDisplay';
  static const body = 'Manrope';
}

abstract final class FamGradients {
  static const primary = [FamColors.royal, FamColors.navy];
}

/// Minimum touch target per accessibility guidance.
const double kMinTouch = 44;
