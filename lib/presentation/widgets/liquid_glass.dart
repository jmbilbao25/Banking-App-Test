import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../core/design/glass.dart';

/// A refracting glass pane for chrome that floats over scrolling content.
///
/// This is the app shell surface. It differs from `GlassPanel` in `brand.dart`
/// on purpose: `GlassPanel` is a flat frosted card that sits on the brand
/// backdrop, where the colour behind it is known and fixed. [LiquidGlass] sits
/// over live, moving, unknown content, so it carries the layers that make an
/// edge readable against anything. See [Glass] for the layer order.
///
/// The refraction is one [BackdropFilter] laid out larger than the pane and
/// scaled back down onto it. The layer therefore covers the pane exactly, but its
/// local space is wider and taller, and that mismatch offsets the backdrop it
/// samples. Because the offset is a scale about the centre, it is zero in the
/// middle of the pane and grows toward the rim on its own, which is the way a
/// thick lens bends light.
///
/// Nothing inside the pane is clipped. An earlier version built the bezel from
/// concentric rings, each with its own filter, and the boundaries between them
/// read as a second solid shape sitting inside the glass. One continuous pass
/// cannot produce that seam.
///
/// Collapses to a single opaque fill when the platform asks for reduced
/// transparency, so the chrome never becomes unreadable.
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    required this.child,
    required this.borderRadius,
    this.recipe,
    this.bloomAlignment = const Alignment(-0.7, -1),
    super.key,
  });

  final Widget child;
  final BorderRadius borderRadius;

  /// Overrides the brightness resolved recipe. Rarely needed.
  final Glass? recipe;

  /// Where the implied light source sits, in the pane's own coordinates.
  final Alignment bloomAlignment;

  @override
  Widget build(BuildContext context) {
    final glass = recipe ?? Glass.of(context);

    if (Glass.isReduced(context)) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: glass.fallback,
          borderRadius: borderRadius,
          border: Border.all(color: glass.rimDim),
          boxShadow: [
            BoxShadow(
              color: glass.shadow,
              blurRadius: glass.shadowBlur,
              offset: glass.shadowOffset,
            ),
          ],
        ),
        child: child,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: glass.shadow,
            blurRadius: glass.shadowBlur,
            offset: glass.shadowOffset,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _Refraction(glass: glass),

            IgnorePointer(
              child: CustomPaint(
                painter: _GlassBodyPainter(
                  glass: glass,
                  bloomAlignment: bloomAlignment,
                ),
                child: const SizedBox.expand(),
              ),
            ),

            child,

            // Over the content, so a glyph parked against the edge cannot
            // swallow the rim.
            IgnorePointer(
              child: CustomPaint(
                painter: _GlassRimPainter(
                  glass: glass,
                  borderRadius: borderRadius,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The single refraction pass.
class _Refraction extends StatelessWidget {
  const _Refraction({required this.glass});

  final Glass glass;

  @override
  Widget build(BuildContext context) => Transform(
    transform: Matrix4.diagonal3Values(glass.lensX, glass.lensY, 1),
    alignment: Alignment.center,
    child: FractionallySizedBox(
      widthFactor: 1 / glass.lensX,
      heightFactor: 1 / glass.lensY,
      // A blur is the most expensive operation on this screen, and without its
      // own layer it is re-rasterised whenever anything in the enclosing repaint
      // region changes. The boundary confines that cost to the pane itself.
      child: RepaintBoundary(
        child: BackdropFilter(
          filter: glass.filter,
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
}

class _GlassBodyPainter extends CustomPainter {
  const _GlassBodyPainter({required this.glass, required this.bloomAlignment});

  final Glass glass;
  final Alignment bloomAlignment;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    void wash(List<Color> colors) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(
            rect.topCenter,
            rect.bottomCenter,
            colors,
          ),
      );
    }

    wash(glass.scrim);
    wash(glass.lift);

    // Implied light source.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          bloomAlignment.withinRect(rect),
          size.longestSide * 0.6,
          [glass.bloom, glass.bloom.withValues(alpha: 0)],
          const [0, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _GlassBodyPainter old) =>
      old.glass != glass || old.bloomAlignment != bloomAlignment;
}

/// The lit edge of the pane, and the reflections on its face.
///
/// Five strokes and one band, in order:
///
///   1. the outer rim, graded from the top highlight through the grazing side
///      colour to the bottom bounce. This grading is what reads as a lit glass
///      edge rather than a drawn border
///   2. a concentrated arc at the top left, where the light source sits
///   3. a second, weaker arc at the bottom right, light bouncing back up
///   4. an inner hairline that fades out by the vertical midpoint, which gives
///      the pane implied thickness
///   5. a diagonal sheen across the upper half, the reflection of the room
class _GlassRimPainter extends CustomPainter {
  const _GlassRimPainter({required this.glass, required this.borderRadius});

  final Glass glass;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shape = borderRadius.toRRect(rect);

    canvas.drawRRect(
      shape.deflate(0.6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          [glass.rimTop, glass.rimDim, glass.rimBottom],
          const [0, 0.55, 1],
        ),
    );

    canvas.save();
    canvas.clipRRect(shape);

    void arc({
      required Offset from,
      required Offset to,
      required double width,
      required Color color,
    }) {
      canvas.drawRRect(
        shape.deflate(0.6),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..maskFilter = const MaskFilter.blur(ui.BlurStyle.normal, 2.5)
          ..shader = ui.Gradient.linear(from, to, [
            color,
            color.withValues(alpha: 0),
          ]),
      );
    }

    arc(
      from: rect.topLeft,
      to: Offset(rect.width * 0.5, rect.top),
      width: 3,
      color: glass.rimTop,
    );
    arc(
      from: rect.bottomRight,
      to: Offset(rect.width * 0.55, rect.bottom),
      width: 2.4,
      color: glass.rimBottom,
    );

    final inner = glass.rimTop.withValues(alpha: glass.rimTop.a * 0.3);
    canvas.drawRRect(
      shape.deflate(2.4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.center,
          [inner, inner.withValues(alpha: 0)],
          const [0, 1],
        ),
    );

    // Reflection of the room. Narrow, off axis, and fading at both ends, so it
    // reads as light on a curved face rather than a stripe.
    final transparent = glass.sheen.withValues(alpha: 0);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topLeft,
          Offset(rect.width * 0.62, rect.bottom),
          [
            transparent,
            glass.sheen.withValues(alpha: glass.sheen.a * 0.35),
            glass.sheen,
            transparent,
          ],
          const [0.04, 0.13, 0.2, 0.36],
        ),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlassRimPainter old) =>
      old.glass != glass || old.borderRadius != borderRadius;
}
