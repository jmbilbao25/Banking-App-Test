import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/design/motion.dart';
import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../domain/models.dart';
import 'brand.dart';

/// The payment card face.
///
/// Portrait, the way the physical card is held. One vertical fall from ice to
/// ink carries the brand colour in the top third, the bare mark sits centred on
/// the dark half, and the four pieces of real information sit in the corners:
/// the last four digits, the scheme mark, and the product type.
class CardFace extends StatelessWidget {
  const CardFace({
    required this.card,
    this.sheen = 0,
    this.lift = 1,
    this.pending = false,
    this.radius = AppRadius.lg,
    super.key,
  });

  /// Height as a share of width, taken from the physical card proportion.
  static const double aspectRatio = 0.66;

  /// Height for a given available width.
  static double heightFor(double width) => width / aspectRatio;

  final BankCard card;

  /// Where the specular highlight sits, from -1 to 1. The carousel drives this
  /// from the swipe offset so light travels across the face as it turns.
  final double sheen;

  /// How much elevation the face carries, from 0 to 1. Off centre cards sit
  /// lower, so the active card reads as the one in hand.
  final double lift;

  /// True while a freeze or a thaw has been asked for and the write has not come
  /// back. The face takes the frost to [_FrostDriveState._nucleation] so the tap
  /// is answered on the frame the finger lifts, and deliberately stops short of
  /// the point where [_FrozenTag] appears: the material can show that something
  /// is happening, but the card is not frozen until the bank says it is.
  final bool pending;

  final double radius;

  @override
  Widget build(BuildContext context) {
    final border = BorderRadius.circular(radius);

    return _FrostDrive(
      frozen: card.status == CardStatus.frozen,
      pending: pending,
      builder: (context, frost) {
        final face = DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: border,
            boxShadow: [
              BoxShadow(
                color: Palette.frostInk.withValues(alpha: 0.34 * lift),
                blurRadius: 34 * lift,
                spreadRadius: -4,
                offset: Offset(0, 18 * lift),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: border,
            child: _FrostedFace(
              frost: frost,
              sheen: sheen,
              radius: radius,
              colourway: colourwayFor(card.id),
              // Handed in rather than rebuilt, so freezing repaints the material
              // without rebuilding the type, the glyph, and the scheme mark on
              // every frame. The marker inside listens to the same drive and
              // rebuilds only itself.
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  // Inner hairline. Reads as the milled edge of the card.
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: border,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) => Padding(
                      padding: EdgeInsets.all(constraints.maxWidth * 0.075),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  '\u2022\u2022\u2022\u2022 ${card.last4}',
                                  style: AppType.numericSmall.copyWith(
                                    color: Palette.frostInk.withValues(
                                      alpha: 0.72,
                                    ),
                                    letterSpacing: 1.4,
                                  ),
                                ),
                              ),
                              _FrozenTag(frost: frost),
                            ],
                          ),
                          Expanded(
                            child: Center(
                              child: FrostGlyph(
                                width: constraints.maxWidth * 0.56,
                                excludeSemantics: true,
                              ),
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Align, not a bare Expanded child: Expanded hands
                              // down a tight width, which would stretch the mark
                              // and pull the two Mastercard circles apart.
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: NetworkMark(
                                    network: card.network,
                                    width: constraints.maxWidth * 0.21,
                                  ),
                                ),
                              ),
                              Text(
                                card.kind.label,
                                style: AppType.titleSmall.copyWith(
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        // Applied outside the clip and the shadow, so the object squeezes as a
        // whole rather than the content pulling away from its own corners.
        if (Motion.isReduced(context)) return face;
        return _Recoil(frost: frost, child: face);
      },
    );
  }
}

/// The freeze timeline.
///
/// One controller for the whole state change: the material, the marker, and the
/// squeeze all read from it, so nothing has to be kept in step with anything
/// else and the face costs one ticker rather than one per moving part.
///
/// Freezing and thawing are not the same run played backwards, which is the
/// whole point of driving it by hand instead of with a [TweenAnimationBuilder].
/// Ice takes hold over a longer run than it gives up, the bright pass lands at a
/// different moment in each direction, and the needles grow but do not retract.
class _FrostDrive extends StatefulWidget {
  const _FrostDrive({
    required this.frozen,
    required this.pending,
    required this.builder,
  });

  final bool frozen;
  final bool pending;

  /// Handed the drive rather than a value, so each moving part can listen for
  /// itself and rebuild only its own subtree.
  final Widget Function(BuildContext context, Animation<double> frost) builder;

  @override
  State<_FrostDrive> createState() => _FrostDriveState();
}

class _FrostDriveState extends State<_FrostDrive>
    with SingleTickerProviderStateMixin {
  /// The freeze. Longer than the thaw, and longer than a plain transition,
  /// because the face has to be seen taking the frost rather than arriving with
  /// it. Summed from bands in [Motion] rather than being a new number, so the
  /// feature stays inside the motion system.
  static final Duration _freezeRun = Motion.long + Motion.short;

  /// The thaw. Ice lets go faster than it forms.
  static final Duration _thawRun = Motion.medium + Motion.instant;

  /// The bite. Front loaded, so the edge is already cold on the frame the finger
  /// lifts and the rest of the run is the front creeping inward.
  static const Curve _bite = Motion.emphasized;

  /// The release. Read against a value falling from one, this drops the bulk of
  /// the ice at once and leaves the last film to clear slowly, which is the
  /// shape of a thaw rather than a freeze in reverse.
  static const Curve _release = Motion.standard;

  /// How far the frost goes while the write is in flight. Enough to read as
  /// taking hold at the edge, and under [_FrozenTag._start], so a pending card
  /// never claims to be frozen.
  static const double _nucleation = 0.16;

  late final AnimationController _frost;

  @override
  void initState() {
    super.initState();
    _frost = AnimationController(
      vsync: this,
      duration: _freezeRun,
      reverseDuration: _thawRun,
      value: widget.frozen ? 1 : 0,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Also covers the platform turning animation off mid run.
    _run();
  }

  @override
  void didUpdateWidget(_FrostDrive oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.frozen != widget.frozen ||
        oldWidget.pending != widget.pending) {
      _run();
    }
  }

  @override
  void dispose() {
    _frost.dispose();
    super.dispose();
  }

  /// Where the frost belongs for the current inputs.
  double get _target {
    if (!widget.pending) return widget.frozen ? 1 : 0;
    return widget.frozen ? 1 - _nucleation : _nucleation;
  }

  void _run() {
    final target = _target;
    if (Motion.isReduced(context)) {
      _frost.value = target;
      return;
    }
    // Retargeting mid run is the normal case, not an edge case: the write
    // resolves while the nucleation is still settling. Both calls interpolate
    // from wherever the value currently sits and scale the run to the distance
    // left, so the frost never jumps and never restarts.
    if (target > _frost.value) {
      _frost.animateTo(target, curve: _bite);
    } else if (target < _frost.value) {
      _frost.animateBack(target, curve: _release);
    } else if (_frost.isAnimating) {
      // Asked for exactly where it already sits while a run is in flight, so the
      // run is heading somewhere no longer wanted.
      _frost.stop();
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _frost);
}

/// The card material, repainted as the frost moves.
///
/// The [RepaintBoundary] keeps the freeze inside the face. Without it, every
/// frame marks the deck and the screen above it dirty as well.
class _FrostedFace extends StatefulWidget {
  const _FrostedFace({
    required this.frost,
    required this.sheen,
    required this.radius,
    required this.colourway,
    required this.child,
  });

  final Animation<double> frost;
  final double sheen;
  final double radius;
  final CardColourway colourway;
  final Widget child;

  @override
  State<_FrostedFace> createState() => _FrostedFaceState();
}

class _FrostedFaceState extends State<_FrostedFace> {
  @override
  void initState() {
    super.initState();
    widget.frost.addStatusListener(_onStatus);
  }

  @override
  void didUpdateWidget(_FrostedFace old) {
    super.didUpdateWidget(old);
    if (old.frost != widget.frost) {
      old.frost.removeStatusListener(_onStatus);
      widget.frost.addStatusListener(_onStatus);
    }
  }

  @override
  void dispose() {
    widget.frost.removeStatusListener(_onStatus);
    super.dispose();
  }

  /// Rebuilds twice a run rather than forty times.
  ///
  /// The only thing in this subtree that depended on the frost value through the
  /// widget layer was [CustomPaint.willChange], and that only has to change when
  /// the run starts and stops. The painting itself is now driven straight off the
  /// animation, so a tick repaints without building or laying out anything.
  void _onStatus(AnimationStatus _) {
    if (mounted) setState(() {});
  }

  bool get _running =>
      widget.frost.status == AnimationStatus.forward ||
      widget.frost.status == AnimationStatus.reverse;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _CardFacePainter(
        sheen: widget.sheen,
        // Handed the animation, not a value. RenderCustomPaint listens to it and
        // repaints every tick while skipping the build and layout phases, which
        // an AnimatedBuilder wrapped around this cannot do.
        drive: widget.frost,
        radius: widget.radius,
        colourway: widget.colourway,
      ),
      // Tells the raster cache not to hold a layer that is about to change. False
      // at both rest states, so a settled face can still be cached.
      willChange: _running,
      child: widget.child,
    ),
  );
}

/// The card's own answer to the change.
///
/// Feedback: the face tightens as the ice locks and eases open as it lets go, so
/// the object responds rather than only its surface. Scale alone, on the same
/// pulse as the bright pass in the painter, so the two read as one event. Not
/// built at all under reduced motion.
class _Recoil extends StatelessWidget {
  const _Recoil({required this.frost, required this.child});

  final Animation<double> frost;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: frost,
    child: child,
    builder: (context, face) {
      final thawing = frost.status == AnimationStatus.reverse;
      final event = _lockEvent(frost.value, thawing);
      // Below this the squeeze is under a tenth of a pixel on a card this size,
      // so the transform is not worth a layer.
      if (event < 0.03) return face!;
      return Transform.scale(
        scale: thawing ? 1 + 0.008 * event : 1 - 0.013 * event,
        child: face,
      );
    },
  );
}

/// The moment the state actually turns over, as a pulse from 0 to 1.
///
/// Zero at both rest states, so it fires once per change and never sits on a
/// settled card. On a freeze it peaks near full ice, where the face locks. On a
/// thaw it peaks near clear, where the last film breaks and the card comes back.
/// That difference in timing is most of what stops the two directions from
/// reading as one animation played both ways.
///
/// Both shapes are also near zero where a pending face parks, which is why
/// waiting on the bank does not leave a card sitting lit.
double _lockEvent(double frost, bool thawing) {
  final t = frost.clamp(0.0, 1.0);
  // Normalised so each has a maximum of exactly 1: the remainder squared peaks
  // at one third, t cubed times the remainder at three quarters.
  return thawing ? t * (1 - t) * (1 - t) * 6.75 : t * t * t * (1 - t) * 9.481;
}

/// Frozen marker.
///
/// Arrives on the same drive as the frost, over a window inside it: it waits for
/// the rime to bite and is settled before the ice locks, so the marker reads as a
/// consequence of the freeze rather than a second thing happening alongside it.
/// Run the other way, that window makes the tag the first thing to leave on a
/// thaw, which is the right order for a card being handed back.
///
/// It takes no width at all when the card is active, so the face still stays at
/// four elements in its normal state, and once it is in the tree its box is a
/// fixed size for the rest of the run: the arrival is a transform and an opacity,
/// never a width. The earlier version animated an [Align] width factor, which
/// relaid out the row and remeasured the digits beside it on every single frame.
class _FrozenTag extends StatelessWidget {
  const _FrozenTag({required this.frost});

  final Animation<double> frost;

  /// Where in the freeze the tag lands. The start also sets the ceiling on
  /// [_FrostDriveState._nucleation]: below it, a card whose write is still in
  /// flight shows frost but never the word.
  static const double _start = 0.2;
  static const double _end = 0.7;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: frost,
    builder: (context, child) {
      final raw = ((frost.value - _start) / (_end - _start)).clamp(0.0, 1.0);
      if (raw <= 0) return const SizedBox.shrink();
      final t = Motion.standard.transform(raw);
      return Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(10 * (1 - t), 0),
          child: Transform.scale(
            scale: 0.9 + 0.1 * t,
            // Pinned to the right, so the tag grows out of the edge it sits
            // against instead of drifting toward the digits.
            alignment: Alignment.centerRight,
            child: child,
          ),
        ),
      );
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.x2, vertical: 3),
      decoration: BoxDecoration(
        color: Palette.frostInk.withValues(alpha: 0.16),
        borderRadius: AppRadius.all(AppRadius.pill),
        border: Border.all(color: Palette.frostInk.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.ac_unit_rounded,
            size: 11,
            color: Palette.frostInk.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 4),
          Text(
            'FROZEN',
            style: AppType.labelSmall.copyWith(
              color: Palette.frostInk.withValues(alpha: 0.8),
              fontSize: 9,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Scheme colours. Third party marks, kept out of [Palette] because that file
/// is the FrostBank brand sheet and these belong to the card schemes.
abstract final class _Scheme {
  static const Color mastercardRed = Color(0xFFEB001B);
  static const Color mastercardYellow = Color(0xFFF79E1B);

  /// The colour of the region where the two circles meet.
  static const Color mastercardOverlap = Color(0xFFFF5F00);

  /// The Visa word mark, bundled as artwork rather than drawn, because the
  /// letterforms are a custom typeface that no interface font approximates. The
  /// artwork carries Visa Blue itself, so no colour constant is needed for it.
  static const String visaAsset = 'assets/brand/visa.webp';
}

/// Scheme mark on the card face.
///
/// Both marks belong to their schemes, not to FrostBank, which is why the
/// colours live here rather than in [Palette]. Visa is the real word mark, drawn
/// from bundled artwork. Mastercard is drawn from its published geometry: two
/// circles of equal diameter overlapping, with the intersection in a third
/// colour.
///
/// Visa sits on a white plate. Visa Blue is dark, so on the near black lower
/// half of the card face it would disappear, and a white plate is how the mark
/// is placed on dark cards in practice. Mastercard needs no plate, because its
/// two circles already carry their own contrast.
class NetworkMark extends StatelessWidget {
  const NetworkMark({required this.network, required this.width, super.key});

  final CardNetwork network;

  /// Width of the mark. Height follows the scheme's own proportion, so both
  /// marks take the same footprint on the card.
  final double width;

  /// Width to height of the Mastercard symbol, and of the Visa plate that has
  /// to sit beside it.
  static const double _aspect = 1.55;

  @override
  Widget build(BuildContext context) => Semantics(
    label: network.label,
    child: ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: width / _aspect,
        child: switch (network) {
          CardNetwork.mastercard => CustomPaint(
            painter: const _MastercardPainter(),
          ),
          CardNetwork.visa => DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(width * 0.08),
            ),
            child: Padding(
              // Clear space around the word mark. The plate is proportioned to
              // match the Mastercard symbol beside it, so the mark is centred in
              // it rather than filling it.
              padding: EdgeInsets.symmetric(
                horizontal: width * 0.1,
                vertical: width * 0.09,
              ),
              child: Image.asset(
                _Scheme.visaAsset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                // The mark is decorative here: NetworkMark already announces the
                // scheme through Semantics.
                excludeFromSemantics: true,
              ),
            ),
          ),
        },
      ),
    ),
  );
}

/// The Mastercard symbol: two circles of equal diameter, overlapping, with the
/// intersection filled in the third colour.
class _MastercardPainter extends CustomPainter {
  const _MastercardPainter();

  static final Paint _red = Paint()..color = _Scheme.mastercardRed;
  static final Paint _yellow = Paint()..color = _Scheme.mastercardYellow;
  static final Paint _overlap = Paint()..color = _Scheme.mastercardOverlap;

  /// The overlap, kept between paints.
  ///
  /// [Path.combine] is a geometry solve, and this mark sits on a card face that
  /// re-rasterises with the deck: it was running the boolean every time the layer
  /// was redrawn to produce a shape that only depends on the size.
  static Size? _shapeSize;
  static Path? _shape;

  static Path _overlapFor(Rect left, Rect right, Size size) {
    final cached = _shape;
    if (cached != null && _shapeSize == size) return cached;
    _shapeSize = size;
    return _shape = Path.combine(
      PathOperation.intersect,
      Path()..addOval(left),
      Path()..addOval(right),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Circle diameter is the full height, so the published width to height
    // proportion sets how far the two circles overlap.
    final r = size.height / 2;
    final left = Rect.fromCircle(center: Offset(r, r), radius: r);
    final right = Rect.fromCircle(center: Offset(size.width - r, r), radius: r);

    canvas
      ..drawOval(left, _red)
      ..drawOval(right, _yellow)
      ..drawPath(_overlapFor(left, right, size), _overlap);
  }

  @override
  bool shouldRepaint(covariant _MastercardPainter oldDelegate) => false;
}

/// A card product's colourway.
///
/// Every card in the portfolio shares one structure: ice at the top, ink under
/// the mark, the same stops from [Palette.cardFaceStops], the same corner bloom,
/// the same specular travel. Only the hue of the band and the light entering from
/// the right change, which is enough to tell one card from another in a strip
/// while keeping them unmistakably one family.
class CardColourway {
  const CardColourway({
    required this.fall,
    required this.light,
    required this.lightFade,
  });

  /// Top to bottom fall of the face, read against [Palette.cardFaceStops].
  final List<Color> fall;

  /// Cool light entering from the right, held inside the colour band, and the
  /// tone it falls away through.
  final Color light;
  final Color lightFade;
}

/// The portfolio.
///
/// Three products, so a wallet reads as a wallet rather than as one card printed
/// several times. All three stay cold and stay inside the brand sheet.
const List<CardColourway> _colourways = [
  // Glacier. The signature card, and the one the brand mark was drawn against.
  CardColourway(
    fall: Palette.gradientCardFace,
    light: Palette.cardAzure,
    lightFade: Palette.cardOcean,
  ),
  // Aurora.
  CardColourway(
    fall: Palette.gradientCardAurora,
    light: Palette.frostViolet,
    lightFade: Palette.frostPurple,
  ),
  // Meridian.
  CardColourway(
    fall: Palette.gradientCardMeridian,
    light: Palette.frostIceBlue,
    lightFade: Palette.primaryBlue,
  ),
];

/// Which product a card is.
///
/// Taken from the card's own id, so a card keeps its face wherever it sits in the
/// deck and however the list is ordered. Mixed by hand rather than through
/// [String.hashCode], which Dart does not promise to keep the same between runs:
/// a card that changed colour on a restart would be a bug the holder could see.
CardColourway colourwayFor(String cardId) {
  var hash = 0;
  for (final unit in cardId.codeUnits) {
    hash = (hash * 31 + unit) & 0xffffff;
  }
  return _colourways[hash % _colourways.length];
}

/// One frost needle, in coordinates relative to the face.
///
/// Fixed rather than random, so a card looks the same every time it freezes and
/// no seeded generator has to run inside a painter.
class _Crystal {
  const _Crystal(this.x, this.y, this.r, this.rotation, this.delay);

  /// Position as a share of the face, from 0 to 1.
  final double x;
  final double y;

  /// Arm length as a share of the face width.
  final double r;

  final double rotation;

  /// Share of the freeze that passes before this one starts to grow. Set by hand
  /// rather than derived from the position: the needles all sit near an edge now,
  /// so geometry alone would start them together and there would be no creep.
  final double delay;
}

/// Where the frost takes hold.
///
/// All of them hug an edge or a corner, which is where a real card ices up first
/// and, just as usefully, leaves the middle of the face clear so the mark and the
/// scheme artwork still read through the frost. An earlier pass put sixteen large
/// needles across the whole face, including over the mark, and a frozen card
/// stopped looking like a FrostBank card at all.
/// Two sizes rather than one. An earlier pass used ten needles all of much the
/// same size, and at rest they read as a handful of snowflakes stuck on the card
/// rather than as frost: evenly sized shapes with clear space between them are
/// what makes a pattern look applied. The small ones fill the gaps and break that
/// up, and because every needle lands in the same [Path] the extra ones cost
/// nothing beyond their own line work.
const List<_Crystal> _frostCrystals = [
  _Crystal(0.07, 0.05, 0.092, 0.2, 0),
  _Crystal(0.92, 0.96, 0.08, 1.25, 0.05),
  _Crystal(0.91, 0.07, 0.08, 1.1, 0.11),
  _Crystal(0.06, 0.95, 0.088, 0.45, 0.16),
  _Crystal(0.18, 0.14, 0.042, 0.75, 0.2),
  _Crystal(0.04, 0.3, 0.07, 0.9, 0.24),
  _Crystal(0.82, 0.17, 0.04, 0.35, 0.28),
  _Crystal(0.96, 0.38, 0.074, 0.3, 0.31),
  _Crystal(0.15, 0.86, 0.045, 1.05, 0.35),
  _Crystal(0.46, 0.02, 0.062, 0.6, 0.38),
  _Crystal(0.86, 0.85, 0.043, 0.5, 0.42),
  _Crystal(0.93, 0.7, 0.064, 0.75, 0.45),
  _Crystal(0.12, 0.46, 0.038, 0.2, 0.48),
  _Crystal(0.06, 0.64, 0.07, 1.4, 0.51),
  _Crystal(0.9, 0.52, 0.04, 0.95, 0.54),
  _Crystal(0.42, 0.98, 0.058, 0.15, 0.57),
  _Crystal(0.66, 0.05, 0.036, 1.15, 0.6),
  _Crystal(0.28, 0.95, 0.037, 0.65, 0.64),
];

/// The fills of a card face that are a function of its size and its product, and
/// of nothing that moves.
class _FaceLayers {
  const _FaceLayers({
    required this.fall,
    required this.bloom,
    required this.light,
    required this.lightBand,
    required this.vignette,
  });

  factory _FaceLayers.build(Size size, CardColourway colourway) {
    final rect = Offset.zero & size;
    return _FaceLayers(
      fall: Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colourway.fall,
          stops: Palette.cardFaceStops,
        ).createShader(rect),
      bloom: Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.16, -size.height * 0.04),
          size.width * 1.05,
          [
            Palette.frostIceWhite.withValues(alpha: 0.52),
            Palette.frostIcePale.withValues(alpha: 0.16),
            Palette.frostIcePale.withValues(alpha: 0),
          ],
          const [0, 0.42, 1],
        ),
      light: Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 1.02, size.height * 0.16),
          size.width * 0.8,
          [
            colourway.light.withValues(alpha: 0.55),
            colourway.lightFade.withValues(alpha: 0.2),
            colourway.lightFade.withValues(alpha: 0),
          ],
          const [0, 0.5, 1],
        ),
      lightBand: Rect.fromLTWH(0, 0, size.width, size.height * 0.5),
      vignette: Paint()
        ..shader = LinearGradient(
          begin: Alignment.center,
          end: Alignment.bottomCenter,
          colors: [
            Palette.cardVoid.withValues(alpha: 0),
            Palette.cardVoid.withValues(alpha: 0.55),
          ],
        ).createShader(rect),
    );
  }

  final Paint fall;
  final Paint bloom;
  final Paint light;

  /// The light from the right is held inside the colour band rather than run over
  /// the whole face, so it carries its own rectangle.
  final Rect lightBand;

  final Paint vignette;
}

class _CardFacePainter extends CustomPainter {
  /// The animated face. Passing the drive to [CustomPainter.repaint] is what lets
  /// a tick repaint without a build or a layout pass.
  _CardFacePainter({
    required this.sheen,
    required Animation<double> drive,
    required this.radius,
    required this.colourway,
  }) : _drive = drive,
       frost = drive.value,
       thawing = drive.status == AnimationStatus.reverse,
       needles = true,
       super(repaint: drive);

  /// A face at rest, with no drive. Used by the thumbnail and the card back,
  /// neither of which animates.
  _CardFacePainter.still({
    required this.sheen,
    required this.frost,
    required this.radius,
    required this.colourway,
    this.needles = true,
  }) : _drive = null,
       thawing = false;

  final Animation<double>? _drive;

  /// Reused between frames rather than allocated in every one. The painter now
  /// outlives the frame it was built for, so it can own its scratch geometry.
  ///
  final Path _needlePath = Path();

  /// Needle tips, as a flat xy buffer for one batched `drawRawPoints`. Grown once
  /// and then reused, so a sparkle costs no allocation per frame.
  Float32List? _tips;

  /// Live value when there is a drive, because [frost] was captured when this
  /// instance was constructed and the drive keeps moving after that.
  double get _frost => _drive?.value ?? frost;

  bool get _thawing => _drive?.status == AnimationStatus.reverse || thawing;

  /// Which product this face is. Only the fall and the light read it: the bloom,
  /// the vignette, the specular travel, and the whole freeze are neutral and work
  /// on any of them.
  final CardColourway colourway;

  final double sheen;

  /// How far the freeze has taken hold, from 0 to 1. A continuous value rather
  /// than a flag, so most of the material is one piece of code read in either
  /// direction.
  final double frost;

  /// Corner radius of the face, needed for the rime that hugs the edge.
  final double radius;

  /// True while [frost] is falling. The three layers that carry the change
  /// itself, rather than the state, read this so a thaw is not a freeze in
  /// reverse.
  final bool thawing;

  /// Whether to grow crystals. Off for the small face, where they would be a
  /// scribble at that size and are not worth the path.
  final bool needles;

  /// The four fills that describe the product rather than the moment, built once
  /// per size and colourway and then shared.
  ///
  /// This painter repaints on every frame of the freeze, because the drive is
  /// wired to [CustomPainter.repaint], and a new one is built on every frame of a
  /// swipe, because the sheen moves. Building a gradient allocates a native
  /// object, and these four do not depend on either the frost or the sheen: there
  /// are three colourways in the application and a handful of face sizes, so
  /// almost every frame was rebuilding shaders it had already built.
  static final Map<(Size, CardColourway), _FaceLayers> _layerCache = {};

  static _FaceLayers _layersFor(Size size, CardColourway colourway) {
    final key = (size, colourway);
    final hit = _layerCache[key];
    if (hit != null) return hit;
    // Three colourways against the deck, the thumbnail and the back, so the live
    // set is small. The clear is a backstop against a face whose size changes
    // continuously, which would otherwise grow this without bound.
    if (_layerCache.length >= 12) _layerCache.clear();
    return _layerCache[key] = _FaceLayers.build(size, colourway);
  }

  /// The travelling highlight. Cached per painter rather than shared, because
  /// [sheen] is what moves; it is final, so one instance only ever needs one.
  Paint? _specular;
  Size? _specularSize;

  Paint _specularFor(Rect rect) {
    final cached = _specular;
    if (cached != null && _specularSize == rect.size) return cached;
    _specularSize = rect.size;
    final x = sheen * 0.9;
    return _specular = Paint()
      ..shader = LinearGradient(
        begin: Alignment(x - 1.4, -1),
        end: Alignment(x + 0.6, 1),
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.13),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0.34, 0.5, 0.66],
      ).createShader(rect);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final layers = _layersFor(size, colourway);

    canvas
      // The fall. Colour in the top third, near black below the mark.
      ..drawRect(rect, layers.fall)
      // Ice bloom off the top left corner, so the colour band is not a flat ramp.
      ..drawRect(rect, layers.bloom)
      // Cool light entering from the right, held inside the colour band.
      ..drawRect(layers.lightBand, layers.light)
      // Bottom vignette. Pulls the lower half further down so the mark holds.
      ..drawRect(rect, layers.vignette)
      // Specular sheen. Travels with the swipe, so the face reads as a hard
      // surface catching light rather than a printed gradient.
      ..drawRect(rect, _specularFor(rect));

    if (_frost <= 0) return;
    _paintFrost(canvas, size, rect);
  }

  /// The freeze.
  ///
  /// Six layers. Four are pure functions of [frost] and describe the state, so
  /// they read the same in either direction. Two also read [thawing] and describe
  /// the change, because a card giving up its ice does not look like the same
  /// film running backwards:
  ///
  ///   1. a haze whose open centre closes as the frost rises, which is what makes
  ///      the freeze read as spreading inward rather than fading in everywhere at
  ///      once, with the freeze front riding on the same fill as a narrow bright
  ///      band sitting exactly at the closing edge. The band is brightest mid run
  ///      and gone at both rest states, so it crawls inward on a freeze, retreats
  ///      outward on a thaw, and never shows on a settled card. The centre closes
  ///      all the way, so a frozen card is iced right across and carries no disc
  ///      where the front finished
  ///   2. the sheet, which drains the colour out of the face. Heaviest over the
  ///      band at the top where the colour actually is, thinnest across the mark,
  ///      back up over the ink below it
  ///   3. rime thickening along the milled edge, its light front loaded, so the
  ///      edge is cold in the first frames of a freeze and is the last thing to
  ///      give up on a thaw
  ///   4. needles, each waiting its turn, with the wait shorter the nearer it
  ///      sits to an edge, so growth travels inward behind the front. Each arm
  ///      overshoots its length and settles, the way a crystal snaps rather than
  ///      eases into place. On a thaw the light drains out of them faster than
  ///      they shorten, because ice leaving a surface thins rather than retracts
  ///   5. a bright pass carrying the turn itself, near full ice on a freeze where
  ///      the face locks and near clear on a thaw where the last film breaks.
  ///      Zero at both ends, so it fires once per change and never shows at rest
  ///   6. the settled veil, which cools and flattens what is left
  ///
  /// Everything here is sized from the width rather than in logical pixels, so a
  /// thumbnail and a card in the hand ice over to the same proportions.
  ///
  /// Every layer is a plain shader fill or a stroke. There is deliberately no
  /// [MaskFilter] anywhere: an earlier version blurred each needle and drew each
  /// one separately, which came to 576 draw calls per frame with 288 of them
  /// blurred, and that alone was enough to drop frames and take the rasteriser
  /// down. The needles accumulate into one [Path] stroked twice however many of
  /// them there are, and the front is two extra stops on a gradient that was
  /// already being filled, so the whole freeze costs seven draw calls at its most
  /// expensive frame and none of them are blurred.
  void _paintFrost(Canvas canvas, Size size, Rect rect) {
    const ice = Palette.frostIceWhite;
    const pale = Palette.frostIcePale;

    // Clamped before it reaches a curve. Curve.transform asserts on anything
    // outside the unit range, and a value that overshoots by a float's width
    // would otherwise take the whole frame down.
    final t = _frost.clamp(0.0, 1.0);
    final thaw = _thawing;

    // The advancing front.
    //
    // Soft, and elliptical rather than circular. Two earlier passes got this
    // wrong in opposite directions. A plain radial gradient centred on the face
    // is circular, so on a card that is half again as tall as it is wide the
    // front reached the long edges while the short ones were still clear, and the
    // ice read as a disc laid on a card. Replacing it with real geometry, the card
    // outline minus a shrinking rounded rectangle, fixed the shape and introduced
    // something worse: an even-odd fill has a crisp boundary, so mid freeze the
    // card carried a hard rectangle outline across its middle that read as a
    // misplaced border rather than as ice.
    //
    // A gradient cannot have a hard edge, and a transform can give it the card's
    // proportion. The matrix compresses the gradient's y axis by the card's aspect
    // ratio, which turns the circle into an ellipse that reaches all four edges at
    // the same moment while staying soft everywhere.
    final aspect = size.width / size.height;
    final lens = Matrix4.identity();
    // Scale y about the centre of the face, so the ellipse stays centred.
    lens.storage[5] = aspect;
    lens.storage[13] = rect.center.dy * (1 - aspect);

    // Where the front currently sits, from just outside the face to closed. Eased
    // so the edge is cold early and the last of the middle takes its time.
    final clear = ui
        .lerpDouble(1.02, 0, Curves.easeIn.transform(t))!
        .clamp(0.0, 0.99);
    // Brightest halfway through and exactly zero at both rest states, so the band
    // crawls inward on a freeze, retreats outward on a thaw, and never shows on a
    // settled card.
    final front = math.sin(math.pi * t);
    final haze = 0.4 * t;
    // The centre closing the last of the gap. Cubed, so it is still clearly open
    // through the middle of the run and only fills as the face locks.
    final core = haze * t * t;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          rect.center,
          // Past the corner distance in gradient space, which is 0.707 of the
          // width once y is compressed, so the corners ice over too.
          size.width * 0.72,
          [
            pale.withValues(alpha: core),
            ice.withValues(alpha: (haze + 0.34 * front).clamp(0.0, 1.0)),
            pale.withValues(alpha: haze),
          ],
          [clear, math.min(clear + 0.06, 0.995), 1],
          ui.TileMode.clamp,
          lens.storage,
        ),
    );

    // Rime thickening along the milled edge, graded outward rather than blurred.
    //
    // This one is allowed to be a stroke: it sits on the card's own border, where
    // there is already a hard edge, so it reads as the edge icing over instead of
    // as a shape drawn on the face. Taken as a share of the width, so a thumbnail
    // and a card in the hand ice to the same proportion.
    final thickness = size.width * (0.008 + 0.026 * t);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(thickness / 2),
        Radius.circular(radius),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..shader = ui.Gradient.radial(
          rect.center,
          size.width * 0.72,
          [
            ice.withValues(alpha: 0),
            ice.withValues(alpha: 0.42 * Motion.standard.transform(t)),
          ],
          const [0.5, 1],
          ui.TileMode.clamp,
          lens.storage,
        ),
    );

    // The sheet, and the layer that does the actual work of reading as frozen.
    //
    // Everything else in here is edge and detail, and an earlier pass had only
    // those: the corners iced over, needles grew, and the saturated band across
    // the top of the face came through the lot of it untouched, so a frozen card
    // still read as a live card with weather on it. Colour is what has to go.
    //
    // Heaviest exactly where the colour is, thinnest across the middle where the
    // brand mark needs something dark to sit against, and back up over the ink at
    // the bottom so no part of the face is left out of it.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            pale.withValues(alpha: 0.5 * t),
            pale.withValues(alpha: 0.34 * t),
            // The dip. Held low because the band already covers the middle in its
            // own right, so this no longer has to be the only ice over the mark,
            // and because the two stacked would take the white mark under three
            // to one against its background. A soft stop on a vertical ramp
            // leaves no edge and no shape.
            ice.withValues(alpha: 0.07 * t),
            // Cold rather than colourless. An earlier pass pushed near-white over
            // the whole lower half, and near-white over near-black is grey: the
            // card stopped reading as frozen and started reading as disabled. Ice
            // takes the colour down and the temperature with it, so the bottom of
            // the sheet is the brand's own cold blue at low alpha instead of more
            // white.
            Palette.frostIceBlue.withValues(alpha: 0.2 * t),
            Palette.frostIceBlue.withValues(alpha: 0.26 * t),
          ],
          stops: const [0, 0.28, 0.5, 0.76, 1],
        ).createShader(rect),
    );

    // No separate rime layer any more. The contour band above is the rime: it
    // hugs the same outline, and its radial shader is already brightest at the
    // rim. Painting both stacked two edge treatments on one edge and cost a draw
    // call to do it.

    if (needles) {
      final path = _needlePath..reset();
      var any = false;
      var tipCount = 0;
      final tips = _tips ??= Float32List(_frostCrystals.length * 6 * 2);

      for (final crystal in _frostCrystals) {
        final local = ((t - crystal.delay) / (1 - crystal.delay)).clamp(
          0.0,
          1.0,
        );
        if (local <= 0) continue;

        // Overshoot and settle. Clamped, because the overshoot goes past one and
        // an arm longer than its own cell would cross a neighbour.
        //
        // Scaled down from the value an earlier pass used. At full length on a
        // card in the hand these were forty pixel six-armed stars spaced evenly
        // around the edge, which is not what frost looks like: it read as a row of
        // snowflake stickers applied to the card. Shorter arms, and the small
        // family drops to three of them below, turn them back into splinters in
        // the ice rather than glyphs on top of it.
        final arm =
            crystal.r *
            size.width *
            0.5 *
            Motion.settle.transform(local).clamp(0.0, 1.08);
        // Below a pixel there is nothing to see, and a round cap would leave a
        // dot where no crystal has grown yet.
        if (arm < 1) continue;

        final centre = Offset(
          crystal.x * size.width,
          crystal.y * size.height,
        );
        _needle(
          path,
          centre,
          arm,
          crystal.rotation,
          // Six arms is a snowflake. Three is a splinter. The large family keeps
          // the full star because at that size the symmetry reads as crystal; the
          // small family would just be a scatter of tiny identical snowflakes.
          arms: crystal.r > 0.055 ? 6 : 3,
        );
        any = true;

        // Tips of the grown crystals, for the sparkle below. Only the large
        // family and only once an arm is most of the way out, so the light lands
        // on crystals that are actually there.
        if (crystal.r > 0.055 && local > 0.72) {
          for (var i = 0; i < 6; i++) {
            final angle = crystal.rotation + i * (math.pi / 3);
            tips[tipCount++] = centre.dx + math.cos(angle) * arm;
            tips[tipCount++] = centre.dy + math.sin(angle) * arm;
          }
        }
      }

      if (any) {
        // Squared on a thaw, so a needle is out of sight well before it has
        // finished shortening and the ice reads as thinning off the face rather
        // than being pulled back into it.
        final lit = thaw ? t * t : t;
        // Two strokes over the same path: a wide soft one for body, a narrow
        // bright one for the crystal itself. Both taken from the width, so a
        // needle on a thumbnail is the same weight relative to its card as one on
        // a card in the hand, and neither ends up as line art laid over the face.
        final line = size.width * 0.004;
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = line * 2.8
            ..color = pale.withValues(alpha: 0.2 * lit),
        );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = line
            // Held down from the value an earlier pass used. Bright white line
            // work on a smooth face reads as a decal stuck on the card; the same
            // shape a little dimmer reads as crystal in the ice above it.
            ..color = ice.withValues(alpha: 0.38 * lit),
        );

        // Light catching the crystal tips, as the ice locks.
        //
        // One `drawRawPoints` over a flat xy buffer, so every tip on the face is
        // a single draw call however many there are. Round caps make each point a
        // dot rather than a square. Gated on the same pulse as the bright pass, so
        // it fires once per freeze and is absent on a settled card: nothing here
        // repeats, and nothing changes luminance more than once in a run, which is
        // what keeps it clear of WCAG 2.2.2 and of requirement 2.6.
        final spark = _lockEvent(t, thaw);
        if (!thaw && tipCount > 0 && spark > 0.12) {
          canvas.drawRawPoints(
            ui.PointMode.points,
            Float32List.sublistView(tips, 0, tipCount),
            Paint()
              ..strokeCap = StrokeCap.round
              ..strokeWidth = size.width * 0.013
              ..color = ice.withValues(alpha: 0.7 * spark),
          );
        }
      }
    }

    // The turn. Same pulse the face squeezes on, so the flash and the recoil are
    // one event rather than two things that happen to coincide. Below the
    // threshold the fill would be under two values of white, which is not worth
    // a draw call.
    final event = _lockEvent(t, thaw);
    if (event > 0.04) {
      canvas.drawRect(
        rect,
        Paint()..color = ice.withValues(alpha: (thaw ? 0.11 : 0.17) * event),
      );
    }

    canvas.drawRect(rect, Paint()..color = pale.withValues(alpha: 0.09 * t));
  }

  /// Adds one needle to [path]: six arms from a centre, each forking into two
  /// barbs partway out.
  ///
  /// Appends rather than draws, so every needle on the face ends up in a single
  /// path and costs one rasterisation between them.
  static void _needle(
    Path path,
    Offset centre,
    double arm,
    double rotation, {
    int arms = 6,
  }) {
    final step = math.pi * 2 / arms;
    for (var i = 0; i < arms; i++) {
      final angle = rotation + i * step;
      final direction = Offset(math.cos(angle), math.sin(angle));

      path
        ..moveTo(centre.dx, centre.dy)
        ..relativeLineTo(direction.dx * arm, direction.dy * arm);

      final fork = centre + direction * (arm * 0.52);
      for (final side in const [-1.0, 1.0]) {
        final barb = angle + side * math.pi / 3.2;
        path
          ..moveTo(fork.dx, fork.dy)
          ..relativeLineTo(
            math.cos(barb) * arm * 0.3,
            math.sin(barb) * arm * 0.3,
          );
      }
    }
  }

  /// Only consulted when a NEW painter instance arrives, which now happens on a
  /// configuration change rather than on every animation tick: while a drive is
  /// attached, `repaint` triggers the repaint and this is never asked.
  @override
  bool shouldRepaint(covariant _CardFacePainter oldDelegate) =>
      oldDelegate.sheen != sheen ||
      oldDelegate._drive != _drive ||
      oldDelegate._frost != _frost ||
      oldDelegate._thawing != _thawing ||
      oldDelegate.radius != radius ||
      oldDelegate.colourway != colourway ||
      oldDelegate.needles != needles;
}

/// Small portrait card used in strips and lists, where the full face would not
/// have room to breathe. Same material, fewer elements.
class MiniCardFace extends StatelessWidget {
  const MiniCardFace({required this.card, this.width = 96, super.key});

  final BankCard card;
  final double width;

  /// Narrower than this and the scaled labels are no longer readable, so they
  /// are dropped rather than rendered as illegible microtype.
  static const double minWidthForLabels = 72;

  bool get _showsLabels => width >= minWidthForLabels;

  @override
  Widget build(BuildContext context) {
    final border = BorderRadius.circular(AppRadius.sm);

    // Each thumbnail carries a CustomPaint and a drop shadow, and a strip of
    // them scrolls horizontally. Its own layer means scrolling the strip does not
    // repaint every face in it.
    return RepaintBoundary(
      child: SizedBox(
        width: width,
        height: CardFace.heightFor(width),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: border,
            boxShadow: [
              BoxShadow(
                color: Palette.frostInk.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: border,
            // Not animated, and no crystals. A strip of these can be on screen at
            // once, and the freeze is already told on the full face; paying for it
            // again on a 96 pixel thumbnail is not worth the frames.
            child: CustomPaint(
              painter: _CardFacePainter.still(
                sheen: 0,
                frost: card.status == CardStatus.frozen ? 1 : 0,
                radius: AppRadius.sm,
                colourway: colourwayFor(card.id),
                needles: false,
              ),
              child: DecoratedBox(
                // The same milled edge the full face carries, and the reason a
                // strip of these lines up. The bottom of an active card is near
                // black and the backdrop behind it is near black too, so without a
                // hairline its lower corners simply are not there, while a frozen
                // card beside it holds a clear pale edge for its whole height. Two
                // cards the same size read as two different sizes.
                decoration: BoxDecoration(
                  borderRadius: border,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(width * 0.1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Both labels scale with the thumbnail, so under the
                      // threshold they fall to around five logical pixels and
                      // become texture rather than text. At that size the card is
                      // an identity chip, not a data surface, so it carries the
                      // mark alone. The digits and the kind are on the full face
                      // and on the card detail screen, which is where a customer
                      // goes to read them.
                      if (_showsLabels) ...[
                        Text(
                          card.last4,
                          style: AppType.numericSmall.copyWith(
                            color: Palette.frostInk.withValues(alpha: 0.72),
                            fontSize: width * 0.11,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                      Expanded(
                        child: Center(
                          child: FrostGlyph(
                            width: width * (_showsLabels ? 0.5 : 0.62),
                            excludeSemantics: true,
                          ),
                        ),
                      ),
                      if (_showsLabels)
                        Text(
                          card.kind.label.toUpperCase(),
                          style: AppType.labelSmall.copyWith(
                            color: Colors.white.withValues(alpha: 0.86),
                            fontSize: width * 0.09,
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
}

/// Empty slot in a strip of cards. Reads as a place a card could go rather than
/// as a card. Wrap it in a [Pressable] to make it actionable.
class AddCardTile extends StatelessWidget {
  const AddCardTile({this.width = 96, this.onBrand = false, super.key});

  final double width;

  /// True when the tile sits on the brand backdrop instead of the light sheet.
  final bool onBrand;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final line = onBrand ? Colors.white.withValues(alpha: 0.26) : tokens.border;
    final ink = onBrand ? Colors.white : tokens.interactivePrimary;

    return SizedBox(
      width: width,
      height: CardFace.heightFor(width),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: onBrand
              ? Colors.white.withValues(alpha: 0.07)
              : tokens.surface,
          borderRadius: AppRadius.all(AppRadius.sm),
          border: Border.all(color: line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: ink, size: width * 0.24),
            SizedBox(height: width * 0.06),
            Text(
              'Add',
              style: AppType.labelSmall.copyWith(
                color: ink,
                fontSize: width * 0.095,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated page dots for the card carousel. The active dot stretches into a
/// bar, so position reads without counting.
class CardPageDots extends StatelessWidget {
  const CardPageDots({
    required this.count,
    required this.page,
    this.color,
    this.trackColor,
    super.key,
  });

  final int count;

  /// Fractional page position, so the dots track the finger rather than
  /// snapping after the gesture ends.
  final double page;

  final Color? color;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final active = color ?? tokens.accent;
    final track = trackColor ?? tokens.border;
    final index = page.round().clamp(0, count - 1);

    return Semantics(
      label: 'Card ${index + 1} of $count',
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++)
              _Dot(
                // Nearness is continuous, so the bar grows and shrinks with the
                // swipe instead of after it.
                weight: (1 - (page - i).abs()).clamp(0.0, 1.0),
                active: active,
                track: track,
              ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.weight, required this.active, required this.track});

  final double weight;
  final Color active;
  final Color track;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 3),
    width: 7 + 15 * weight,
    height: 7,
    decoration: BoxDecoration(
      color: Color.lerp(track, active, weight),
      borderRadius: AppRadius.all(AppRadius.pill),
    ),
  );
}

/// Skeleton shaped like the card face, so the carousel does not resize when the
/// real cards arrive.
class CardFaceSkeleton extends StatelessWidget {
  const CardFaceSkeleton({required this.width, super.key});

  final double width;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: CardFace.heightFor(width),
    decoration: BoxDecoration(
      color: context.tokens.skeletonHighlight,
      borderRadius: AppRadius.all(AppRadius.lg),
    ),
  );
}

/// Cross fades the trailing edge of a value that changes with the active card.
class CardValueSwap extends StatelessWidget {
  const CardValueSwap({required this.child, this.alignment, super.key});

  final Widget child;
  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: Motion.resolve(context, Motion.medium),
    switchInCurve: Motion.standard,
    switchOutCurve: Motion.standard,
    layoutBuilder: (currentChild, previousChildren) => Stack(
      alignment: alignment ?? Alignment.center,
      children: [...previousChildren, ?currentChild],
    ),
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.22),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    ),
    child: child,
  );
}


/// The back of the card.
///
/// Same material as the front, same colourway, same milled hairline, so the
/// object that turns over is unmistakably the same object. What changes is what
/// it carries: the four things that only exist on the back of a real card, laid
/// out where a real card puts them. The magnetic stripe sits near the top, the
/// signature panel under it with the security code at its right hand end, and the
/// full number below in the same mono face the rest of the application sets
/// figures in.
///
/// This widget renders whatever it is handed. It does not decide whether the
/// holder is allowed to see it. That decision belongs to the screen, behind
/// App_Lock, and requirement 13.8 puts a clock on it.
class CardBackFace extends StatelessWidget {
  const CardBackFace({
    required this.card,
    this.lift = 1,
    this.radius = AppRadius.lg,
    super.key,
  });

  final BankCard card;
  final double lift;
  final double radius;

  /// The number in groups of four, whatever the stored string does about spacing.
  String get _grouped {
    final digits = card.number.replaceAll(RegExp(r'\D'), '');
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) out.write('  ');
      out.write(digits[i]);
    }
    return out.toString();
  }

  @override
  Widget build(BuildContext context) {
    final border = BorderRadius.circular(radius);
    final colourway = colourwayFor(card.id);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: border,
        boxShadow: [
          BoxShadow(
            color: Palette.frostInk.withValues(alpha: 0.34 * lift),
            blurRadius: 34 * lift,
            spreadRadius: -4,
            offset: Offset(0, 18 * lift),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: border,
        child: CustomPaint(
          painter: _CardFacePainter.still(
            sheen: 0,
            // The back of a frozen card is frozen too. Needles are off because
            // they are drawn to sit around the mark, and there is no mark here.
            frost: card.status == CardStatus.frozen ? 1 : 0,
            radius: radius,
            colourway: colourway,
            needles: false,
          ),
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: border,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final pad = w * 0.075;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: pad),
                      // Magnetic stripe. Full bleed, the way it is on a card.
                      Container(
                        height: w * 0.2,
                        width: double.infinity,
                        color: Palette.cardVoid.withValues(alpha: 0.82),
                      ),
                      SizedBox(height: pad * 0.9),
                      // Signature panel, with the code at its right hand end.
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: pad),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: w * 0.13,
                                padding: EdgeInsets.symmetric(
                                  horizontal: w * 0.035,
                                ),
                                alignment: Alignment.centerLeft,
                                decoration: BoxDecoration(
                                  color: Palette.frostIcePale.withValues(
                                    alpha: 0.9,
                                  ),
                                  borderRadius: BorderRadius.circular(w * 0.02),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    card.holderName,
                                    style: AppType.labelSmall.copyWith(
                                      color: Palette.frostInk.withValues(
                                        alpha: 0.7,
                                      ),
                                      fontSize: w * 0.06,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: w * 0.03),
                            Container(
                              height: w * 0.13,
                              padding: EdgeInsets.symmetric(
                                horizontal: w * 0.03,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.94),
                                borderRadius: BorderRadius.circular(w * 0.02),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  card.cvc,
                                  style: AppType.numericSmall.copyWith(
                                    color: Palette.frostInk,
                                    fontSize: w * 0.07,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(pad, pad, pad, pad),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Centred in what is left rather than pinned under
                              // the signature panel. The card is portrait, so
                              // pinning it to the top left the lower half of the
                              // face as one empty black rectangle, which reads as
                              // unfinished rather than as a real card back.
                              Expanded(
                                child: Center(
                                  // On an ink plate, for the same reason the
                                  // signature panel is on one: this is the only
                                  // text in the application that sits behind
                                  // App_Lock, and it has to stay readable on a
                                  // frozen card. Frost is pale by definition, and
                                  // white digits on pale ice fall under the 4.5:1
                                  // floor. The plate also groups the number with
                                  // its own label instead of leaving it floating
                                  // in the middle of the face.
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: w * 0.05,
                                      vertical: w * 0.04,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Palette.cardVoid.withValues(
                                        alpha: 0.42,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        w * 0.03,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                  Text(
                                    'CARD NUMBER',
                                    style: AppType.labelSmall.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.56,
                                      ),
                                      fontSize: w * 0.042,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  SizedBox(height: w * 0.02),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          _grouped,
                                          style: AppType.numericSmall.copyWith(
                                            color: Colors.white,
                                            fontSize: w * 0.095,
                                            letterSpacing: 0.6,
                                          ),
                                        ),
                                      ),
                                        SizedBox(height: w * 0.045),
                                        // Expiry joins the number on the same
                                        // plate rather than sitting loose at the
                                        // bottom of the face. Two reasons, and
                                        // both are rules: it is the same kind of
                                        // information, so proximity should say so,
                                        // and white type on pale ice fails the
                                        // contrast floor exactly the way the
                                        // number did.
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.baseline,
                                          textBaseline: TextBaseline.alphabetic,
                                          children: [
                                            Text(
                                              'EXPIRES',
                                              style: AppType.labelSmall.copyWith(
                                                color: Colors.white.withValues(
                                                  alpha: 0.56,
                                                ),
                                                fontSize: w * 0.042,
                                                letterSpacing: 1.2,
                                              ),
                                            ),
                                            SizedBox(width: w * 0.03),
                                            Text(
                                              card.expiry,
                                              style: AppType.numericSmall
                                                  .copyWith(
                                                    color: Colors.white,
                                                    fontSize: w * 0.06,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // The scheme mark keeps its own white plate, so it
                              // needs nothing from the ink panel above.
                              Align(
                                alignment: Alignment.centerRight,
                                child: NetworkMark(
                                  network: card.network,
                                  width: w * 0.21,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Turns a card over.
///
/// State transition: the card rotates about its own vertical axis to show the
/// side the holder asked for, so the details arrive on the object they belong to
/// instead of in a panel somewhere else on the screen.
///
/// The visible side swaps at the halfway point, where the card is edge on and
/// nothing can be read, and the incoming side is counter rotated so its type is
/// never mirrored. Rotation is one of the four properties requirement 2.3 allows,
/// and the whole thing is driven by an implicit tween, so there is no controller
/// to leak and nothing repeats. Under reduced motion the correct side is rendered
/// immediately with no rotation at all.
class FlipCard extends StatelessWidget {
  const FlipCard({
    required this.showBack,
    required this.front,
    required this.back,
    super.key,
  });

  final bool showBack;
  final Widget front;
  final Widget back;

  @override
  Widget build(BuildContext context) {
    if (Motion.isReduced(context)) return showBack ? back : front;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: showBack ? 1 : 0),
      duration: Motion.medium,
      // Linear, and it is the one motion in the application that should be.
      //
      // Every eased curve in the set front loads its value, and a flip is the one
      // case where that is visible as a fault rather than as polish: on
      // easeOutCubic the value crosses the halfway point at about a third of the
      // duration, so the card showed its front for a third of the turn and spent
      // the other two thirds bringing the back around. A physical card turned
      // between finger and thumb has roughly constant angular velocity, and the
      // side swap has to land in the middle of the run or the two halves are
      // visibly different lengths. Linear is already in the named set, so this
      // adds no fifth curve.
      curve: Motion.linear,
      builder: (context, t, _) {
        final angle = t * math.pi;
        final past = t >= 0.5;
        final transform = Matrix4.identity()
          // Perspective, so the turn has a near edge and a far edge rather than
          // reading as a horizontal squash.
          ..setEntry(3, 2, 0.0013)
          ..rotateY(past ? angle - math.pi : angle);

        return Transform(
          alignment: Alignment.center,
          transform: transform,
          filterQuality: FilterQuality.medium,
          child: past ? back : front,
        );
      },
    );
  }
}
