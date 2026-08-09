import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../../core/design/glass.dart';
import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import 'liquid_glass.dart';

/// Geometry of the FrostBank mark, transcribed one to one from the source SVG.
///
/// The SVG is the source of truth. Painting from these numbers keeps the mark
/// crisp at every size on Android, iOS, and the web without a rasterised asset,
/// and gives one definition for both the badged mark and the bare glyph.
///
/// ```
/// <svg viewBox="0 0 512 512">
///   <path d="M120 256H392  M170 170L342 342  M170 342L342 170"
///         stroke="#FFFFFF" stroke-width="22" stroke-linecap="square"/>
/// </svg>
/// ```
abstract final class FrostGlyphGeometry {
  static const double viewBox = 512;
  static const double centre = 256;
  static const double barNear = 120;
  static const double barFar = 392;
  static const double diagNear = 170;
  static const double diagFar = 342;
  static const double stroke = 22;

  /// Ink extent in view box units, square caps included.
  static const double inkWidth = barFar - barNear + stroke;
  static const double inkHeight = diagFar - diagNear + stroke;

  /// Height of the bare glyph as a share of its width.
  static const double aspect = inkHeight / inkWidth;

  /// Strokes the three paths. [unit] is canvas pixels per view box unit and
  /// [origin] is where view box (256, 256) lands on the canvas.
  static void stroke3(
    Canvas canvas, {
    required double unit,
    required Offset origin,
    required Color color,
  }) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke * unit
      ..strokeCap = StrokeCap.square
      ..isAntiAlias = true;

    Offset at(double x, double y) =>
        origin + Offset((x - centre) * unit, (y - centre) * unit);

    canvas.drawLine(at(barNear, centre), at(barFar, centre), paint);
    canvas.drawLine(at(diagNear, diagNear), at(diagFar, diagFar), paint);
    canvas.drawLine(at(diagNear, diagFar), at(diagFar, diagNear), paint);
  }
}

/// The FrostBank mark on its brand tile. Used wherever the logo needs to hold
/// its own against surrounding content, such as the navigation pill.
class FrostMark extends StatelessWidget {
  const FrostMark({this.size = 44, this.radiusRatio = 0.28, super.key});

  final double size;

  /// Corner radius as a share of [size]. The SVG uses 80 of 472.
  final double radiusRatio;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'FrostBank',
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _FrostMarkPainter(radiusRatio: radiusRatio)),
    ),
  );
}

/// The bare mark, no tile and no background, for surfaces that already carry the
/// brand, such as the card face.
///
/// [width] is the full ink width. Height follows [FrostGlyphGeometry.aspect], so
/// the glyph is never stretched.
class FrostGlyph extends StatelessWidget {
  const FrostGlyph({
    required this.width,
    this.color = Colors.white,
    this.excludeSemantics = false,
    super.key,
  });

  final double width;
  final Color color;

  /// Set when a parent already announces the brand.
  final bool excludeSemantics;

  @override
  Widget build(BuildContext context) {
    final painted = SizedBox(
      width: width,
      height: width * FrostGlyphGeometry.aspect,
      child: CustomPaint(painter: _FrostGlyphPainter(color: color)),
    );
    if (excludeSemantics) return ExcludeSemantics(child: painted);
    return Semantics(label: 'FrostBank', image: true, child: painted);
  }
}

class _FrostMarkPainter extends CustomPainter {
  const _FrostMarkPainter({required this.radiusRatio});

  final double radiusRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final rect = Offset.zero & Size(side, side);
    final rounded = RRect.fromRectAndRadius(
      rect,
      Radius.circular(side * radiusRatio),
    );

    canvas.save();
    canvas.clipRRect(rounded);
    FrostGradients.paintLayers(canvas, rect);
    canvas.restore();

    FrostGlyphGeometry.stroke3(
      canvas,
      unit: side / FrostGlyphGeometry.viewBox,
      origin: rect.center,
      color: Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _FrostMarkPainter oldDelegate) =>
      oldDelegate.radiusRatio != radiusRatio;
}

class _FrostGlyphPainter extends CustomPainter {
  const _FrostGlyphPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    FrostGlyphGeometry.stroke3(
      canvas,
      unit: size.width / FrostGlyphGeometry.inkWidth,
      origin: Offset(size.width / 2, size.height / 2),
      color: color,
    );
  }

  @override
  bool shouldRepaint(covariant _FrostGlyphPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// The layered gradient recipe shared by the mark and every brand surface.
abstract final class FrostGradients {
  /// Draws the recipe into [rect].
  ///
  /// The five shaders are built once per geometry and then reused. This matters
  /// more here than anywhere else in the application: [FrostBackdrop] is the root
  /// of fourteen screens, so these are five full screen fills, and building a
  /// `ui.Gradient` allocates a native object every time. The recipe is a pure
  /// function of the rectangle and the glow, so anything that repaints the
  /// backdrop at the same size was rebuilding five identical shaders per frame.
  static void paintLayers(Canvas canvas, Rect rect, {double glow = 1}) {
    if (rect.isEmpty || rect.width <= 0 || rect.height <= 0) return;
    for (final layer in _layersFor(rect, glow)) {
      canvas.drawRect(rect, layer);
    }
  }

  /// Cached layers, most recently used last.
  ///
  /// A list rather than a single entry because the mark and the backdrop paint at
  /// different sizes in the same frame, and a one deep cache would thrash between
  /// them. Small and bounded: the application has a handful of distinct backdrop
  /// geometries at any moment, and the entries are shaders, not images.
  static final List<_FrostLayers> _cache = <_FrostLayers>[];

  static const int _cacheLimit = 8;

  static List<Paint> _layersFor(Rect rect, double glow) {
    for (var index = _cache.length - 1; index >= 0; index--) {
      final entry = _cache[index];
      if (entry.rect == rect && entry.glow == glow) return entry.paints;
    }

    final paints = _buildLayers(rect, glow);
    _cache.add(_FrostLayers(rect, glow, paints));
    if (_cache.length > _cacheLimit) _cache.removeAt(0);
    return paints;
  }

  static List<Paint> _buildLayers(Rect rect, double glow) {
    final layers = <Paint>[
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Palette.frostBaseTop, Palette.frostBaseBottom],
        ).createShader(rect),
    ];

    final reach = math.max(rect.width, rect.height);
    if (reach <= 0) return layers;

    // Bottom left icy bloom, the signal colour of the brand.
    _radial(
      layers,
      rect,
      center: Offset(
        rect.left + rect.width * 0.12,
        rect.top + rect.height * 0.9,
      ),
      radius: reach * 0.78,
      stops: const [0, 0.18, 0.35, 0.58, 1],
      colors: [
        Palette.frostIceWhite.withValues(alpha: glow),
        Palette.frostIcePale.withValues(alpha: 0.94 * glow),
        Palette.skyBlue.withValues(alpha: 0.86 * glow),
        Palette.frostIceBlue.withValues(alpha: 0.62 * glow),
        Palette.frostIceBlue.withValues(alpha: 0),
      ],
    );

    // Top right cool light.
    _radial(
      layers,
      rect,
      center: Offset(
        rect.left + rect.width * 0.96,
        rect.top + rect.height * 0.04,
      ),
      radius: reach * 0.72,
      stops: const [0, 0.25, 0.6, 1],
      colors: [
        Palette.skyBlue.withValues(alpha: 0.92 * glow),
        Palette.frostPeriwinkle.withValues(alpha: 0.72 * glow),
        Palette.frostViolet.withValues(alpha: 0.38 * glow),
        Palette.frostViolet.withValues(alpha: 0),
      ],
    );

    // Deep violet shadow that keeps the right side from going flat.
    _radial(
      layers,
      rect,
      center: Offset(
        rect.left + rect.width * 0.9,
        rect.top + rect.height * 0.35,
      ),
      radius: reach * 0.6,
      stops: const [0, 0.4, 1],
      colors: [
        Palette.frostInk.withValues(alpha: 0.55),
        Palette.frostPurple.withValues(alpha: 0.32),
        Palette.frostPurple.withValues(alpha: 0),
      ],
    );

    // Centre lift.
    _radial(
      layers,
      rect,
      center: rect.center,
      radius: reach * 0.46,
      stops: const [0, 1],
      colors: [
        Palette.frostLift.withValues(alpha: 0.8 * glow),
        Palette.frostLift.withValues(alpha: 0),
      ],
    );

    return layers;
  }

  static void _radial(
    List<Paint> layers,
    Rect rect, {
    required Offset center,
    required double radius,
    required List<double> stops,
    required List<Color> colors,
  }) {
    if (radius <= 0 || radius.isNaN || radius.isInfinite) return;
    layers.add(
      Paint()..shader = ui.Gradient.radial(center, radius, colors, stops),
    );
  }
}

/// One geometry's worth of built layers.
class _FrostLayers {
  const _FrostLayers(this.rect, this.glow, this.paints);

  final Rect rect;
  final double glow;
  final List<Paint> paints;
}

/// Brand backdrop for the splash, the sign in screen, and the dashboard header.
///
/// [glow] pulls the icy bloom back so body text keeps its contrast on large
/// surfaces, where a full strength bloom would wash the type out.
class FrostBackdrop extends StatelessWidget {
  const FrostBackdrop({
    required this.child,
    this.borderRadius,
    this.glow = 0.34,
    super.key,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final double glow;

  @override
  Widget build(BuildContext context) {
    // The backdrop is a sibling of the content behind it rather than a painter
    // wrapped around it, and both halves get their own layer.
    //
    // The recipe is five fills the size of the screen and this widget is the root
    // of fourteen screens, so it is the largest single piece of painting in the
    // application. As one CustomPaint with the content as its child, the two
    // shared a layer: anything that repainted in the content - a scroll frame, an
    // entrance animation, a glass pane resolving - redrew all five fills
    // underneath it, every frame. Split apart, the content repaints on its own,
    // and the backdrop's raster is a candidate for the raster cache because it is
    // a leaf that only changes when its size or its glow does.
    //
    // StackFit.passthrough is load bearing: it hands the parent's constraints to
    // the content unchanged, which is what the CustomPaint used to do. Under the
    // default loose fit, a screen whose content expands to fill the viewport would
    // collapse to its intrinsic height instead.
    final surface = Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: _BackdropPainter(glow: glow)),
          ),
        ),
        RepaintBoundary(child: child),
      ],
    );
    if (borderRadius == null) return surface;
    return ClipRRect(borderRadius: borderRadius!, child: surface);
  }
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter({required this.glow});

  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || size.width <= 0 || size.height <= 0) return;
    FrostGradients.paintLayers(canvas, Offset.zero & size, glow: glow);
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter oldDelegate) =>
      oldDelegate.glow != glow;
}

/// Mark plus wordmark lockup.
class FrostLockup extends StatelessWidget {
  const FrostLockup({this.markSize = 40, this.onBrand = true, super.key});

  final double markSize;
  final bool onBrand;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      label: 'FrostBank',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FrostMark(size: markSize),
            SizedBox(width: markSize * 0.3),
            Text(
              'FrostBank',
              style: AppType.headlineMedium.copyWith(
                fontSize: markSize * 0.52,
                color: onBrand ? Colors.white : tokens.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Frosted glass surface used on brand backdrops.
///
/// The same material as the application chrome, at the panel tier: see [Glass]
/// for what the tiers change and why. It used to be a flat sigma 16
/// [BackdropFilter] with a white fill and a white border, which meant the
/// interface was made of two visibly different glasses depending on whether you
/// were looking at a card or at the navigation bar. It is now one.
///
/// Reduced transparency is handled by [LiquidGlass] itself, which collapses to an
/// opaque fill.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(Space.x5),
    this.radius = AppRadius.xl,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: LiquidGlass(
      radius: radius,
      recipe: Glass.panelOf(context),
      child: Padding(padding: padding, child: child),
    ),
  );
}

/// Small frosted control on a brand backdrop, sized for a 48 pixel target.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Unread count rendered on the control. Zero renders no badge.
  ///
  /// Requirement 12.16 asks for a count rather than a dot, and requirement 25.4
  /// requires the indicator to be bound to a real value, so this is a number
  /// from the repository and never a literal true.
  final int badgeCount;

  bool get _hasBadge => badgeCount > 0;

  /// Counts above 9 read as `9+`, so the badge never outgrows the control.
  String get _badgeText => badgeCount > 9 ? '9+' : '$badgeCount';

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    // The count is spoken as part of the name, so a screen reader hears how many
    // are waiting rather than only that something is.
    label: _hasBadge ? '$label, $badgeCount unread' : label,
    child: ExcludeSemantics(
      child: SizedBox.square(
        dimension: Layout.minTapTarget,
        child: LiquidGlass(
          radius: AppRadius.md,
          // Always the dark recipe. This control only ever sits on the brand
          // backdrop, in both themes, so a pane that followed the platform
          // brightness would turn pale and disappear into a navy gradient.
          recipe: Glass.dark.panel,
          // Feedback: the pane gives under the finger and springs back, which is
          // the one thing a piece of glass does that a tinted rectangle cannot.
          // The lens allocates nothing for this until the first touch.
          flex: const LiquidGlassFlex.subtle(),
          child: Material(
            // The pane is the surface now, so the Material is here only to host
            // the ink response. The theme sets NoSplash, so nothing is drawn.
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              // Expanded on purpose. The pane takes its size from the box above
              // it, but inside the pane the content is what measures, so without
              // this the whole control collapses to the width of the glyph and
              // stops being a 48 pixel target.
              child: SizedBox.expand(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(icon, color: Colors.white, size: 20),
                    if (_hasBadge)
                      Positioned(
                        top: 6,
                        right: 4,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 16),
                          height: 16,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: Palette.frostIceBlue,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(
                              color: Palette.frostBaseTop,
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _badgeText,
                            style: AppType.labelSmall.copyWith(
                              color: Palette.frostBaseTop,
                              fontSize: 10,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Text field for brand backdrops.
///
/// The entered value is explicitly white here, because these fields sit on the
/// dark brand surface in both light and dark mode.
class FrostField extends StatelessWidget {
  const FrostField({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.prefix,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
    this.inputFormatters,
    this.maxLength,
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final Widget? prefix;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
    );

    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      autofillHints: autofillHints,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      cursorColor: Colors.white,
      style: AppType.bodyLarge.copyWith(color: Colors.white),
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: AppType.bodyMedium.copyWith(
          color: Colors.white.withValues(alpha: 0.56),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.1),
        prefixIcon: prefix,
        suffixIcon: suffix,
        suffixIconColor: Colors.white.withValues(alpha: 0.72),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.x4,
          vertical: Space.x4,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: Palette.frostIcePale, width: 2),
        ),
      ),
    );
  }
}

/// Field label used above every brand surface input.
class FrostFieldLabel extends StatelessWidget {
  const FrostFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.x2),
    child: Text(
      text,
      style: AppType.labelMedium.copyWith(
        color: Colors.white.withValues(alpha: 0.78),
      ),
    ),
  );
}

/// Payment card face. Built on the Card gradient token, with a navy scrim and a
/// single sheen so the surface reads as cold metal rather than neon.
class FrostCardSurface extends StatelessWidget {
  const FrostCardSurface({
    required this.child,
    this.radius = AppRadius.xl,
    this.padding = const EdgeInsets.all(Space.x5),
    super.key,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final border = BorderRadius.circular(radius);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: border,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: tokens.gradientCard,
        ),
        boxShadow: [
          BoxShadow(
            color: Palette.frostInk.withValues(alpha: 0.3),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: border,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: const [0, 0.62, 1],
                    colors: [
                      Palette.frostBaseTop.withValues(alpha: 0.94),
                      Palette.frostLift.withValues(alpha: 0.52),
                      Palette.frostIceBlue.withValues(alpha: 0.1),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -60,
              right: -40,
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Palette.frostIcePale.withValues(alpha: 0.34),
                      Palette.frostIcePale.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: border,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

/// Card and tile surface for the light content sheet. Uses soft tinted
/// elevation instead of a hard one pixel border.
class SoftCard extends StatelessWidget {
  const SoftCard({
    required this.child,
    this.padding = const EdgeInsets.all(Space.x4),
    this.radius = AppRadius.lg,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surfaceRaised,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: tokens.isDark
              ? tokens.border
              : tokens.border.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: tokens.shadow,
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
