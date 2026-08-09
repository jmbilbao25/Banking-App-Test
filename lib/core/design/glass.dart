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
    required this.lensBend,
    required this.lensBand,
    required this.lensZoom,
    required this.lensAberration,
    required this.scrim,
    required this.lift,
    required this.bloom,
    required this.rimTop,
    required this.rimBottom,
    required this.rimDim,
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
    required this.indicatorGlow,
  });

  /// Blur sigma applied to the refracted backdrop, on both axes.
  ///
  /// Deliberately low. A heavy blur erases the very displacement that makes the
  /// pane read as glass, and leaves a grey slab.
  final double blur;

  /// Saturation multiplier applied to the refracted backdrop, so colour behind
  /// the pane still reads as colour rather than grey.
  final double saturation;

  /// Peak displacement inside the refraction band, from 0 to 1.
  ///
  /// This is the whole effect. Held low: the band is narrow, so a large bend
  /// here does not read as thicker glass, it reads as a fisheye.
  final double lensBend;

  /// Width of the refraction band inward from the edge, in logical pixels.
  ///
  /// Scaled to the pane rather than shared, because the band is what gives the
  /// pane implied thickness and a fixed band on a tall card looks like a frame
  /// while the same band on a 68 pixel bar covers the whole thing.
  final double lensBand;

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

  /// Fill of the selection capsule, top to bottom.
  ///
  /// Near neutral rather than a saturated accent. The selected destination is a
  /// brighter piece of glass sitting on the pane, not a painted button, and the
  /// brand colour arrives as light through [indicatorGlow] instead of as fill.
  final List<Color> indicator;

  final Color indicatorRim;

  /// Glow the selection capsule casts onto the pane beneath it.
  final Color indicatorGlow;

  /// Pale frosted glass carrying ink glyphs.
  static const Glass light = Glass(
    blur: 11,
    saturation: 1.5,
    lensBend: 0.12,
    lensBand: 22,
    lensZoom: 1.02,
    lensAberration: 0.004,
    // Barely there, just enough to keep a white backdrop from flattening the rim.
    scrim: [Color(0x0F0B0D2B), Color(0x1A0B0D2B)],
    // 0.46 and 0.38. Milky, but a paler pane cannot hold ink glyphs when dark
    // content scrolls under it.
    lift: [Color(0x75FFFFFF), Color(0x61FFFFFF)],
    bloom: Color(0x59FFFFFF),
    rimTop: Color(0xFFFFFFFF),
    rimBottom: Color(0xA6FFFFFF),
    rimDim: Color(0x2E0B0D2B),
    sheen: Color(0x73FFFFFF),
    shadow: Color(0x3D0B0D2B),
    shadowBlur: 28,
    shadowOffset: Offset(0, 10),
    fallback: Color(0xFFF4F7FF),
    onGlass: Palette.textPrimary,
    onGlassMuted: Color(0xB80F1123),
    glyphShadow: Color(0x73FFFFFF),
    // White 0.62 and 0.42. Brighter than the pane, so ink glyphs gain contrast.
    indicator: [Color(0x9EFFFFFF), Color(0x6BFFFFFF)],
    indicatorRim: Color(0x380B0D2B),
    indicatorGlow: Color(0x596A5CFF),
  );

  /// Dark glass carrying white glyphs.
  static const Glass dark = Glass(
    blur: 12,
    saturation: 1.7,
    // A touch stronger than light mode. The dark backdrop carries less detail
    // for the lens to bend, so the band needs more to read at all.
    lensBend: 0.14,
    lensBand: 24,
    lensZoom: 1.02,
    lensAberration: 0.005,
    // 0.22 and 0.30.
    scrim: [Color(0x38000000), Color(0x4D000000)],
    // 0.13 and 0.05. Low enough to read the backdrop straight through the pane.
    lift: [Color(0x21FFFFFF), Color(0x0DFFFFFF)],
    bloom: Color(0x3DFFFFFF),
    rimTop: Color(0xDBFFFFFF),
    rimBottom: Color(0x6BFFFFFF),
    rimDim: Color(0x1FFFFFFF),
    sheen: Color(0x2EFFFFFF),
    shadow: Color(0x99040616),
    shadowBlur: 34,
    shadowOffset: Offset(0, 14),
    fallback: Palette.darkSurfaceRaised,
    onGlass: Color(0xFFFFFFFF),
    onGlassMuted: Color(0xD1FFFFFF),
    glyphShadow: Color(0x8C04060B),
    // Periwinkle at 0.34 and 0.14: a cool white, not a purple fill.
    indicator: [Color(0x57B0CBFF), Color(0x24B0CBFF)],
    indicatorRim: Color(0x9EFFFFFF),
    indicatorGlow: Color(0x7A6A5CFF),
  );

  /// The chrome tier. Panes that float over live, unknown content.
  static Glass of(BuildContext context) =>
      AppTokens.of(context).isDark ? dark : light;

  /// The floating navigation bar, in both brightnesses.
  ///
  /// Pinned to the dark material rather than following the platform, and this is
  /// the one place the material deliberately does not adapt. The bar is the only
  /// surface that has to stay legible over the navy brand gradient at the top of
  /// a screen *and* over the near white sheet at the bottom of the same screen.
  /// The pale recipe cannot do the second job: over a white sheet its lift washes
  /// go milky, the rim has nothing to grip, and the bar stops reading as an
  /// object and starts reading as a smudge on the page. Dark glass with white
  /// glyphs holds in both places, and it bookends the brand gradient instead of
  /// competing with it.
  static const Glass bar = dark;

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
    () => _copyWith(
      lensBand: lensBand + 8,
      scrim: [scrim.first.withValues(alpha: scrim.first.a * 0.5), scrim.last],
      lift: [
        lift.first.withValues(alpha: lift.first.a * 0.34),
        lift.last.withValues(alpha: lift.last.a * 0.34),
      ],
      bloom: bloom.withValues(alpha: bloom.a * 0.7),
    ),
  );

  static final Map<Glass, Glass> _panels = {};

  Glass _copyWith({
    double? lensBand,
    List<Color>? scrim,
    List<Color>? lift,
    Color? bloom,
  }) => Glass(
    blur: blur,
    saturation: saturation,
    lensBend: lensBend,
    lensBand: lensBand ?? this.lensBand,
    lensZoom: lensZoom,
    lensAberration: lensAberration,
    scrim: scrim ?? this.scrim,
    lift: lift ?? this.lift,
    bloom: bloom ?? this.bloom,
    rimTop: rimTop,
    rimBottom: rimBottom,
    rimDim: rimDim,
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
    indicatorGlow: indicatorGlow,
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
          other.lensBend == lensBend &&
          other.lensBand == lensBand &&
          other.lensZoom == lensZoom &&
          other.lensAberration == lensAberration &&
          listEquals(other.scrim, scrim) &&
          listEquals(other.lift, lift) &&
          other.bloom == bloom &&
          other.rimTop == rimTop &&
          other.rimBottom == rimBottom &&
          other.rimDim == rimDim &&
          other.sheen == sheen &&
          other.shadow == shadow &&
          other.shadowBlur == shadowBlur &&
          other.shadowOffset == shadowOffset &&
          other.fallback == fallback &&
          other.onGlass == onGlass &&
          other.onGlassMuted == onGlassMuted &&
          other.glyphShadow == glyphShadow &&
          listEquals(other.indicator, indicator) &&
          other.indicatorRim == indicatorRim &&
          other.indicatorGlow == indicatorGlow;

  // hashAll rather than hash, because Object.hash takes at most 20 arguments and
  // this recipe carries more fields than that.
  @override
  int get hashCode => Object.hashAll([
    blur,
    saturation,
    lensBend,
    lensBand,
    lensZoom,
    lensAberration,
    Object.hashAll(scrim),
    Object.hashAll(lift),
    bloom,
    rimTop,
    rimBottom,
    rimDim,
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
    indicatorGlow,
  ]);
}
