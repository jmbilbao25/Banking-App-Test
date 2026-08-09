import 'package:flutter/material.dart';

/// Raw brand palette, transcribed from the FrostBank brand sheet.
///
/// Widgets never read this class directly. They read [AppTokens], which
/// resolves a light value and a dark value for every semantic role.
abstract final class Palette {
  // Primary
  static const Color deepNavy = Color(0xFF0B0D2B);
  static const Color primaryPurple = Color(0xFF2B1E6B);
  static const Color primaryBlue = Color(0xFF1565E0);
  static const Color vibrantBlue = Color(0xFF6A5CFF);
  static const Color skyBlue = Color(0xFFBFD6FF);

  // Gradients
  static const List<Color> gradientPrimary = [deepNavy, primaryBlue];
  static const List<Color> gradientSecondary = [primaryPurple, skyBlue];
  static const List<Color> gradientCard = [
    Color(0xFF1E1B4B),
    Color(0xFF00D4FF),
  ];

  // Neutral
  static const Color textPrimary = Color(0xFF0F1123);
  static const Color textSecondary = Color(0xFF475569);
  static const Color border = Color(0xFFCBD5E1);
  static const Color surface = Color(0xFFF1F5F9);
  static const Color backgroundLight = Color(0xFFF8FAFF);
  static const Color background = Color(0xFFFFFFFF);

  // Semantic
  static const Color success = Color(0xFF22C55E);
  static const Color info = Color(0xFF1976D2);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // Interactive
  static const Color interactivePrimary = primaryPurple;
  static const Color interactiveHover = Color(0xFF3C2A8C);
  static const Color interactiveActive = vibrantBlue;
  static const Color interactiveSecondary = Color(0xFFEEF0FF);
  static const Color disabled = Color(0xFFE2E8F0);

  // Payment card face. A single vertical fall from ice to ink, so the brand
  // mark sits on the dark half and the frozen top edge carries the colour.
  // These are face-only values and never appear in the interface chrome.
  static const Color cardIce = Color(0xFFA9D0E7);
  static const Color cardSky = Color(0xFF6DB4DD);
  static const Color cardAzure = Color(0xFF1C9FDB);
  static const Color cardOcean = Color(0xFF0B6DB1);
  static const Color cardDeep = Color(0xFF0A2C50);
  static const Color cardNight = Color(0xFF070E1C);
  static const Color cardVoid = Color(0xFF04060B);

  /// Top to bottom fall of the card face.
  static const List<Color> gradientCardFace = [
    cardIce,
    cardSky,
    cardAzure,
    cardOcean,
    cardDeep,
    cardNight,
    cardVoid,
  ];

  /// Stops for every card face fall. Front loaded, so colour lives in the top
  /// third and the mark reads white against near black below it.
  ///
  /// Shared by all three falls: the structure is what makes the portfolio one
  /// family, and only the hue of the band tells one product from another.
  static const List<double> cardFaceStops = [0, 0.08, 0.2, 0.29, 0.41, 0.58, 1];

  /// Second card product. The same fall carried by the violet end of the brand
  /// sheet, so two cards in a wallet are not the same object twice.
  static const List<Color> gradientCardAurora = [
    skyBlue,
    frostPeriwinkle,
    frostViolet,
    frostPurple,
    primaryPurple,
    cardNight,
    cardVoid,
  ];

  /// Third card product. The same fall in the brand's own blue rather than the
  /// cyan of [gradientCardFace], which reads as a different card beside it.
  static const List<Color> gradientCardMeridian = [
    frostIcePale,
    skyBlue,
    frostIceBlue,
    primaryBlue,
    deepNavy,
    cardNight,
    cardVoid,
  ];

  // FrostBank brand surface, transcribed from the brand mark artwork. These
  // build the layered backdrop that the logo and every brand surface share.
  static const Color frostBaseTop = Color(0xFF0A0D2C);
  static const Color frostBaseBottom = Color(0xFF081135);
  static const Color frostIceWhite = Color(0xFFEDF9FF);
  static const Color frostIcePale = Color(0xFFDDF4FF);
  static const Color frostIceBlue = Color(0xFF4EA3FF);
  static const Color frostPeriwinkle = Color(0xFFB0CBFF);
  static const Color frostViolet = Color(0xFF7E7AF8);
  static const Color frostPurple = Color(0xFF5548D9);
  static const Color frostInk = Color(0xFF0B0D22);
  static const Color frostLift = Color(0xFF274AAE);

  // Dark surfaces, derived from Deep Navy so brand identity survives dark mode.
  static const Color darkBackground = Color(0xFF07091C);
  static const Color darkBackgroundAlt = deepNavy;
  static const Color darkSurface = Color(0xFF151935);
  static const Color darkSurfaceRaised = Color(0xFF1E2347);
  static const Color darkBorder = Color(0xFF2E3560);
  static const Color darkTextPrimary = Color(0xFFF5F7FF);
  static const Color darkTextSecondary = Color(0xFFAEB8D6);
  static const Color darkDisabled = Color(0xFF343B63);
}

/// The single radius scale. Every rounded surface reads a step from here.
abstract final class AppRadius {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// Fully rounded controls (pills, chips, avatars).
  static const double pill = 999;

  static BorderRadius all(double step) => BorderRadius.circular(step);
}

/// The single spacing scale, built on a 4 logical pixel unit.
abstract final class Space {
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 20;
  static const double x6 = 24;
  static const double x7 = 28;
  static const double x8 = 32;
  static const double x10 = 40;
  static const double x12 = 48;
  static const double x16 = 64;
}

/// Layout constants shared across every screen.
abstract final class Layout {
  /// Content width cap so the web build reads as a designed application
  /// instead of a stretched phone layout.
  static const double maxContentWidth = 520;

  /// Minimum tap target on every platform.
  static const double minTapTarget = 48;

  /// Bottom padding a scrolling screen needs so its content can clear the
  /// floating navigation bar.
  ///
  /// The bar is 68 logical pixels tall and floats 16 above the bottom edge, so it
  /// covers the lowest 84 pixels of the screen. A scrollable padded by less than
  /// that can never bring its final row out from under the bar, however far the
  /// user scrolls - the row stays permanently half covered.
  ///
  /// Which is what was happening. Screens were padded by 40. A reviewer studying a
  /// render of the navigation bar measured the bottom edge cutting a transaction
  /// row through the middle of its capitals, leaving 11 pixels of a 31 pixel cap
  /// height, and pointed out that this was a layout fault rather than anything the
  /// glass was doing: no tint or refraction can rescue a row the bar is sitting on.
  /// It was invisible in every previous round because the argument was about the
  /// material and nobody had asked what the material was covering up.
  ///
  /// 84 plus a 16 pixel breathing gap. Deliberately not `Space` - this is a
  /// measurement of a specific widget, and it has to move when that widget's height
  /// does.
  static const double navBarClearance = 100;
}

/// Semantic design tokens for one brightness.
///
/// Resolved through [Theme], so a widget that asks for a token that does not
/// exist fails at the call site with a named assertion instead of silently
/// falling back to a Material default.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.brightness,
    required this.background,
    required this.backgroundAlt,
    required this.surface,
    required this.surfaceRaised,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textOnBrand,
    required this.accent,
    required this.interactivePrimary,
    required this.interactiveHover,
    required this.interactiveActive,
    required this.interactiveSecondary,
    required this.disabled,
    required this.success,
    required this.info,
    required this.warning,
    required this.error,
    required this.skeletonBase,
    required this.skeletonHighlight,
    required this.shadow,
    required this.gradientPrimary,
    required this.gradientSecondary,
    required this.gradientCard,
  });

  final Brightness brightness;
  final Color background;
  final Color backgroundAlt;
  final Color surface;
  final Color surfaceRaised;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;

  /// Text and icon color that sits on a brand gradient.
  final Color textOnBrand;

  /// The single accent. Every active indicator and focus ring resolves here.
  final Color accent;

  final Color interactivePrimary;
  final Color interactiveHover;
  final Color interactiveActive;
  final Color interactiveSecondary;
  final Color disabled;
  final Color success;
  final Color info;
  final Color warning;
  final Color error;
  final Color skeletonBase;
  final Color skeletonHighlight;

  /// Soft elevation tinted toward the brand navy. Cards lean on this instead of
  /// hard one pixel borders.
  final Color shadow;
  final List<Color> gradientPrimary;
  final List<Color> gradientSecondary;
  final List<Color> gradientCard;

  static const AppTokens light = AppTokens(
    brightness: Brightness.light,
    background: Palette.background,
    backgroundAlt: Palette.backgroundLight,
    surface: Palette.surface,
    surfaceRaised: Palette.background,
    border: Palette.border,
    textPrimary: Palette.textPrimary,
    textSecondary: Palette.textSecondary,
    textOnBrand: Palette.background,
    accent: Palette.vibrantBlue,
    interactivePrimary: Palette.interactivePrimary,
    interactiveHover: Palette.interactiveHover,
    interactiveActive: Palette.interactiveActive,
    interactiveSecondary: Palette.interactiveSecondary,
    disabled: Palette.disabled,
    success: Palette.success,
    info: Palette.info,
    warning: Palette.warning,
    error: Palette.error,
    skeletonBase: Palette.surface,
    skeletonHighlight: Color(0xFFE2E8F0),
    shadow: Color(0x140B0D2B),
    gradientPrimary: Palette.gradientPrimary,
    gradientSecondary: Palette.gradientSecondary,
    gradientCard: Palette.gradientCard,
  );

  static const AppTokens dark = AppTokens(
    brightness: Brightness.dark,
    background: Palette.darkBackground,
    backgroundAlt: Palette.darkBackgroundAlt,
    surface: Palette.darkSurface,
    surfaceRaised: Palette.darkSurfaceRaised,
    border: Palette.darkBorder,
    textPrimary: Palette.darkTextPrimary,
    textSecondary: Palette.darkTextSecondary,
    textOnBrand: Palette.background,
    accent: Palette.vibrantBlue,
    interactivePrimary: Palette.vibrantBlue,
    interactiveHover: Color(0xFF8478FF),
    interactiveActive: Palette.skyBlue,
    interactiveSecondary: Color(0xFF232A55),
    disabled: Palette.darkDisabled,
    success: Color(0xFF4ADE80),
    info: Color(0xFF60A5FA),
    warning: Color(0xFFFBBF24),
    error: Color(0xFFF87171),
    skeletonBase: Palette.darkSurface,
    skeletonHighlight: Palette.darkSurfaceRaised,
    shadow: Color(0x66040616),
    gradientPrimary: Palette.gradientPrimary,
    gradientSecondary: Palette.gradientSecondary,
    gradientCard: Palette.gradientCard,
  );

  static AppTokens of(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>();
    assert(
      tokens != null,
      'AppTokens missing from Theme. Build the theme with AppTheme.light or '
      'AppTheme.dark so every semantic token resolves.',
    );
    return tokens ?? light;
  }

  bool get isDark => brightness == Brightness.dark;

  @override
  AppTokens copyWith({Brightness? brightness}) =>
      brightness == null || brightness == this.brightness
      ? this
      : (brightness == Brightness.dark ? dark : light);

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    // State transition: theme changes cross fade token by token.
    return AppTokens(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: Color.lerp(background, other.background, t)!,
      backgroundAlt: Color.lerp(backgroundAlt, other.backgroundAlt, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textOnBrand: Color.lerp(textOnBrand, other.textOnBrand, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      interactivePrimary: Color.lerp(
        interactivePrimary,
        other.interactivePrimary,
        t,
      )!,
      interactiveHover: Color.lerp(
        interactiveHover,
        other.interactiveHover,
        t,
      )!,
      interactiveActive: Color.lerp(
        interactiveActive,
        other.interactiveActive,
        t,
      )!,
      interactiveSecondary: Color.lerp(
        interactiveSecondary,
        other.interactiveSecondary,
        t,
      )!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
      success: Color.lerp(success, other.success, t)!,
      info: Color.lerp(info, other.info, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      skeletonBase: Color.lerp(skeletonBase, other.skeletonBase, t)!,
      skeletonHighlight: Color.lerp(
        skeletonHighlight,
        other.skeletonHighlight,
        t,
      )!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      gradientPrimary: _lerpStops(gradientPrimary, other.gradientPrimary, t),
      gradientSecondary: _lerpStops(
        gradientSecondary,
        other.gradientSecondary,
        t,
      ),
      gradientCard: _lerpStops(gradientCard, other.gradientCard, t),
    );
  }

  static List<Color> _lerpStops(List<Color> a, List<Color> b, double t) => [
    for (var i = 0; i < a.length; i++) Color.lerp(a[i], b[i], t)!,
  ];
}

extension AppTokensContext on BuildContext {
  /// Shorthand for the resolved semantic tokens.
  AppTokens get tokens => AppTokens.of(this);
}
