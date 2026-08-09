import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../../core/design/glass.dart';
import '../../core/design/motion.dart';
import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/pressable.dart';
import 'destinations.dart';

/// Floating liquid glass navigation over the branch in view.
///
/// The bar refracts whatever scrolls beneath it rather than sitting on an opaque
/// fill, and selection is carried by one capsule that travels between slots
/// instead of five independent highlights. See [_SelectionCapsule] for why that
/// distinction matters to how the bar reads.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _go(int branch) => navigationShell.goBranch(
    branch,
    // Selecting the active destination returns that branch to its first route.
    initialLocation: branch == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.tokens.backgroundAlt,
    // The body runs under the bar, which is the whole point of the glass.
    extendBody: true,
    // Android's stretch overscroll lifts a scrollable into its own layer at the
    // scroll edges. A pane that samples the backdrop then has nothing to sample
    // and renders black along the edge, which is a visible fault on every list
    // that runs under the bar. Dropping the indicator keeps the platform physics
    // and the scrollbars, and only gives up the stretch itself.
    body: ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
      child: navigationShell,
    ),
    bottomNavigationBar: _GlassNavBar(
      activeBranch: navigationShell.currentIndex,
      onSelect: _go,
    ),
  );
}

/// The shipped navigation bar, on its own, with no router attached.
///
/// This exists so the render harness in `tool/glass_lab` photographs the bar the
/// application actually ships rather than a copy of it. A copy is worse than no
/// harness at all: it lets a reviewer approve a bar that is not the one on the
/// device. Nothing in the application uses this, and it adds no code to the
/// shipped tree beyond the constructor.
@visibleForTesting
class ShellNavBarPreview extends StatelessWidget {
  const ShellNavBarPreview({
    required this.activeBranch,
    this.onSelect,
    this.showContent = true,
    this.recipe,
    super.key,
  });

  final int activeBranch;
  final ValueChanged<int>? onSelect;

  /// Overrides the recipe the pane is drawn with.
  ///
  /// The harness sweeps the lens parameters through this. Without it a sweep means
  /// editing the recipe and rebuilding once per value, and at three minutes a
  /// build that is enough friction to discourage checking a hunch - which is how a
  /// refraction that showed the same word twice survived three rounds.
  final Glass? recipe;

  /// False renders the pane with nothing in it.
  ///
  /// This is the measurement mode. What the pane does to its own backdrop can
  /// only be read off a region that contains nothing but pane and backdrop, and
  /// every glyph in the bar contributes far more contrast than the glass does. It
  /// is the same pane at the same geometry, so the numbers transfer.
  final bool showContent;

  @override
  Widget build(BuildContext context) => _GlassNavBar(
    activeBranch: activeBranch,
    onSelect: onSelect ?? (_) {},
    showContent: showContent,
    recipe: recipe,
  );
}

class _GlassNavBar extends StatelessWidget {
  const _GlassNavBar({
    required this.activeBranch,
    required this.onSelect,
    this.showContent = true,
    this.recipe,
  });

  final int activeBranch;
  final ValueChanged<int> onSelect;
  final bool showContent;
  final Glass? recipe;

  static const double _height = 68;

  @override
  Widget build(BuildContext context) => SafeArea(
    minimum: const EdgeInsets.only(bottom: Space.x4),
    // heightFactor is load bearing. Scaffold hands its bottom slot a loose
    // height of the whole screen, and an Align without a height factor takes all
    // of it, which parks the pill in the vertical centre of the display.
    child: Align(
      alignment: Alignment.bottomCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Layout.maxContentWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.x5),
          child: SizedBox(
            width: double.infinity,
            height: _height,
            child: LiquidGlass(
              // The pill token is a sentinel, not a measurement. Clamping it to
              // half the height gives the same stadium while keeping the radii
              // well formed for the lens, the rim, and the capsule painter.
              radius: math.min(AppRadius.pill, _height / 2),
              // Follows the brightness. See Glass.barOf for why this used to be
              // pinned to the dark recipe and why that was the wrong call.
              recipe: recipe ?? Glass.barOf(context),
              child: !showContent
                  ? const SizedBox.expand()
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        _SelectionCapsule(
                          slot: ShellDestinations.slotOf(activeBranch),
                          height: _height,
                        ),
                        // The glyphs get their own layer.
                        //
                        // The bar is the one surface that is on screen on every
                        // route, and it samples a live backdrop, so its region is
                        // recomposited on every frame in which anything underneath
                        // it scrolls or animates. Sharing a layer with the pane
                        // meant re-running the whole row each of those frames, and
                        // the row is ten shadowed draws: five glyphs and five
                        // labels, each carrying a blurred halo. On its own layer it
                        // is rasterised once and then blitted, and it only redraws
                        // when the selection actually moves.
                        RepaintBoundary(
                          child: Row(
                            children: [
                              for (final destination
                                  in ShellDestinations.ordered)
                                Expanded(
                                  child: _NavItem(
                                    destination: destination,
                                    isActive:
                                        activeBranch == destination.branch,
                                    onTap: () => onSelect(destination.branch),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The one moving part of the bar: a second lens that slides from the slot it was
/// in to the slot that was tapped.
///
/// A shared indicator, rather than a highlight per item, is what makes the bar
/// read as one surface with a selection on it instead of five buttons.
///
/// It is a real lens, not a painted shape, and that is the point. It used to be
/// an [RRect] with a gradient fill, a rim stroke, a crown highlight and a brand
/// coloured glow spilling out from under it. Two reviewers looking at renders of
/// this bar beside a reference implementation, independently and without knowing
/// which was which, both named that shape as the single worst thing in the frame:
/// an opaque saturated sticker glued onto a surface whose entire subject is
/// transparency. A painted highlight cannot be made of glass by tuning its
/// colours, because what identifies glass is that it bends what is behind it, and
/// paint has nothing behind it.
///
/// So the selection is now the same material as the bar, one tier brighter: its
/// own refraction, its own optical rim, and its own colour separation at the
/// edge. No fill to speak of and no glow at all.
///
/// The liquid part is squash and stretch. While travelling, the capsule widens
/// by an amount proportional to the distance it has to cover and loses a little
/// height, both peaking at the halfway point. The position itself overshoots on
/// [Motion.settle] and comes back, so it arrives under its own weight. Both
/// effects flatten to nothing under reduced motion, leaving a plain slide.
///
/// It marks all five slots, including the centre.
class _SelectionCapsule extends StatefulWidget {
  const _SelectionCapsule({required this.slot, required this.height});

  final int slot;
  final double height;

  @override
  State<_SelectionCapsule> createState() => _SelectionCapsuleState();
}

class _SelectionCapsuleState extends State<_SelectionCapsule>
    with SingleTickerProviderStateMixin {
  late final AnimationController _travel = AnimationController(
    vsync: this,
    duration: Motion.medium,
    value: 1,
  );

  /// Slot the current run started from. A double rather than an int, because a
  /// tap that lands mid travel starts its run from wherever the capsule
  /// currently is.
  late double _from = widget.slot.toDouble();
  late int _to = widget.slot;

  /// Where the capsule sits right now, in slots.
  double get _position => ui.lerpDouble(
    _from,
    _to.toDouble(),
    Motion.settle.transform(_travel.value.clamp(0.0, 1.0)),
  )!;

  @override
  void didUpdateWidget(_SelectionCapsule old) {
    super.didUpdateWidget(old);
    if (widget.slot == _to) return;

    if (Motion.isReduced(context)) {
      _from = widget.slot.toDouble();
      _to = widget.slot;
      _travel.value = 1;
      return;
    }
    // Retargeting from the live position means a second tap mid travel bends the
    // path rather than snapping back to the slot the first tap left.
    _from = _travel.isAnimating ? _position : _to.toDouble();
    _to = widget.slot;
    _travel.forward(from: 0);
  }

  @override
  void dispose() {
    _travel.dispose();
    super.dispose();
  }

  /// Widest the capsule is allowed to get, so it stays a capsule on a tablet
  /// width bar rather than growing into a slab.
  static const double _maxWidth = 66;
  static const double _inset = Space.x2;

  /// Where the capsule sits and how big it is, for a bar of [size].
  ///
  /// Pulled out of the old painter unchanged. The geometry was never the problem;
  /// what the geometry was filled with was.
  Rect _rectFor(Size size, double stretch) {
    final slotWidth = size.width / ShellDestinations.count;
    final restWidth = math.min(slotWidth - _inset, _maxWidth);
    final restHeight = size.height - _inset * 2;

    final t = _travel.value.clamp(0.0, 1.0);
    final travelled = Motion.settle.transform(t);
    // Peaks at the midpoint of the journey and is gone at both ends.
    final smear = math.sin(math.pi * t) * stretch;
    final reach = math.min((_to - _from).abs() * 0.14, 0.34);

    final centreX =
        ui.lerpDouble(_from + 0.5, _to + 0.5, travelled)! * slotWidth;

    return Rect.fromCenter(
      center: Offset(centreX, size.height / 2),
      width: restWidth * (1 + reach * smear),
      height: restHeight * (1 - 0.1 * reach * smear),
    );
  }

  @override
  Widget build(BuildContext context) {
    final glass = Glass.barOf(context);
    final stretch = Motion.amount(context, 1);

    return LayoutBuilder(
      builder: (context, constraints) => AnimatedBuilder(
        animation: _travel,
        builder: (context, _) {
          final rect = _rectFor(constraints.biggest, stretch);
          final radius = rect.height / 2;

          return Stack(
            children: [
              Positioned.fromRect(
                rect: rect,
                child: IgnorePointer(
                  child: Glass.isReduced(context)
                      // Reduced transparency gets the old painted capsule back,
                      // because the whole point of that mode is to stop asking
                      // the user to read text through a lens.
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(radius),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: glass.indicator,
                            ),
                            border: Border.all(color: glass.indicatorRim),
                          ),
                        )
                      : LiquidGlassLens(
                          style: LiquidGlassStyle(
                            shape: LiquidGlassShape.continuousRoundedRectangle(
                              cornerRadius: radius,
                              lightColor: glass.indicatorRim,
                              // A touch brighter than the pane's rim, not four
                              // times it. The selected slot is a nearer piece of
                              // glass and a nearer edge catches more light, which
                              // was the argument for pushing this hard; what it
                              // actually produced was a bright ring reviewers
                              // measured at seven times the strength of the bar's
                              // own edge and read as a sticker. A nearer piece of
                              // glass is identified by transmitting and bending
                              // more, not by being outlined harder.
                              lightIntensity: 1.15,
                              borderType: const OpticalBorder(
                                borderSaturation: 1.4,
                                ambientIntensity: 1.2,
                                borderSolidity: 0.4,
                              ),
                            ),
                            appearance: LiquidGlassAppearance(
                              color: glass.indicator.first,
                              // Sigma 1, where this was 0 on the argument that the
                              // capsule sits on a pane which has already blurred
                              // the backdrop once, so blurring again would only
                              // make the capsule the more opaque of the two.
                              //
                              // The argument held on the device and failed in the
                              // harness, and the failure turned out to be the
                              // interesting one. At 0 the capsule magnified text
                              // behind it with nothing to smooth it, and that text
                              // is drawn with subpixel antialiasing: enlarging its
                              // per-channel edge differences without a blur to
                              // average them turned every letter under the capsule
                              // into saturated red, green and yellow copies of
                              // itself. It was the worst artefact in the render and
                              // it was the only element in the bar with no blur at
                              // all, which is precisely why it was the only element
                              // showing the fringes.
                              //
                              // A sigma of 1 is enough to average the subpixels away
                              // and small enough to keep the capsule the clearer
                              // piece of glass, which is the job it came for.
                              blur: const LiquidGlassBlur(sigmaX: 1, sigmaY: 1),
                            ),
                            refraction: const LiquidGlassRefraction(
                              // Snell's law through a bevel, on the same physical
                              // path as the pane and for the same reasons. See
                              // [Glass.lensIor].
                              //
                              // The bevel is half the capsule's own height, so its
                              // curve runs from rim to centreline exactly as the
                              // pane's does - the two are the same glass at two
                              // sizes rather than two different materials. On the
                              // legacy path this had to be a 6 pixel sliver, for
                              // the same reason the pane did: anything wider showed
                              // the wrong letters across most of a 44 pixel object,
                              // which reviewers picked out as fringing on the one
                              // word passing behind it.
                              refractionType: OpticalRefraction(
                                refraction: 1.5,
                                refractionWidth: 22,
                                depth: 0.03,
                              ),
                              // No magnification, as on the pane. At 1.06 this laid
                              // a second, larger copy of the backdrop over the one
                              // the band was already displacing.
                              magnification: 1,
                              // Zero, where this was 0.005 on the argument that a
                              // small object has almost no transmitted image for
                              // dispersion to spoil, so the capsule was the one
                              // place in the interface that could afford it.
                              //
                              // The argument was sound and the premise was false.
                              // The capsule is 44 pixels wide and it sits directly
                              // over the transaction list, so it has a transmitted
                              // image and that image is type. Reviewers picked out
                              // cyan and green fringing on the one word passing
                              // behind it by name. A pane earns the right to spend
                              // dispersion by having nothing legible behind it, and
                              // nothing in this bar qualifies.
                              //
                              // The rim keeps its colour: that comes from the
                              // optical border's [borderSaturation] above, which is
                              // a separate path and is still above unity.
                              chromaticAberration: 0,
                              refractionMode:
                                  LiquidGlassRefractionMode.shapeRefraction,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The centre slot has no special case any more, and that is the change.
///
/// It was a [FrostMark]: the brand glyph on a 38 pixel tile filled with the navy
/// to cyan brand gradient. On an opaque bar that read as a logo. On a pane whose
/// whole proposition is that you can see through it, it was the loudest possible
/// contradiction, and reviewers comparing renders of this bar against a reference
/// implementation named it unprompted: the most opaque, most saturated object in
/// the frame, an app icon glued to the bar rather than one of five places to go.
///
/// The first attempt at a fix dropped the tile and kept the bare glyph, drawn at
/// the weight of the four Material icons beside it. That was worse in a way worth
/// recording: the mark is a horizontal bar crossed by two diagonals, and stripped
/// of its tile, at 19 pixels, between a receipt and a pie chart, two reviewers
/// independently read it not as a logo but as a missing glyph fallback - "renders
/// as a black asterisk", "the app failed to draw". A brand mark that reads as a
/// rendering error is worse than no brand mark.
///
/// So the centre slot is now [Icons.home_rounded], the icon
/// [ShellDestinations.ordered] always declared for it, and all five slots are one
/// grammar: a glyph, a label, and a lens behind whichever is selected. The brand
/// is present on the dashboard through [FrostLockup]; it does not need a badge in
/// the navigation bar, and the bar cannot afford one.

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.isActive,
    required this.onTap,
  });

  final ShellDestination destination;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final glass = Glass.barOf(context);

    return Pressable(
      onTap: onTap,
      semanticLabel: '${destination.label}${isActive ? ', selected' : ''}',
      borderRadius: AppRadius.pill,
      // Selection is a single driver, so the tint, the lift, the icon size, and
      // the glyph glow all resolve on one timeline instead of drifting apart.
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: isActive ? 1 : 0),
        duration: Motion.resolve(context, Motion.medium),
        curve: Motion.emphasized,
        builder: (context, t, _) {
          final color = Color.lerp(glass.onGlassMuted, glass.onGlass, t)!;
          // A see through pane cannot guarantee contrast, so each glyph carries
          // its own halo. This is what lets the tint stay low enough to read the
          // backdrop through the bar.
          //
          // Tight, not wide, and one shadow rather than two. At blurRadius 5 the
          // halo was a soft cloud around every glyph, and five soft clouds on a
          // translucent pane add up to the haze the pane is trying not to have. At
          // 2 it reads as the glyph standing off the surface, and it buys more
          // contrast per unit of haze because the darkness lands next to the
          // stroke instead of spread across the slot.
          //
          // The selected glyph used to carry a second, brand coloured glow on top.
          // That was the same mistake the capsule was making, at a smaller size:
          // selection announced by added light rather than by the material. The
          // capsule's rim says it now.
          final halo = <Shadow>[Shadow(color: glass.glyphShadow, blurRadius: 2)];

          return Transform.translate(
            offset: Offset(0, Motion.amount(context, -1.5) * t),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  destination.icon,
                  size: 20 + 2 * t,
                  color: color,
                  shadows: halo,
                ),
                const SizedBox(height: 5),
                Text(
                  destination.label,
                  style: AppType.labelSmall.copyWith(
                    color: color,
                    fontSize: 9.5,
                    letterSpacing: 0.2,
                    shadows: halo,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
