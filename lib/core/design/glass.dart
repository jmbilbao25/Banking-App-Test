import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// Layer recipe for the liquid glass surfaces that carry the interface.
///
/// Apple documents Liquid Glass for Apple platforms only. There is no official
/// cross platform implementation, so this is an approximation, assembled from
/// five layers always painted in the same order:
///
///   1. refraction  a real lens pass. The backdrop is sampled against a signed
///                  distance field of the pane's own shape, so the displacement
///                  is concentrated in a narrow band hugging the edge while the
///                  middle stays close to undistorted. This is the layer that
///                  separates glass from a blurred rectangle, and an even scale
///                  cannot stand in for it: scaling bends light in proportion to
///                  distance from the centre, which reads as a squashed
///                  photograph behind a sheet rather than as a lens
///   2. scrim       a thin dark wash that stops bright content behind the pane
///                  from blowing out the glyphs
///   3. lift        a brighter wash that keeps the pane visible over dark content
///   4. specular    the shader's own rim light, plus a diagonal sheen and an
///                  inner hairline painted over the content. The rim is where
///                  most of the sense of a lit, solid edge comes from
///   5. shadow      outer separation, tinted toward the brand navy
///
/// Refraction is a single pass covering the whole pane, never a stack of inset
/// bands. Bands need hard clips between them, and any hard clip inside the pane
/// reads as a second solid shape sitting inside the glass.
///
/// Scrim and lift are two passes rather than one tint on purpose. A single
/// translucent fill can either lift the pane above a dark backdrop or hold it
/// under a bright one, never both, and interface surfaces have to sit over both.
///
/// The two brightnesses invert the material rather than sharing it: dark mode is
/// dark glass carrying white glyphs, light mode is pale frosted glass carrying
/// ink glyphs. That is what keeps the pane readable while staying see through,
/// and it is how system chrome behaves.
///
/// Two tiers, from one set of colours. [Glass.of] is the chrome tier, for panes
/// that float over live, moving, unknown content. [Glass.panelOf] is the panel
/// tier, for cards that sit on the brand backdrop, where the colour behind is
/// known: it keeps the same rim and sheen but pulls the washes back, because a
/// pane milky enough to survive a white scrolling list reads as a white slab
/// when it is laid on a navy gradient instead.
@immutable
class Glass {
  const Glass({
    required this.blur,
    required this.saturation,
    required this.lensIor,
    required this.lensBevel,
    required this.lensDepth,
    required this.lensZoom,
    required this.lensAberration,
    required this.rimLightDirection,
    required this.rimWidth,
    required this.rimSpread,
    required this.rimAmbient,
    required this.scrim,
    required this.lift,
    required this.bloom,
    required this.rimTop,
    required this.rimBottom,
    required this.rimDim,
    required this.rimSolidity,
    required this.rimIntensity,
    required this.rimSaturation,
    required this.sheen,
    required this.shadow,
    required this.shadowBlur,
    required this.shadowOffset,
    required this.fallback,
    required this.onGlass,
    required this.onGlassMuted,
    required this.glyphShadow,
    required this.indicator,
    required this.indicatorRim,
  });

  /// Blur sigma applied to the refracted backdrop, on both axes.
  ///
  /// Deliberately low. A heavy blur erases the very displacement that makes the
  /// pane read as glass, and leaves a grey slab.
  final double blur;

  /// Saturation multiplier applied to the refracted backdrop, so colour behind
  /// the pane still reads as colour rather than grey.
  final double saturation;

  /// Refractive index of the glass, fed to Snell's law.
  ///
  /// These three fields - [lensIor], [lensBevel], [lensDepth] - drive the
  /// shader's *physical* refraction path, and getting onto that path was the
  /// change this material needed most. The package exposes two calculations. The
  /// legacy one displaces each sample toward an anchor point inset from the edge,
  /// with one dial that is both the amplitude and, in effect, the shape of the
  /// ramp. The physical one lifts the pane's 2D distance field into a 3D surface
  /// normal - flat facing the viewer deep inside the glass, tilting outward
  /// through a bevel at the rim - and bends the incident ray through it with
  /// `refract()`.
  ///
  /// Everything that went wrong for three rounds was a property of the legacy
  /// path. Its displacement is not monotonic, so the pane could show the same
  /// word twice or, at small amplitudes, sample the blank gap between two rows
  /// and show nothing at all. And because amplitude and band width were welded
  /// together, the only way to stop it mangling 12 pixel type was to shrink the
  /// band until it did nothing - which is what shipped, and which measured as a
  /// pane with a median displacement of exactly zero across its whole area. It
  /// was legible because it had stopped being a lens.
  ///
  /// The physical path separates the two. A wide bevel with a small depth is a
  /// gentle, monotonic warp across the whole pane, which is what glass does and
  /// what the legacy path could not express at any setting.
  ///
  /// 1.0 does not bend at all and common glass is about 1.5. Snell's law
  /// saturates, so past roughly 2.0 the ray is already fully bent and this stops
  /// doing anything; [lensDepth] is the dial to reach for instead.
  final double lensIor;

  /// Width of the bevel at the rim, in logical pixels: how far in from the edge
  /// the surface ramps from facing the viewer to facing sideways.
  ///
  /// This is a shape, not a strength. Widening it moves the bend further into the
  /// pane without making it any stronger, which is the decoupling the legacy path
  /// did not offer. See [lensIor].
  final double lensBevel;

  /// How far the refracted ray travels, from 0 to 1: the strength dial.
  ///
  /// The shader's displacement works out to roughly `bevel * depth * 5`, so this
  /// is read against [lensBevel] rather than on its own.
  final double lensDepth;

  /// Magnification of content seen through the pane. Barely above one: a lens
  /// this thin should bend light without visibly enlarging what is behind it.
  final double lensZoom;

  /// Colour separation at the rim. Small, but it is the difference between an
  /// edge that looks drawn and an edge that looks refracted.
  final double lensAberration;

  /// Dark wash, top to bottom.
  final List<Color> scrim;

  /// Bright wash, top to bottom.
  final List<Color> lift;

  /// Lens light in the upper left corner.
  final Color bloom;

  /// Rim along the top edge, the primary highlight.
  final Color rimTop;

  /// Rim along the bottom edge, the bounce highlight.
  final Color rimBottom;

  /// Rim along the sides, where light only grazes.
  final Color rimDim;

  /// How far the shader's optical border may push its rim toward opaque, from 0
  /// to 1.
  ///
  /// This was 0, on the argument that a solid rim is a border and a border is
  /// what the surface is trying not to be. That argument was wrong about what it
  /// was buying. At 0 the rim never resolves into a line, so the pane has no
  /// edge, and a pane with no edge is not glass, it is a wash. Every reference
  /// implementation of this material runs the rim near a third solid: that is
  /// what makes the specular highlight read as the lit corner of a physical
  /// object rather than as a soft glow.
  final double rimSolidity;

  /// Gain on the shader's specular rim. Slightly above one, so the top edge
  /// separates cleanly from whatever is behind it.
  final double rimIntensity;

  /// Saturation of the rim colour. The rim takes its hue from the backdrop, so
  /// this decides whether the cold blues behind the pane come back as colour or
  /// wash out toward white.
  final double rimSaturation;

  /// Where the light comes from, in degrees: 0 is from the right, 90 from above,
  /// 180 from the left.
  ///
  /// This was left at the shader's default of 0 for every round of this work,
  /// which lit the pane from the right. Nothing else in the interface is lit from
  /// the right - every shadow in the application falls downward, so the implied
  /// light is overhead - and a rim whose bright side disagrees with every shadow
  /// around it is a large part of what reads as artificial even when no single
  /// element looks wrong. A reviewer measured our rim as the only one in a set of
  /// four that varied with position the way a lit object does; it was varying
  /// around the wrong axis.
  final double rimLightDirection;

  /// Thickness of the rim, in logical pixels.
  ///
  /// The shader's default is 1.0. Slightly above it, because at exactly one
  /// logical pixel the rim lands on a single device pixel at low densities and
  /// aliases into a dotted line along the shallow part of the curve.
  final double rimWidth;

  /// Flat, directionless light on the rim, which in practice means light on the
  /// pane's end caps.
  ///
  /// This was added to fix a defect it turned out not to touch, and the corrected
  /// account is worth more than the value. A reviewer measured the pane's top rim
  /// and its bottom rim as equal to within a percent and concluded the pill was
  /// outlined rather than lit. That is accurate. The intended fix was to cut the
  /// ambient term, on the reasoning that light with no direction floods the shadow
  /// side and erases the contrast between them.
  ///
  /// Sweeping it from 1.1 down to 0.15 moved the top-to-bottom ratio from 0.99 to
  /// 1.00. The shader says why: the optical border's angular response is
  /// deliberately two-lobed - `mainLight + oppositeLight * 0.8` - so the far side of
  /// the rim is always lit to four fifths of the near side, and the ratio is capped
  /// at 1.25 whatever this is set to. The ambient term contributes a further tenth
  /// against a directional term multiplied by three, which is why it was invisible.
  /// The reference implementation of this material measures 0.94 on the same test.
  /// A symmetric rim is what this border *is*, and on glass that is defensible:
  /// unlike an opaque object, a glass edge picks up light all the way round by
  /// internal reflection. A single-sided rim would mean giving up the optical
  /// border's background tinting for a classic sweep gradient, which is a worse
  /// trade.
  ///
  /// What the value does control is the end caps. Where the surface normal is
  /// perpendicular to the light both lobes fall to zero, so on a stadium's caps this
  /// is the only light there is. Half, because a reviewer independently noted that
  /// bright straight edges with dimmer caps is the correct signature for a pill of
  /// glass extruded horizontally - so the caps want to be present, not equal.
  final double rimAmbient;

  /// How far the bright part of the rim wraps around the shape, from 0 to 1.
  ///
  /// Low values keep a tight specular glint on the side facing the light; high
  /// values spread it most of the way round. A pill is mostly straight edge with
  /// two tight caps, and a glint that stops before it reaches the caps leaves
  /// them looking unlit.
  final double rimSpread;

  /// Diagonal reflection sweeping the upper half of the pane.
  final Color sheen;

  final Color shadow;
  final double shadowBlur;
  final Offset shadowOffset;

  /// Opaque fill used when the platform asks for reduced transparency.
  final Color fallback;

  /// Content colour for the selected item.
  final Color onGlass;

  /// Content colour for every other item.
  final Color onGlassMuted;

  /// Halo behind glyphs. A transparent pane cannot guarantee contrast on its
  /// own, so every glyph carries its own separation: a dark halo under white
  /// glyphs, a light one under ink glyphs.
  final Color glyphShadow;

  /// Tint of the selection capsule, top to bottom.
  ///
  /// Very low, because the capsule is a second lens rather than a painted shape:
  /// what marks the selected destination is that lens's own rim and the way it
  /// bends the pane behind it, not a fill.
  ///
  /// The capsule used to also cast a brand coloured glow onto the pane beneath
  /// it. Two reviewers, independently, named that glow as the thing that made the
  /// selection read as a sticker glued to the bar: it was the most opaque and most
  /// saturated element in a surface whose entire subject is transparency. It is
  /// gone, and the rim does the work.
  final List<Color> indicator;

  final Color indicatorRim;


  /// Pale frosted glass carrying ink glyphs.
  static const Glass light = Glass(
    // Sigma 1, walked down from 11 through 3 and 1.5.
    //
    // The last step is the one worth explaining. At 1.5 the pane genuinely was
    // displacing what passed behind it - a row crossing the top of the bar arrives
    // shifted and slightly enlarged, and that is visible under magnification - but
    // two reviewers looking at the render at normal size both reported no
    // refraction at all, only blur. They were right about what they could see. A
    // displacement you cannot resolve is indistinguishable from a blur, because
    // recognising that something has moved requires recognising the something
    // first. Blur does not merely hide the transmitted image, it hides the optics
    // performed on the transmitted image.
    blur: 1,
    // Exactly 1.
    //
    // Not a taste decision, and it took three attribution builds to pin down. The
    // rainbow fringing on text behind the pane survived chromaticAberration going
    // to zero on both lenses, and survived the optical border's saturation going to
    // unity. This was the only variable left.
    //
    // The cause is that text behind the pane is drawn with subpixel antialiasing,
    // so its strokes already carry small per-channel differences at their edges.
    // Magnifying that through a lens spreads those differences across more pixels,
    // and any saturation multiplier above unity pushes them to fully saturated red,
    // green and yellow. The pane was not inventing dispersion, it was amplifying
    // the text renderer's own.
    //
    // Nothing worth having is lost: above unity this was boosting a navy gradient
    // and a white sheet, neither of which needs it.
    saturation: 1,
    // Ordinary glass. See [lensIor] for why the pane is on the physical path at
    // all; the short version is that the legacy one could not both bend light and
    // stay legible, and this one can.
    lensIor: 1.5,
    // 34, which is exactly half the bar's height, so the bevel runs from the rim to
    // the centreline and the pane is curved the whole way across with no flat spot
    // in the middle. That is what a lens is, and the legacy band could not be asked
    // for it: its equivalent had to be cut to 6 pixels to stop it mangling type, at
    // which point the pane measured a median displacement of exactly zero over its
    // whole area. It was legible because it had stopped being a lens.
    lensBevel: 34,
    // Small, and read against the bevel - the shader's displacement is roughly
    // `bevel * depth * 5`, so about 6 device pixels at the rim easing to nothing at
    // the centreline.
    //
    // Chosen by sweeping both parameters and scoring two things at once: whether a
    // row of type survives the crossing, and how far the pane actually moves it.
    // Against the shipped legacy recipe, which scored 0.72 correlation at zero
    // displacement, this scores 0.73 at 6 pixels - the same legibility, and optics
    // where there were none. Against the reference bar on the same backdrop, 0.55
    // and 0.36 at 3 and 10 pixels: we are more legible and still bending light.
    //
    // Higher is available and was rejected on the tail rather than the median. At
    // depth 0.05 the median holds up at 0.70 but the tenth percentile falls to 0.27,
    // which is a handful of blocks being destroyed rather than displaced, and those
    // are what a reader notices.
    //
    // Trimmed from 0.04 after a reviewer measured what the tail actually was: an 11
    // pixel band just inside the lower rim where the transmitted row was not
    // displaced but *gone*, its contrast energy down 73 percent, with a compressed
    // copy jammed against the rim below it. That is the displacement at the rim
    // exceeding the height of a line of type, so the band shows the gap between two
    // rows instead of either of them. The bevel keeps its width; only the travel
    // comes down.
    lensDepth: 0.03,
    // Exactly 1: no magnification, which is also the reference's value.
    //
    // This was 1.02 and then 1.05, on the argument that a step in scale across the
    // boundary is half of what reads as thickness. The argument was wrong about
    // where this control acts. It is not a step at the boundary - it rescales
    // everything seen through the lens about the pane's centre, so it lays a
    // second, differently sized copy of the backdrop over the copy the band is
    // already displacing. That is what turned the fold above from a compressed
    // strip into a legible duplicate of the same word at two sizes. Thickness comes
    // from the band and the rim.
    lensZoom: 1,
    // Zero, and the walk down to it is the useful record: 0.004, 0.011, 0.007,
    // 0.003, 0.0015, and the magenta and green fringes on every stroke of type
    // behind the pane barely changed across the whole range.
    //
    // They barely changed because this value is not an absolute offset, it is a
    // fraction of the displacement, and the displacement here is large by design.
    // A wide pane cannot spend dispersion at all: its band runs the full length of
    // the bar, so anything that separates at the edge separates across everything
    // read through it, and fringed text does not read as glass, it reads as a
    // broken composite. Two reviewers independently called it the worst artefact
    // in the frame and said it would read to a user as a rendering failure.
    //
    // Nothing is lost at the rim. The rim takes its colour from the shader's
    // optical border and its [rimSaturation], which is a separate path.
    lensAberration: 0,
    // Up from 0.06 and 0.10, and this is where the light tier's missing edge was
    // actually fixed.
    //
    // A reviewer measured the light pane's own rim at 14 against the dark pane's 83
    // and reported it as having no edge at all. The previous answer was to paint a
    // contour just inside it, which two reviewers then measured as a drawn stroke and
    // read as a scratch across the transaction list. The real problem was never the
    // rim: it was that the pane's washes added up to something *brighter* than the
    // near-white sheet underneath, so the silhouette had nothing to register
    // against, and a rim is not what makes a pane visible - being a different value
    // from its surroundings is.
    //
    // Navy at 0.10 and 0.15, against a lift cut to almost nothing below, leaves the
    // pane a shade darker and cooler than the sheet. That reads as a deliberately
    // tinted piece of glass laid on white, which is what light-mode system chrome
    // is, and it gives the shader's optical border a value step to resolve against.
    scrim: [Color(0x1A0B0D2B), Color(0x260B0D2B)],
    // 0.06 and 0.03, from 0.18 and 0.12, and originally 0.46 and 0.38.
    //
    // Each cut was made for the same reason and the last one finishes the job: a
    // wash this pane lays over its backdrop is contrast it takes away from whatever
    // is behind it. On a white sheet a white lift also costs the pane its own
    // silhouette. What is left is just enough to keep the top of the pane from going
    // flat against the scrim below it.
    lift: [Color(0x0FFFFFFF), Color(0x08FFFFFF)],
    bloom: Color(0x30FFFFFF),
    rimTop: Color(0xFFFFFFFF),
    rimBottom: Color(0xA6FFFFFF),
    // Navy at 0.18. Doubles as the reduced transparency border and, since the pane
    // stopped fading its specular colour for the job, as the inner contour that
    // gives the light pane an edge over a white sheet. See [LiquidGlass]'s sheen
    // painter.
    rimDim: Color(0x2E0B0D2B),
    // 0.45 and 1.3, up from 0.34 and 1.15. The shader's optical border takes its
    // colour from the backdrop, so on the stretch of bar that crosses the brand
    // header it has something to resolve into a line; more solidity buys a crisper
    // line there. Over the white sheet it buys very little, which is why the inner
    // contour above had to change as well - these two together are the light pane's
    // edge, and neither is sufficient alone.
    rimSolidity: 0.45,
    rimIntensity: 1.3,
    rimSaturation: 1.25,
    // 96 degrees: light from just past overhead, leaning left, matching the
    // direction every shadow in the application already implies. See
    // [rimLightDirection] - this sat at the shader's default of 0, lighting the
    // pane from the right, for every round of this work.
    rimLightDirection: 96,
    rimWidth: 1.4,
    // Wide, because a pill is two tight caps joined by a long straight edge and a
    // tight glint never reaches the caps.
    rimSpread: 0.72,
    rimAmbient: 0.5,
    sheen: Color(0x40FFFFFF),
    // Tighter and a little stronger: 0.24 at 14 pixels offset 4, from 0.18 at 18
    // offset 6. On a white sheet the shadow is the only thing defining the pane's
    // underside, and a wide soft one at low alpha spreads far enough to read as
    // haze rather than as a lifted edge.
    shadow: Color(0x3D0B0D2B),
    shadowBlur: 14,
    shadowOffset: Offset(0, 4),
    fallback: Color(0xFFF4F7FF),
    onGlass: Palette.textPrimary,
    onGlassMuted: Color(0xB80F1123),
    // Tight and strong, matching the dark recipe's reasoning. A white halo is
    // what separates an ink glyph from dark content passing under the pane.
    glyphShadow: Color(0xCCFFFFFF),
    // Navy at 0.10 and 0.06, where this used to be white at 0.62 and 0.42.
    //
    // The old values were right for the old pane: a milky white pane needed an
    // even brighter capsule to lift the selected glyph off it. This pane is close
    // to clear over a white sheet, so a white capsule on it is invisible, and the
    // selected slot has to be the *darker* piece of glass instead. Same idea as
    // the dark recipe, sign flipped.
    indicator: [Color(0x1A0B0D2B), Color(0x0F0B0D2B)],
    indicatorRim: Color(0x4D0B0D2B),
  );

  /// Dark glass carrying white glyphs.
  static const Glass dark = Glass(
    // Sigma 1, walked down from 12 through 3 and 1.5.
    //
    // This one number was most of what made the navigation bar read as a plastic
    // slab. At sigma 12 nothing behind the pane survives as a shape: the rows of a
    // transaction list passing underneath arrive as an even grey, and an even grey
    // is what a slab looks like. The eye reads a surface as transparent by
    // recognising what is behind it, not by measuring how much light gets through.
    // See the light recipe for why it went below 1.5: a displacement nobody can
    // resolve reads as a blur, so blur hides the optics as well as the content.
    blur: 1,
    // Exactly 1. See the light recipe: above unity this amplifies the subpixel
    // antialiasing of text passing behind the pane into saturated rainbow fringes.
    saturation: 1,
    // See the light recipe. Same glass, same bevel, same depth: the tiers differ in
    // what they do to colour, not in their optics.
    lensIor: 1.5,
    lensBevel: 34,
    lensDepth: 0.03,
    // Exactly 1. See the light recipe: magnification rescales everything seen
    // through the lens about its centre, which lays a second copy of the backdrop
    // over the one the band is displacing.
    lensZoom: 1,
    // Zero. See the light recipe: on a pane this wide the dispersion lands on the
    // transmitted image rather than staying at the edge, and the rim gets its
    // colour from the optical border instead.
    lensAberration: 0,
    // 0.13 and 0.21, down from 0.22 and 0.30, and navy rather than black.
    //
    // Black was the other half of the slab. A neutral wash over the brand
    // gradient subtracts the colour that identifies the surface and leaves grey,
    // and grey over a white sheet is dirt rather than glass. Tinting the wash
    // with the brand navy keeps it reading as a deliberately dark piece of glass.
    scrim: [Color(0x210B0D2B), Color(0x360B0D2B)],
    // 0.06 at the top and 0.06 at the bottom, where the bottom used to be 0.02.
    //
    // A reviewer measured the lower half of this pane at luminance 45 against a
    // backdrop of 44 and said the pane's mass thinned out, leaving the bottom third
    // to survive on the strength of the rim alone. That is what a scrim tinted with
    // the same navy as the surface it floats over will do: near the bottom, where
    // the scrim is heaviest and the lift had almost run out, the glass and the sheet
    // arrive at the same colour. Holding the lift flat rather than letting it decay
    // keeps a little separation all the way down without brightening the top.
    lift: [Color(0x0FFFFFFF), Color(0x0FFFFFFF)],
    bloom: Color(0x1CFFFFFF),
    rimTop: Color(0xF2FFFFFF),
    rimBottom: Color(0x7AFFFFFF),
    // White at 0.30, up from 0.12, because this colour took on a second job: it is
    // now the inner contour on the face of the pane as well as the reduced
    // transparency border. At 0.12 that contour was weaker than the faded specular
    // white it replaced, so the dark pane would have lost a little of its implied
    // thickness in a change meant to fix the light one.
    rimDim: Color(0x4DFFFFFF),
    rimSolidity: 0.36,
    rimIntensity: 1.18,
    rimSaturation: 1.25,
    // See the light recipe.
    rimLightDirection: 96,
    rimWidth: 1.4,
    rimSpread: 0.72,
    rimAmbient: 0.5,
    // 0.10, down from 0.18. The sheen is a reflection, not a light source, and at
    // the old strength it was a grey wedge laid across the corner.
    sheen: Color(0x1AFFFFFF),
    // Tightened hard. A 34 pixel blur at 60 percent under a floating pill is not
    // separation, it is a smudge, and over a white sheet the smudge is the most
    // visible thing about the bar. The rim does this job now.
    shadow: Color(0x66040616),
    shadowBlur: 16,
    shadowOffset: Offset(0, 6),
    fallback: Palette.darkSurfaceRaised,
    onGlass: Color(0xFFFFFFFF),
    onGlassMuted: Color(0xD1FFFFFF),
    // Tight and strong rather than wide and weak. A pane this transparent cannot
    // guarantee contrast, so the glyph carries its own: a small, dense shadow
    // reads as the glyph sitting above the surface, where a wide soft one reads
    // as haze and is exactly what the pane is trying to stop looking like.
    glyphShadow: Color(0xB304060B),
    // Periwinkle at 0.14 and 0.06, down from 0.34 and 0.14. The capsule is a lens
    // now, so this is a tint the shader composites rather than a fill a painter
    // lays down, and a lens needs very little of it.
    indicator: [Color(0x24B0CBFF), Color(0x0FB0CBFF)],
    indicatorRim: Color(0xC7FFFFFF),
  );

  /// The chrome tier. Panes that float over live, unknown content.
  static Glass of(BuildContext context) =>
      AppTokens.of(context).isDark ? dark : light;

  /// The floating navigation bar.
  ///
  /// This used to be pinned to [dark] in both brightnesses, on the argument that
  /// the bar has to stay legible over the navy brand gradient at the top of a
  /// screen *and* over the near white sheet at the bottom of the same one, and
  /// that the pale recipe went milky over white.
  ///
  /// Both halves of that were wrong. The bar is 68 pixels tall and sits at the
  /// bottom, so it is never over both backdrops at once: it is over whatever the
  /// branch screen's own background is, and every branch screen uses the themed
  /// background. The gradient it was supposedly spanning belongs to the
  /// dashboard's header, which is off the top of the bar by most of a screen. And
  /// the milkiness was not the recipe, it was the recipe's lift washes at 46 and
  /// 38 percent, which are now 30 and 24.
  ///
  /// The pin was also what made the bar impossible to read. White glyphs on a
  /// pane over a white sheet cannot reach a 3:1 contrast ratio at any tint that
  /// still passes light: even the old 30 percent black wash only reached about
  /// 2.1:1, and it bought that by looking like a slab. Following the brightness
  /// dissolves the conflict rather than trading one failure for the other, and it
  /// is what system chrome does: pale glass with ink glyphs on light content,
  /// dark glass with white glyphs on dark.
  static Glass barOf(BuildContext context) => of(context);

  /// The panel tier. Cards that sit on the brand backdrop.
  static Glass panelOf(BuildContext context) => of(context).panel;

  /// True when the platform asks for less transparency. Flutter does not expose
  /// the iOS reduce transparency flag, so high contrast stands in for it, the
  /// same substitution the rest of the app makes.
  static bool isReduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.highContrast ?? false;

  /// This recipe softened for a card sitting on a known backdrop.
  ///
  /// The washes come back hard, because their whole job in the chrome tier is to
  /// survive content the pane cannot predict, and a panel can predict it. The
  /// band widens because panels are larger and carry a larger corner radius, so
  /// the same band would read as a thin frame rather than as an edge.
  ///
  /// Memoised. `shouldRepaint` compares recipes, so handing a painter a freshly
  /// built instance on every build would repaint the pane on every build.
  Glass get panel => _panels.putIfAbsent(
    this,
    () => copyWith(
      lensBevel: lensBevel + 8,
      scrim: [scrim.first.withValues(alpha: scrim.first.a * 0.5), scrim.last],
      lift: [
        lift.first.withValues(alpha: lift.first.a * 0.34),
        lift.last.withValues(alpha: lift.last.a * 0.34),
      ],
      bloom: bloom.withValues(alpha: bloom.a * 0.7),
    ),
  );

  static final Map<Glass, Glass> _panels = {};

  /// This recipe with individual values replaced.
  ///
  /// Public because the render harness in `tool/glass_lab` sweeps the lens
  /// parameters through it. Sweeping used to mean editing this file and rebuilding
  /// once per value, which at three minutes a build is enough friction to
  /// discourage checking a hunch - and unchecked hunches are what put a
  /// non-monotonic refraction in this file for three rounds.
  Glass copyWith({
    double? lensIor,
    double? lensBevel,
    double? lensDepth,
    double? rimLightDirection,
    double? rimWidth,
    double? rimSpread,
    double? rimAmbient,
    double? rimIntensity,
    double? rimSolidity,
    List<Color>? scrim,
    List<Color>? lift,
    Color? bloom,
  }) => Glass(
    blur: blur,
    saturation: saturation,
    lensIor: lensIor ?? this.lensIor,
    lensBevel: lensBevel ?? this.lensBevel,
    lensDepth: lensDepth ?? this.lensDepth,
    rimLightDirection: rimLightDirection ?? this.rimLightDirection,
    rimWidth: rimWidth ?? this.rimWidth,
    rimSpread: rimSpread ?? this.rimSpread,
    rimAmbient: rimAmbient ?? this.rimAmbient,
    lensZoom: lensZoom,
    lensAberration: lensAberration,
    scrim: scrim ?? this.scrim,
    lift: lift ?? this.lift,
    bloom: bloom ?? this.bloom,
    rimTop: rimTop,
    rimBottom: rimBottom,
    rimDim: rimDim,
    rimSolidity: rimSolidity ?? this.rimSolidity,
    rimIntensity: rimIntensity ?? this.rimIntensity,
    rimSaturation: rimSaturation,
    sheen: sheen,
    shadow: shadow,
    shadowBlur: shadowBlur,
    shadowOffset: shadowOffset,
    fallback: fallback,
    onGlass: onGlass,
    onGlassMuted: onGlassMuted,
    glyphShadow: glyphShadow,
    indicator: indicator,
    indicatorRim: indicatorRim,
  );

  /// Compared by value, not by identity.
  ///
  /// Two things depend on this. Painters use it in `shouldRepaint`, so a derived
  /// recipe that is structurally the same as the last one must not force a
  /// repaint. And [_panels] is keyed by recipe, which only works if equal
  /// recipes hash together.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Glass &&
          other.blur == blur &&
          other.saturation == saturation &&
          other.lensIor == lensIor &&
          other.lensBevel == lensBevel &&
          other.lensDepth == lensDepth &&
          other.rimLightDirection == rimLightDirection &&
          other.rimWidth == rimWidth &&
          other.rimSpread == rimSpread &&
          other.rimAmbient == rimAmbient &&
          other.lensZoom == lensZoom &&
          other.lensAberration == lensAberration &&
          listEquals(other.scrim, scrim) &&
          listEquals(other.lift, lift) &&
          other.bloom == bloom &&
          other.rimTop == rimTop &&
          other.rimBottom == rimBottom &&
          other.rimDim == rimDim &&
          other.rimSolidity == rimSolidity &&
          other.rimIntensity == rimIntensity &&
          other.rimSaturation == rimSaturation &&
          other.sheen == sheen &&
          other.shadow == shadow &&
          other.shadowBlur == shadowBlur &&
          other.shadowOffset == shadowOffset &&
          other.fallback == fallback &&
          other.onGlass == onGlass &&
          other.onGlassMuted == onGlassMuted &&
          other.glyphShadow == glyphShadow &&
          listEquals(other.indicator, indicator) &&
          other.indicatorRim == indicatorRim;

  // hashAll rather than hash, because Object.hash takes at most 20 arguments and
  // this recipe carries more fields than that.
  @override
  int get hashCode => Object.hashAll([
    blur,
    saturation,
    lensIor,
    lensBevel,
    lensDepth,
    rimLightDirection,
    rimWidth,
    rimSpread,
    rimAmbient,
    lensZoom,
    lensAberration,
    Object.hashAll(scrim),
    Object.hashAll(lift),
    bloom,
    rimTop,
    rimBottom,
    rimDim,
    rimSolidity,
    rimIntensity,
    rimSaturation,
    sheen,
    shadow,
    shadowBlur,
    shadowOffset,
    fallback,
    onGlass,
    onGlassMuted,
    glyphShadow,
    Object.hashAll(indicator),
    indicatorRim,
  ]);
}
