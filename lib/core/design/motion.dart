import 'package:flutter/material.dart';

/// The single motion system.
///
/// Four duration bands, four curves, and only opacity, translation, scale, and
/// rotation are ever animated.
abstract final class Motion {
  /// Touch response. The frame the finger lands on.
  static const Duration instant = Duration(milliseconds: 110);

  /// Press release and state feedback.
  static const Duration short = Duration(milliseconds: 180);

  /// Screen and section transitions.
  static const Duration medium = Duration(milliseconds: 300);

  /// Entrances that carry distance, and the splash sequence.
  static const Duration long = Duration(milliseconds: 560);

  /// Gap between two neighbours in a staggered entrance.
  static const Duration staggerStep = Duration(milliseconds: 55);

  /// Entrances stop staggering past this many items, so a long list never
  /// leaves its tail waiting.
  static const int staggerCap = 8;

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutQuart;

  /// Overshoot for surfaces that arrive under their own weight. Kept shallow so
  /// figures never appear to wobble.
  static const Curve settle = Curves.easeOutBack;

  static const Curve linear = Curves.linear;

  /// True when the platform asks for less animation.
  ///
  /// Reads the two flags as aspects rather than taking the whole
  /// [MediaQueryData]. `MediaQuery.maybeOf` subscribes the calling widget to
  /// every field on the data, so a widget asking only whether animation is
  /// wanted was also rebuilding on any change to the size, the padding, the text
  /// scale, or the view insets. The insets are the expensive one: they change on
  /// every frame of the keyboard opening, and this is called from
  /// [resolve], [stagger] and [amount] all over the tree - so raising the
  /// keyboard on a form rebuilt every animated widget and every glass pane on
  /// the screen, sixty times a second, to answer a question whose answer had not
  /// changed. As aspects, these rebuild only when the flags themselves flip.
  static bool isReduced(BuildContext context) =>
      (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ||
      (MediaQuery.maybeAccessibleNavigationOf(context) ?? false);

  /// Collapses a duration to zero under reduced motion so transitions render
  /// their end state immediately.
  static Duration resolve(BuildContext context, Duration duration) =>
      isReduced(context) ? Duration.zero : duration;

  /// Delay for the item at [index] in a staggered entrance.
  static Duration stagger(BuildContext context, int index) => isReduced(context)
      ? Duration.zero
      : staggerStep * index.clamp(0, staggerCap);

  /// Scales a rotation, translation, or parallax amount to zero under reduced
  /// motion, so a transform driven by a gesture flattens instead of vanishing.
  static double amount(BuildContext context, double value) =>
      isReduced(context) ? 0 : value;
}
