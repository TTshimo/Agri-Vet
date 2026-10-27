import 'package:flutter/material.dart';

/// AgroLens colours — matcha green / almond / rust — for light and dark mode.
///
/// Each colour has two roles, because the same name is used for different
/// jobs: `almond` is both the page background and the text on dark headers.
///   * [Bg]  backgrounds, cards, chips, buttons, borders and dividers
///   * [Fg]  text and icons
/// In light mode both roles give the original colours. In dark mode
/// backgrounds darken and text lightens, while the dark matcha headers (and
/// the light text on them) stay as they are.
///
/// [Palette.dark] is set by the app from ThemeProvider (see main.dart).
///
/// Text colours are chosen to reach at least 4.5:1 contrast against the
/// background they sit on (the WCAG minimum for normal text). Text on rust
/// or matcha buttons should be [Fg.almond].
class Palette {
  Palette._();
  static bool dark = false;
}

Color _pick(int light, int dark) => Color(Palette.dark ? dark : light);

/// Background / surface / line colours.
class Bg {
  Bg._();
  static Color get almond => _pick(0xFFF6EFE2, 0xFF14170F); // page background
  static Color get almondDeep => _pick(0xFFE8DCC6, 0xFF2A3122);
  static Color get almondMuted => _pick(0xFF8E9A7C, 0xFF5E6851);
  static Color get almondSoft => _pick(0xFFB9C4A6, 0xFF3E4934);
  static Color get surface => _pick(0xFFFFFFFF, 0xFF1F2519); // cards (was Colors.white)
  static Color get bgDark => _pick(0xFF1F2A1A, 0xFF141B10);
  static Color get danger => _pick(0xFFC94C3F, 0xFFB5463A);
  static Color get dangerBg => _pick(0xFFFBE9E7, 0xFF3A1F1C);
  static Color get fieldBorder => const Color(0x33FFFFFF);
  static Color get fieldFill => const Color(0x1EFFFFFF);
  static Color get glassBorder => const Color(0x2EFFFFFF);
  static Color get glassFill => const Color(0x14FFFFFF);
  static Color get hairline => _pick(0xFFEDE6D6, 0xFF2E3528);
  static Color get ink => _pick(0xFF2B2820, 0xFFEDE8DC);
  static Color get inkSoft => _pick(0xFF726C5C, 0xFF8F8878);
  static Color get matcha => _pick(0xFF5C7148, 0xFF5C7148);
  static Color get matchaDark => _pick(0xFF374530, 0xFF26321F); // headers
  static Color get matchaHeader => _pick(0xFF4A5B41, 0xFF303E2A);
  static Color get matchaLight => _pick(0xFFD6E0C4, 0xFF2E3A27);
  static Color get matchaTint => _pick(0xFFD6E0C4, 0xFF2E3A27);
  static Color get muted => _pick(0xFFB8AE97, 0xFF4A4537);
  // Deeper than the original #C1703E so light text on buttons is readable
  // (5:1 contrast, was 3.3:1).
  static Color get rust => _pick(0xFF9E5126, 0xFF9E5126);
  static Color get rustBg => _pick(0xFFF1DECB, 0xFF3D2A1E);
  static Color get waveDark => _pick(0xFF2C3A23, 0xFF1A2315);
  static Color get waveDarkSoft => _pick(0xFF374530, 0xFF222D1C);
}

/// Text and icon colours.
class Fg {
  Fg._();
  static Color get almond => const Color(0xFFF6EFE2); // on headers & buttons
  static Color get almondDeep => const Color(0xFFE8DCC6);
  static Color get almondMuted => const Color(0xFFB0BA9C); // auth screens
  static Color get almondSoft => const Color(0xFFB9C4A6);
  static Color get surface => _pick(0xFFFFFFFF, 0xFFFFFFFF);
  static Color get bgDark => _pick(0xFF1F2A1A, 0xFFDCE5CF);
  static Color get danger => _pick(0xFFC94C3F, 0xFFE57368);
  static Color get dangerBg => const Color(0xFFFBE9E7);
  static Color get fieldBorder => const Color(0x33FFFFFF);
  static Color get fieldFill => const Color(0x1EFFFFFF);
  static Color get glassBorder => const Color(0x2EFFFFFF);
  static Color get glassFill => const Color(0x14FFFFFF);
  static Color get hairline => _pick(0xFFEDE6D6, 0xFF3A4233);
  static Color get ink => _pick(0xFF2B2820, 0xFFEDE8DC);
  static Color get inkSoft => _pick(0xFF726C5C, 0xFFB3AC9A);
  static Color get matcha => _pick(0xFF4F633D, 0xFF9DB57F);
  static Color get matchaDark => _pick(0xFF374530, 0xFFB9CBA0);
  static Color get matchaHeader => _pick(0xFF4A5B41, 0xFFB9CBA0);
  static Color get matchaLight => const Color(0xFFD6E0C4);
  static Color get matchaTint => const Color(0xFFD6E0C4);
  static Color get muted => _pick(0xFF7A735F, 0xFF9C937E);
  static Color get rust => _pick(0xFF9E5126, 0xFFE0955F);
  static Color get rustBg => const Color(0xFFF1DECB);
  static Color get waveDark => _pick(0xFF2C3A23, 0xFFB9CBA0);
  static Color get waveDarkSoft => _pick(0xFF374530, 0xFFB9CBA0);
}
