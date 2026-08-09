import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/glass.dart';
import '../../core/design/motion.dart';
import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../widgets/brand.dart';
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
    body: navigationShell,
    bottomNavigationBar: _GlassNavBar(
      activeBranch: navigationShell.currentIndex,
      onSelect: _go,
    ),
  );
}

class _GlassNavBar extends StatelessWidget {
  const _GlassNavBar({required this.activeBranch, required this.onSelect});

  final int activeBranch;
  final ValueChanged<int> onSelect;

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
              // well formed for the rim and capsule painters.
              borderRadius: AppRadius.all(
                math.min(AppRadius.pill, _height / 2),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _SelectionCapsule(
                    slot: ShellDestinations.slotOf(activeBranch),
                    height: _height,
                    // The dashboard is marked by the brand mark lighting up, so
                    // the capsule stands down on that slot.
                    visible: activeBranch != 0,
                  ),
                  Row(
                    children: [
                      for (final destination in ShellDestinations.ordered)
                        Expanded(
                          child: destination.branch == 0
                              ? _HomeMark(
                                  label: destination.label,
                                  isActive: activeBranch == 0,
                                  onTap: () => onSelect(0),
                                )
                              : _NavItem(
                                  destination: destination,
                                  isActive: activeBranch == destination.branch,
                                  onTap: () => onSelect(destination.branch),
                                ),
                        ),
                    ],
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

/// The one moving part of the bar: a glass capsule that slides from the slot it
/// was in to the slot that was tapped.
///
/// A shared indicator, rather than a highlight per item, is what makes the bar
/// read as one surface with a selection on it instead of five buttons. It is
/// painted rather than laid out, so it can stretch and squash without pushing
/// the items around, and so it needs no second [BackdropFilter] on top of the
/// pane's own.
///
/// The liquid part is squash and stretch. While travelling, the capsule widens
/// by an amount proportional to the distance it has to cover and loses a little
/// height, both peaking at the halfway point. The position itself overshoots on
/// [Motion.settle] and comes back, so it arrives under its own weight. Both
/// effects flatten to nothing under reduced motion, leaving a plain slide.
/// The capsule still travels to the centre slot when the dashboard is selected,
/// it just fades out on arrival, because the brand mark takes over as the
/// indicator there. Keeping the travel and fading the paint means the return trip
/// starts from the right place instead of appearing out of nowhere.
class _SelectionCapsule extends StatefulWidget {
  const _SelectionCapsule({
    required this.slot,
    required this.height,
    required this.visible,
  });

  final int slot;
  final double height;
  final bool visible;

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

  @override
  Widget build(BuildContext context) {
    final glass = Glass.of(context);
    final reducedGlass = Glass.isReduced(context);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: widget.visible ? 1 : 0),
      duration: Motion.resolve(context, Motion.medium),
      curve: Motion.standard,
      builder: (context, fade, _) => AnimatedBuilder(
        animation: _travel,
        builder: (context, _) => SizedBox.expand(
          child: CustomPaint(
            painter: _CapsulePainter(
              from: _from,
              to: _to.toDouble(),
              progress: _travel.value,
              opacity: fade,
              stretch: Motion.amount(context, 1),
              fill: glass.indicator,
              rim: glass.indicatorRim,
              glow: reducedGlass
                  ? const Color(0x00000000)
                  : glass.indicatorGlow,
            ),
          ),
        ),
      ),
    );
  }
}

class _CapsulePainter extends CustomPainter {
  const _CapsulePainter({
    required this.from,
    required this.to,
    required this.progress,
    required this.opacity,
    required this.stretch,
    required this.fill,
    required this.rim,
    required this.glow,
  });

  final double from;
  final double to;
  final double progress;

  /// Scales every layer of the capsule, so it can hand the indicator role to the
  /// brand mark on the centre slot.
  final double opacity;

  /// Scales squash and stretch to zero under reduced motion.
  final double stretch;

  final List<Color> fill;
  final Color rim;
  final Color glow;

  /// Widest the capsule is allowed to get, so it stays a capsule on a tablet
  /// width bar rather than growing into a slab.
  static const double _maxWidth = 66;
  static const double _inset = Space.x2;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0.01) return;

    // One layer for the whole capsule, so the fade is uniform. Scaling each
    // layer's own alpha instead would let the rim outlive the fill and leave a
    // floating outline behind.
    final faded = opacity < 0.99;
    if (faded) {
      canvas.saveLayer(
        null,
        Paint()..color = Colors.black.withValues(alpha: opacity),
      );
    }

    final slotWidth = size.width / ShellDestinations.count;
    final restWidth = math.min(slotWidth - _inset, _maxWidth);
    final restHeight = size.height - _inset * 2;

    final t = progress.clamp(0.0, 1.0);
    final travelled = Motion.settle.transform(t);
    // Peaks at the midpoint of the journey and is gone at both ends.
    final smear = math.sin(math.pi * t) * stretch;
    final reach = math.min((to - from).abs() * 0.14, 0.34);

    final width = restWidth * (1 + reach * smear);
    final height = restHeight * (1 - 0.1 * reach * smear);

    final centreX = ui.lerpDouble(from + 0.5, to + 0.5, travelled)! * slotWidth;

    final rect = Rect.fromCenter(
      center: Offset(centreX, size.height / 2),
      width: width,
      height: height,
    );
    final shape = RRect.fromRectAndRadius(rect, Radius.circular(height / 2));

    // The brand colour arrives as light spilling from under the capsule rather
    // than as fill, which is what keeps the selected destination reading as a
    // brighter piece of glass instead of a painted button.
    if (glow.a > 0) {
      canvas.drawRRect(
        shape.inflate(1.5),
        Paint()
          ..color = glow
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    canvas.drawRRect(
      shape,
      Paint()
        ..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, fill),
    );

    // Rim, brightest across the top where the pane's own light lands.
    canvas.drawRRect(
      shape.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          [
            rim,
            rim.withValues(alpha: rim.a * 0.3),
            rim.withValues(alpha: rim.a * 0.55),
          ],
          const [0, 0.6, 1],
        ),
    );

    // A short highlight across the top third, so the capsule has a face and not
    // just an outline.
    canvas.save();
    canvas.clipRRect(shape);
    final crown = Rect.fromLTWH(rect.left, rect.top, rect.width, height * 0.42);
    canvas.drawRect(
      crown,
      Paint()
        ..shader = ui.Gradient.linear(crown.topCenter, crown.bottomCenter, [
          rim.withValues(alpha: rim.a * 0.3),
          rim.withValues(alpha: 0),
        ]),
    );
    canvas.restore();

    if (faded) canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CapsulePainter old) =>
      old.progress != progress ||
      old.from != from ||
      old.to != to ||
      old.opacity != opacity ||
      old.stretch != stretch ||
      old.rim != rim ||
      old.glow != glow;
}

/// The brand mark in the centre slot, which is its own indicator.
///
/// When the dashboard is the branch in view the mark lights up instead of taking
/// a capsule: a brand coloured glow breathes behind the tile, and a specular band
/// sweeps across its face and then rests. Using the logo as the marker for home
/// says something a generic pill cannot, and it leaves the capsule free to mean
/// only "one of the other four".
///
/// One controller drives both, on a cycle long enough that the sweep reads as an
/// occasional catch of light rather than a loading state. The ticker only runs
/// while home is selected, and under reduced motion it does not run at all,
/// leaving a steady glow and no sweep.
class _HomeMark extends StatefulWidget {
  const _HomeMark({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_HomeMark> createState() => _HomeMarkState();
}

class _HomeMarkState extends State<_HomeMark>
    with SingleTickerProviderStateMixin {
  static const double _size = 38;

  /// Long, because most of the cycle is the pause after the sweep.
  static const Duration _cycle = Duration(milliseconds: 3400);

  late final AnimationController _beacon = AnimationController(
    vsync: this,
    duration: _cycle,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_HomeMark old) {
    super.didUpdateWidget(old);
    if (old.isActive != widget.isActive) _sync();
  }

  /// State transition: the mark acknowledges becoming the active destination
  /// once and then rests.
  ///
  /// This used to call repeat(), which left a beacon sweeping forever behind a
  /// BackdropFilter on the most visited screen. That is two problems in one:
  /// requirement 2.6 permits exactly one repeating animation in the application,
  /// which is the splash indicator, and a permanently animating layer over a
  /// blur forces that blur to re-rasterise every frame for the life of the
  /// session.
  void _sync() {
    final shouldRun = widget.isActive && !Motion.isReduced(context);
    if (shouldRun) {
      _beacon.forward(from: 0);
    } else {
      _beacon
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _beacon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final glass = Glass.of(context);

    return Pressable(
      onTap: widget.onTap,
      semanticLabel: '${widget.label}${widget.isActive ? ', selected' : ''}',
      borderRadius: AppRadius.pill,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: widget.isActive ? 1 : 0),
          duration: Motion.resolve(context, Motion.medium),
          curve: Motion.emphasized,
          builder: (context, selected, child) => Transform.scale(
            scale: 1 + 0.08 * selected,
            child: Transform.translate(
              offset: Offset(0, Motion.amount(context, -2) * selected),
              child: AnimatedBuilder(
                animation: _beacon,
                child: child,
                builder: (context, mark) => CustomPaint(
                  painter: _BeaconGlowPainter(
                    selected: selected,
                    phase: _beacon.value,
                    glow: tokens.accent,
                  ),
                  foregroundPainter: _BeaconSweepPainter(
                    selected: selected,
                    phase: _beacon.value,
                    sheen: glass.onGlass,
                  ),
                  child: mark,
                ),
              ),
            ),
          ),
          child: const FrostMark(size: _size),
        ),
      ),
    );
  }
}

/// Corner radius the mark's tile is drawn with, as a share of its size. Matches
/// [FrostMark], so the glow and the sweep sit exactly on the tile.
const double _markRadiusRatio = 0.28;

RRect _markShape(Size size) => RRect.fromRectAndRadius(
  Offset.zero & size,
  Radius.circular(size.shortestSide * _markRadiusRatio),
);

/// The breathing halo behind the mark. Two passes, a tight core and a wide bloom,
/// because a single blurred fill reads as a smudge rather than as light.
class _BeaconGlowPainter extends CustomPainter {
  const _BeaconGlowPainter({
    required this.selected,
    required this.phase,
    required this.glow,
  });

  final double selected;
  final double phase;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    if (selected <= 0.01) return;

    final shape = _markShape(size);
    // Rests at a little over half strength, so a stopped ticker still leaves the
    // mark lit rather than dark.
    final breath = 0.58 + 0.42 * math.sin(2 * math.pi * phase);
    final amount = selected * breath;

    canvas.drawRRect(
      shape.inflate(3 + 5 * amount),
      Paint()
        ..color = glow.withValues(alpha: 0.14 + 0.24 * amount)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 9 + 9 * amount),
    );
    canvas.drawRRect(
      shape.inflate(1),
      Paint()
        ..color = glow.withValues(alpha: 0.2 + 0.32 * amount)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 + 4 * amount),
    );
  }

  @override
  bool shouldRepaint(covariant _BeaconGlowPainter old) =>
      old.selected != selected || old.phase != phase || old.glow != glow;
}

/// The specular band crossing the mark's face.
///
/// Travels corner to corner along the diagonal and occupies only the first part
/// of the cycle, so the rest of the loop is a pause. Intensity rises and falls
/// across the run, so the band never appears or vanishes mid face.
class _BeaconSweepPainter extends CustomPainter {
  const _BeaconSweepPainter({
    required this.selected,
    required this.phase,
    required this.sheen,
  });

  final double selected;
  final double phase;
  final Color sheen;

  /// Share of the cycle the band is travelling for.
  static const Interval _window = Interval(0.06, 0.44, curve: Curves.easeInOut);

  /// Half width of the band, in gradient units.
  static const double _half = 0.13;

  @override
  void paint(Canvas canvas, Size size) {
    if (selected <= 0.01) return;
    final travel = _window.transform(phase);
    if (travel <= 0 || travel >= 1) return;

    // Kept inside the ends of the gradient so the three stops stay strictly
    // increasing, which Gradient.linear requires.
    final centre = _half + travel * (1 - 2 * _half);
    final peak = math.sin(math.pi * travel) * selected;
    final band = sheen.withValues(alpha: sheen.a * 0.72 * peak);
    final clear = sheen.withValues(alpha: 0);

    canvas.save();
    canvas.clipRRect(_markShape(size));
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, size.height),
          [clear, band, clear],
          [centre - _half, centre, centre + _half],
        ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BeaconSweepPainter old) =>
      old.selected != selected || old.phase != phase || old.sheen != sheen;
}

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
    final glass = Glass.of(context);

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
          final halo = <Shadow>[
            Shadow(color: glass.glyphShadow, blurRadius: 5),
            if (t > 0)
              Shadow(
                color: glass.indicatorGlow.withValues(
                  alpha: glass.indicatorGlow.a * t,
                ),
                blurRadius: 14 * t,
              ),
          ];

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
