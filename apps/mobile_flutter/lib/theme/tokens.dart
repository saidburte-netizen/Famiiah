import 'package:flutter/widgets.dart';

/// Design tokens from the approved design (`Fam-App-Design.html`).
/// Mirrors `apps/mobile/theme/tokens.ts` so both clients render identically.
abstract final class FamColors {
  // Core blues
  static const midnight = Color(0xFF061538);
  static const navy = Color(0xFF0A2260);
  static const royal = Color(0xFF1D4ED8);
  static const royalMid = Color(0xFF123A9C);
  static const royalDeep = Color(0xFF0F2F85);
  static const royalBright = Color(0xFF1A47C4);
  static const royalLift = Color(0xFF2F68EE);

  // Supporting
  static const ice = Color(0xFFBFD4FF);
  static const iceSoft = Color(0xFFD6E3FF);
  static const tint = Color(0xFFE6EEFF);
  static const tintDeep = Color(0xFFEEF3FD);
  static const background = Color(0xFFF4F7FE);
  static const white = Color(0xFFFFFFFF);
  static const border = Color(0xFFDDE5F5);
  static const borderStrong = Color(0xFFBFCBE6);
  static const outlineFaint = Color(0xFF9DB5EC);

  // Ink
  static const text = Color(0xFF0B1B3F);
  static const textMuted = Color(0xFF4A5B82);
  static const textLabel = Color(0xFF3D4E78);
  static const textFaint = Color(0xFF7A89AD);

  // Semantic
  static const danger = Color(0xFFB42318);
  static const dangerBg = Color(0xFFFDECEC);
  static const success = Color(0xFF0E7A4A);
  static const successBg = Color(0xFFE4F5EC);
  static const warning = Color(0xFF9A6700);
  static const warningBg = Color(0xFFFFF4DB);

  // Chips / neutral fills
  static const chip = Color(0xFF3D4E78);
  static const chipBg = Color(0xFFEEF1F8);
  static const shade = Color(0xFFC9D5EE);
  static const slate = Color(0xFF9AA8C7);
}

abstract final class FamRadius {
  static const xs = 10.0;
  static const sm = 12.0;
  static const input = 14.0;
  static const button = 16.0;
  static const card = 18.0;
  static const cardLg = 22.0;
  static const hero = 24.0;
  static const sheet = 28.0;
  static const pill = 999.0;
}

/// Matches `spacing()` in the RN client: n * 4.
double famSpacing(double n) => n * 4;

abstract final class FamFonts {
  static const display = 'PlayfairDisplay';
  static const body = 'Manrope';
}

abstract final class FamGradients {
  /// Primary call-to-action: royal blue fading into navy.
  static const primary = [FamColors.royal, FamColors.navy];

  /// Splash / login header.
  static const header = [FamColors.royalDeep, FamColors.navy, FamColors.midnight];

  /// Hero cards.
  static const hero = [FamColors.royalBright, FamColors.navy, FamColors.midnight];

  /// App icon.
  static const mark = [FamColors.royalLift, FamColors.royalMid, FamColors.midnight];
}

abstract final class FamShadows {
  /// Small control shadow (icon buttons on the app background).
  static const control = [
    BoxShadow(color: Color(0x140A2260), blurRadius: 14, offset: Offset(0, 4)),
  ];

  /// Standard content card.
  static const card = [
    BoxShadow(color: Color(0x120A2260), blurRadius: 18, offset: Offset(0, 6)),
  ];

  /// Raised hero / summary surface.
  static const hero = [
    BoxShadow(color: Color(0x470A2260), blurRadius: 36, offset: Offset(0, 18)),
  ];

  /// Primary button.
  static const button = [
    BoxShadow(color: Color(0x521D4ED8), blurRadius: 24, offset: Offset(0, 12)),
  ];

  /// Overlaid auth sheet.
  static const sheet = [
    BoxShadow(color: Color(0x290A2260), blurRadius: 60, offset: Offset(0, 24)),
  ];
}

/// Font weights used across the design, named so screens read clearly.
abstract final class FamWeight {
  static const regular = FontWeight.w400;
  static const medium = FontWeight.w500;
  static const semiBold = FontWeight.w600;
  static const bold = FontWeight.w700;
  static const extraBold = FontWeight.w800;
}

/// Minimum touch target per accessibility guidance.
const double kMinTouch = 44;
