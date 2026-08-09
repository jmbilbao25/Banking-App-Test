import 'package:flutter/material.dart';

import '../../core/design/motion.dart';
import '../../core/design/tokens.dart';

/// One-shot entrance: the child fades up into place.
///
/// Used to give a section, a row, or a control a sense of arrival instead of
/// appearing fully formed. [index] drives the stagger delay, so a group of
/// siblings resolves in reading order. Under reduced motion the child is built
/// at its end state and no controller is started.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    required this.child,
    this.index = 0,
    this.duration = Motion.medium,
    this.offset = const Offset(0, 16),
    this.curve = Motion.standard,
    this.scaleFrom = 1,
    super.key,
  });

  final Widget child;

  /// Position in the staggered group.
  final int index;

  final Duration duration;

  /// Distance travelled, in logical pixels.
  final Offset offset;

  final Curve curve;

  /// Set below one to have the child grow into place alongside the fade.
  final double scaleFrom;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  /// Built once, not per build. A [CurvedAnimation] created inside `build`
  /// attaches a listener to the controller that is never detached, so a widget
  /// that rebuilds while animating accumulates them.
  late final CurvedAnimation _curved = CurvedAnimation(
    parent: _controller,
    curve: widget.curve,
  );

  /// The fade, clamped to the legal range.
  ///
  /// Callers may pass a curve that overshoots - [Motion.settle] is easeOutBack -
  /// and where an opacity above one used to be clipped by a `clamp` in the
  /// builder, it now reaches a render object that asserts on it.
  late final Animation<double> _opacity = _curved.drive(_ClampUnit());

  late final Animation<double> _scale = _curved.drive(
    Tween<double>(begin: widget.scaleFrom, end: 1),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    if (Motion.isReduced(context)) {
      _controller.value = 1;
      return;
    }
    final delay = Motion.stagger(context, widget.index);
    if (delay == Duration.zero) {
      _controller.forward();
      return;
    }
    Future<void>.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The fade and the scale drive their render objects directly instead of being
    // rebuilt per frame, and that is the whole point of this shape.
    //
    // [staggered] puts one of these around every row of a screen, so an entrance
    // is not one animation but a dozen running at once. Each one used to rebuild
    // an [Opacity] every frame, and an Opacity between 0 and 1 allocates a save
    // layer the size of its child: a dozen offscreen buffers per frame, on the
    // frames where the user is also waiting for the screen's first data. A
    // [FadeTransition] holds one opacity layer and drops it entirely at either end
    // of the range, so a settled row costs nothing at all.
    //
    // The translate keeps a builder because the offset is in logical pixels and
    // [SlideTransition] is a fraction of the child's size. It is cheap: a
    // Transform is a matrix on the canvas, not a layer.
    Widget content = AnimatedBuilder(
      animation: _curved,
      child: widget.child,
      builder: (context, child) => Transform.translate(
        offset: widget.offset * (1 - _curved.value),
        child: child,
      ),
    );

    if (widget.scaleFrom != 1) {
      content = ScaleTransition(scale: _scale, child: content);
    }

    return FadeTransition(opacity: _opacity, child: content);
  }
}

/// Holds an overshooting curve inside the range an opacity will accept.
class _ClampUnit extends Animatable<double> {
  @override
  double transform(double t) => t.clamp(0, 1);
}

/// Wraps a list of children in [FadeSlideIn] so a column or row resolves as one
/// staggered group. [from] offsets the stagger when a group follows another.
List<Widget> staggered(
  List<Widget> children, {
  int from = 0,
  Offset offset = const Offset(0, 16),
  Duration duration = Motion.medium,
}) => [
  for (var index = 0; index < children.length; index++)
    FadeSlideIn(
      index: from + index,
      offset: offset,
      duration: duration,
      child: children[index],
    ),
];

/// Sweeps a highlight across a placeholder so a loading surface reads as
/// pending rather than broken.
///
/// This is the only looping animation outside the splash sequence, and it stops
/// entirely under reduced motion.
class Shimmer extends StatefulWidget {
  const Shimmer({required this.child, this.enabled = true, super.key});

  final Widget child;
  final bool enabled;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  bool _active = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(Shimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) _sync();
  }

  void _sync() {
    final next = widget.enabled && !Motion.isReduced(context);
    if (next == _active) return;
    _active = next;
    if (next) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) return widget.child;

    final highlight = context.tokens.skeletonHighlight;

    // Boundary around the sweep, not inside it.
    //
    // A ShaderMask is a save layer, and this one is rebuilt on every frame for as
    // long as any skeleton is on screen. Without a boundary that repaint walks up
    // to whatever ancestor last owned a layer, which on most screens is the
    // FrostBackdrop - so a loading list was repainting five full screen gradients
    // sixty times a second to sweep a highlight across a placeholder.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) => ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            // Travels one and a half widths so the pause between sweeps reads as
            // rhythm instead of a stall.
            final slide = -1.5 + _controller.value * 3;
            return LinearGradient(
              begin: Alignment(slide - 0.6, -0.4),
              end: Alignment(slide + 0.6, 0.4),
              colors: [
                highlight.withValues(alpha: 0),
                Colors.white.withValues(alpha: 0.16),
                highlight.withValues(alpha: 0),
              ],
              stops: const [0, 0.5, 1],
            ).createShader(bounds);
          },
          child: child,
        ),
      ),
    );
  }
}

/// Cross fades between the states of an asynchronous region, so replacing a
/// skeleton with real content reads as one surface resolving.
class StateCrossFade extends StatelessWidget {
  const StateCrossFade({required this.child, this.alignment, super.key});

  final Widget child;
  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: Motion.resolve(context, Motion.medium),
    switchInCurve: Motion.standard,
    switchOutCurve: Motion.standard,
    layoutBuilder: (currentChild, previousChildren) => Stack(
      alignment: alignment ?? AlignmentDirectional.topStart,
      children: [...previousChildren, ?currentChild],
    ),
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: child,
    ),
    child: child,
  );
}
