import 'package:flutter/material.dart';

/// The single typography scale.
///
/// Outfit carries display and headline, Geist carries title, body, and label,
/// GeistMono carries every monetary figure, quantity, and card digit. The three
/// families ship as variable fonts, so each step declares `fontVariations`
/// alongside `fontWeight` to land on the true weight instance rather than a
/// synthesised one.
abstract final class AppType {
  static const String display = 'Outfit';
  static const String ui = 'Geist';
  static const String mono = 'GeistMono';

  static List<FontVariation> _wght(double weight) => [
    FontVariation('wght', weight),
  ];

  static TextStyle _style({
    required String family,
    required double size,
    required double weight,
    required double height,
    double letterSpacing = 0,
  }) => TextStyle(
    fontFamily: family,
    fontSize: size,
    height: height,
    letterSpacing: letterSpacing,
    fontWeight: FontWeight.values[(weight ~/ 100) - 1],
    fontVariations: _wght(weight),
  );

  // Display, Outfit. Kept restrained so headlines carry hierarchy through
  // weight and colour rather than raw scale.
  static final TextStyle displayLarge = _style(
    family: display,
    size: 30,
    weight: 600,
    height: 1.16,
    letterSpacing: -0.4,
  );
  static final TextStyle displayMedium = _style(
    family: display,
    size: 25,
    weight: 600,
    height: 1.2,
    letterSpacing: -0.3,
  );

  // Headline, Outfit.
  static final TextStyle headlineLarge = _style(
    family: display,
    size: 21,
    weight: 600,
    height: 1.24,
    letterSpacing: -0.2,
  );
  static final TextStyle headlineMedium = _style(
    family: display,
    size: 18,
    weight: 600,
    height: 1.28,
    letterSpacing: -0.1,
  );

  // Title, Geist.
  static final TextStyle titleLarge = _style(
    family: ui,
    size: 18,
    weight: 600,
    height: 1.3,
  );
  static final TextStyle titleMedium = _style(
    family: ui,
    size: 16,
    weight: 600,
    height: 1.3,
  );
  static final TextStyle titleSmall = _style(
    family: ui,
    size: 14,
    weight: 600,
    height: 1.32,
  );

  // Body, Geist.
  static final TextStyle bodyLarge = _style(
    family: ui,
    size: 16,
    weight: 400,
    height: 1.45,
  );
  static final TextStyle bodyMedium = _style(
    family: ui,
    size: 14,
    weight: 400,
    height: 1.45,
  );
  static final TextStyle bodySmall = _style(
    family: ui,
    size: 12,
    weight: 400,
    height: 1.4,
  );

  // Label, Geist.
  static final TextStyle labelLarge = _style(
    family: ui,
    size: 14,
    weight: 600,
    height: 1.2,
    letterSpacing: 0.1,
  );
  static final TextStyle labelMedium = _style(
    family: ui,
    size: 12,
    weight: 600,
    height: 1.2,
    letterSpacing: 0.4,
  );
  static final TextStyle labelSmall = _style(
    family: ui,
    size: 11,
    weight: 600,
    height: 1.2,
    letterSpacing: 0.8,
  );

  // Numeric, GeistMono.
  // Requirement 1.8 fixes GeistMono for every monetary figure, and a monospace
  // face sets digits on a wide fixed advance. Negative tracking pulls the hero
  // figure back toward the rhythm of a proportional face so it reads as an
  // amount rather than as a code listing, without leaving the mandated family.
  static final TextStyle numericHero = _style(
    family: mono,
    size: 34,
    weight: 500,
    height: 1.08,
    letterSpacing: -1.8,
  );
  static final TextStyle numericLarge = _style(
    family: mono,
    size: 23,
    weight: 500,
    height: 1.14,
    letterSpacing: -0.6,
  );
  static final TextStyle numericMedium = _style(
    family: mono,
    size: 16,
    weight: 500,
    height: 1.2,
  );
  static final TextStyle numericSmall = _style(
    family: mono,
    size: 13,
    weight: 500,
    height: 1.2,
  );

  static TextTheme textTheme(Color primary, Color secondary) => TextTheme(
    displayLarge: displayLarge.copyWith(color: primary),
    displayMedium: displayMedium.copyWith(color: primary),
    displaySmall: headlineLarge.copyWith(color: primary),
    headlineLarge: headlineLarge.copyWith(color: primary),
    headlineMedium: headlineMedium.copyWith(color: primary),
    headlineSmall: titleLarge.copyWith(color: primary),
    titleLarge: titleLarge.copyWith(color: primary),
    titleMedium: titleMedium.copyWith(color: primary),
    titleSmall: titleSmall.copyWith(color: primary),
    bodyLarge: bodyLarge.copyWith(color: primary),
    bodyMedium: bodyMedium.copyWith(color: secondary),
    bodySmall: bodySmall.copyWith(color: secondary),
    labelLarge: labelLarge.copyWith(color: primary),
    labelMedium: labelMedium.copyWith(color: secondary),
    labelSmall: labelSmall.copyWith(color: secondary),
  );
}
