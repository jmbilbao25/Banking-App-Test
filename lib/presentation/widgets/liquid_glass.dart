import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../../core/design/glass.dart';

/// A refracting glass pane.
///
/// This is the one glass surface in the application. Chrome that floats over
/// scrolling content and cards that sit on the brand backdrop are the same
/// material at two tiers, resolved through [Glass.of] and [Glass.panelOf]; see
/// [Glass] for the layer order and for why the tiers differ.
///
/// The refraction is a real lens. The backdrop is sampled against a signed
/// distance field of this pane's own shape, so the displacement is concentrated
/// in a band that hugs the edge and the middle of the pane stays close to
/// undistorted. An earlier version approximated it by laying a [BackdropFilter]
/// out larger than the pane and scaling it back down. That bends light in
/// proportion to distance from the centre, which is the wrong shape entirely: it
/// reads as a squashed photograph behind a grey sheet rather than as an edge
/// bending light, and no amount of blur or tint recovers it.
///
/// On Impeller the lens samples the live backdrop with no setup. On Skia and on
/// the web there is no live backdrop shader, so the lens degrades to a frosted
/// blur and tint and the pane keeps its washes, its rim and its sheen. That
/// degradation is also what lets the widget tests and the golden suite render it.
///
/// Collapses to a single opaque fill when the platform asks for reduced
/// transparency, so the interface never becomes unreadable.
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    required this.child,
    required this.radius,
    this.recipe,
    this.bloomAlignment = const Alignment(-0.7, -1),
    this.flex,
    super.key,
  });

  final Widget child;

  /// Corner radius of the pane. A single value rather than a [BorderRadius],
  /// because the lens shape is described by one radius and every surface in the
  /// application is uniformly rounded. Keeping them the same shape is the point:
  /// a clip that disagrees with the shader leaves a visible seam at the corner.
  final double radius;

  /// Overrides the tier resolved from brightness. Rarely needed.
  final Glass? recipe;

  /// Where the implied light source sits, in the pane's own coordinates.
  final Alignment bloomAlignment;

  /// Deformation under a finger, if this pane should answer touch directly.
  ///
  /// Null by default, and null costs nothing: no listener and no ticker are
  /// added to the tree. Only set it on a pane with bounded constraints. The lens
  /// measures its rest size from `constraints.biggest` in order to deform
  /// against it, so a pane that sizes itself from its child would expand to fill
  /// its parent the moment this is non null.
  final LiquidGlassFlex? flex;

  @override
  Widget build(BuildContext context) {
    final glass = recipe ?? Glass.of(context);
    final border = BorderRadius.circular(radius);

    if (Glass.isReduced(context)) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: glass.fallback,
          borderRadius: border,
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
        borderRadius: border,
        boxShadow: [
          BoxShadow(
            color: glass.shadow,
            blurRadius: glass.shadowBlur,
            offset: glass.shadowOffset,
          ),
        ],
      ),
      // The lens clips its own child to the lens shape, so there is no
      // ClipRRect here. One shape, described once.
      child: LiquidGlassLens(
        style: LiquidGlassStyle(
          shape: LiquidGlassShape.continuousRoundedRectangle(
            cornerRadius: radius,
            lightColor: glass.rimTop,
            // See [Glass.rimLightDirection]. Left at the shader's default of 0 -
            // light from the right - until a round spent looking for why a pane
            // with defensible numbers still read as artificial.
            lightDirection: glass.rimLightDirection,
            borderWidth: glass.rimWidth,
            // Radial rather than the default edge mode. Edge mode takes the
            // surface normal from the shape's own gradient, which spreads the
            // highlight along a straight edge; radial takes it from the centre
            // outward, which carries the highlight around a curve instead. On a
            // stadium the straight edges are most of the perimeter and the caps
            // are where the eye looks for the glass to be thick, so the mode that
            // lights curves is the right one here.
            lightMode: LiquidGlassLightMode.radial,
            // Gain on the specular rim. The rim is where nearly all of the sense
            // of a lit, solid edge comes from, so it is worth pushing slightly
            // past unity.
            lightIntensity: glass.rimIntensity,
            // The rim is the shader's, not a painter's, and that is the upgrade.
            // A painted rim can only ever be the colour it was written as. This
            // one takes its colour from whatever is currently behind the pane,
            // which is what an edge of real glass does.
            borderType: OpticalBorder(
              // Above one, so the cold blues the brand backdrop is made of come
              // back saturated at the rim instead of washing to white.
              borderSaturation: glass.rimSaturation,
              // Keeps the rim lit on the side facing away from the light, so the
              // pane never loses an edge against a dark backdrop.
              // See [Glass.rimAmbient]. Above unity here is what made the rim
              // an outline rather than a light.
              ambientIntensity: glass.rimAmbient,
              // See [Glass.rimSolidity]. This was pinned at zero on the argument
              // that a solid rim is a border; at zero the rim never resolves into
              // a line at all and the pane loses its edge.
              borderSolidity: glass.rimSolidity,
              lightSpread: glass.rimSpread,
            ),
          ),
          appearance: LiquidGlassAppearance(
            saturation: glass.saturation,
            blur: LiquidGlassBlur(sigmaX: glass.blur, sigmaY: glass.blur),
            // The tint is the scrim and lift pair below, not a flat fill. One
            // fill cannot both hold the pane under bright content and lift it
            // above dark content.
            color: const Color(0x00000000),
          ),
          refraction: LiquidGlassRefraction(
            magnification: glass.lensZoom,
            chromaticAberration: glass.lensAberration,
            // Follows the contour of the shape rather than a circle centred on
            // the pane. On a stadium 68 pixels tall a radial pattern bends the
            // end caps and leaves the long edges flat.
            refractionMode: LiquidGlassRefractionMode.shapeRefraction,
            // Snell's law through a bevelled edge, rather than the legacy
            // anchor-based displacement this used to drive through `distortion`
            // and `distortionWidth`. See [Glass.lensIor]: the legacy path cannot
            // separate how hard it bends from how wide it bends, so the only
            // setting that did not mangle small text was one narrow enough to do
            // nothing measurable at all.
            refractionType: OpticalRefraction(
              refraction: glass.lensIor,
              refractionWidth: glass.lensBevel,
              depth: glass.lensDepth,
            ),
          ),
        ),
        touch: flex == null ? null : LiquidGlassTouch(flex: flex),
        // The washes and the sheen are Positioned.fill rather than a
        // StackFit.expand, so the only child that measures is the content. That
        // is what lets one pane serve both a bar with a fixed height and a card
        // that has to size itself to what is inside it.
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _GlassBodyPainter(
                    glass: glass,
                    bloomAlignment: bloomAlignment,
                  ),
                ),
              ),
            ),

            child,

            // Over the content, so a glyph parked against the edge cannot
            // swallow the reflection.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _GlassSheenPainter(
                    glass: glass,
                    borderRadius: border,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
    //
    // Scaled from the shortest side, not the longest. A specular bloom is a
    // property of how thick the pane is, not how long, and reading it off the
    // longest side put a 210 pixel radial on a bar 68 pixels tall: the highlight
    // covered the whole pane and flattened it to a grey ramp, which is most of
    // what made the old bar read as a slab. Off the shortest side it stays a
    // highlight near the corner the light comes from, and it still opens up to
    // roughly its old size on a surface that is nearer square.
    // 1.15 rather than 1.6. Even off the shortest side, 1.6 put the falloff
    // beyond the far edge of a 68 pixel bar, so the whole pane sat inside the
    // bloom and read as an even ramp. A highlight has to end somewhere inside the
    // surface to be read as a highlight.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          bloomAlignment.withinRect(rect),
          size.shortestSide * 1.15,
          [glass.bloom, glass.bloom.withValues(alpha: 0)],
          const [0, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _GlassBodyPainter old) =>
      old.glass != glass || old.bloomAlignment != bloomAlignment;
}

/// What is left for a painter once the shader owns the rim.
///
/// Two marks, both of which describe the *face* of the pane rather than its edge:
///
///   1. an inner hairline that fades out by the vertical midpoint, which gives
///      the pane implied thickness behind its own rim
///   2. a diagonal sheen across the upper half, the reflection of the room
///
/// An earlier version also painted the outer rim and two blurred corner arcs.
/// Those are now the shader's optical border, which can do the one thing a
/// painter cannot: tint itself from the backdrop. Painting both left a doubled
/// edge, and dropping them takes this from five strokes and a band down to one
/// stroke and a band.
class _GlassSheenPainter extends CustomPainter {
  const _GlassSheenPainter({required this.glass, required this.borderRadius});

  final Glass glass;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shape = borderRadius.toRRect(rect);

    canvas.save();
    canvas.clipRRect(shape);

    // The inner hairline is gone, and it is worth recording why, because it was
    // defended twice in this file.
    //
    // It was a one pixel stroke on `shape.deflate(2.4)`, fading out by the vertical
    // midpoint, and the argument for it was that it gave the pane implied thickness
    // behind its own rim. Last round it was switched from a faded specular white to
    // [Glass.rimDim] so that the light tier would have an edge over a white sheet,
    // which made it stronger.
    //
    // Two reviewers then measured it independently, without knowing what it was,
    // and both called it a defect. It sat 6 device pixels inside the true edge, ran
    // at a constant amplitude across the entire span of the pane, and existed only
    // along the top with no counterpart along the bottom. That constancy along x is
    // the tell: an optical event on a stadium varies as the surface turns, and this
    // did not vary at all, because it was a stroke. One reviewer called it "a
    // scratch dragged across the customer's transaction list", and once named it is
    // impossible to unsee - a straight bright rule crossing the middle of a
    // merchant's name.
    //
    // Nothing replaces it. The shader's optical border draws the actual edge now,
    // with a real width and a light direction, and implied thickness is what the
    // bevel in [Glass.lensBevel] is for: a lens that bends light near its rim
    // *shows* its thickness instead of having a line drawn where the thickness
    // would be. The light tier's edge problem was real, and it is solved where it
    // belonged - in the pane's own tint, which no longer lifts itself brighter than
    // the sheet it floats on.

    // Reflection of the room. Narrow, off axis, and fading at both ends, so it
    // reads as light on a curved face rather than a stripe.
    //
    // Half the width and half the strength it carried when this painter also drew
    // the outer rim and two corner arcs. Those balanced it. On their own against
    // the shader's rim it stopped reading as a reflection and started reading as
    // a grey wedge smeared across the corner, which is the exact failure the
    // whole change was meant to remove.
    final transparent = glass.sheen.withValues(alpha: 0);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topLeft,
          Offset(rect.width * 0.62, rect.bottom),
          [
            transparent,
            glass.sheen.withValues(alpha: glass.sheen.a * 0.16),
            glass.sheen.withValues(alpha: glass.sheen.a * 0.48),
            transparent,
          ],
          const [0.03, 0.08, 0.13, 0.24],
        ),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlassSheenPainter old) =>
      old.glass != glass || old.borderRadius != borderRadius;
}
