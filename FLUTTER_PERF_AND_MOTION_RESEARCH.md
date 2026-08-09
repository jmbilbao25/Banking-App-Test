# Flutter rendering performance & motion UX — authoritative guidance

Scope: an animated frost/ice `CustomPainter` on a credit-card face driven by an
`AnimationController`, plus shader-based "liquid glass" panes, on Impeller.

Every claim below links to its source. Where official docs are silent, that is
stated explicitly rather than filled with a guessed number. Content from sources
was rephrased for compliance with licensing restrictions.

Doc versions consulted: docs.flutter.dev pages reflecting **Flutter 3.44.7**;
framework source from the `stable` branch (`flutter-3.44-candidate.0`).

---

## 1. Rendering performance best practices (officially documented)

### 1.1 Frame budget — the actual numbers

| Target | Total budget | Docs say |
|---|---|---|
| 60 Hz | ~16 ms per frame | Each frame must render approximately every 16 ms to avoid jank ([Flutter performance profiling](https://docs.flutter.dev/perf/ui-performance)) |
| 60 Hz, split across threads | ~8 ms build + ~8 ms raster | Build and rendering are separate threads; to keep latency low, build in 8 ms or less and render in 8 ms or less ([Performance best practices](https://docs.flutter.dev/perf/best-practices)) |
| 120 Hz | under 8 ms total | As 120 fps devices become common, aim to render frames in under 8 ms total ([Performance best practices](https://docs.flutter.dev/perf/best-practices)) |

The performance overlay draws white lines at 16 ms increments; crossing one means
you are below 60 Hz. Red bars mark frames that failed to display. A red bar in
the UI graph means the Dart code is too expensive; a red bar in the GPU/raster
graph means the scene is too complicated to rasterise quickly
([Flutter performance profiling](https://docs.flutter.dev/perf/ui-performance)).
DevTools uses the same threshold — a frame over ~16 ms is flagged janky and
overlaid in red ([Use the Performance view](https://docs.flutter.dev/tools/devtools/performance)).

The docs also make an argument for going *below* budget even when you are already
passing: it will not look different, but it improves battery life and thermals,
and your slowest target device is not your dev device
([Performance best practices](https://docs.flutter.dev/perf/best-practices)).

**Rule for the card:** treat 8 ms raster as the ceiling for the whole screen, not
just the frost layer, and validate on the slowest device you support.

### 1.2 `RepaintBoundary` — when it helps, and when it hurts

`RenderRepaintBoundary` gives its child a **separate display list**. That pays off
in two directions: when the child does not repaint but the parent does, the
previously recorded display list is reused; when the child repaints but the
surrounding tree does not, only the child's list is re-recorded
([RenderRepaintBoundary](https://api.flutter.dev/flutter/rendering/RenderRepaintBoundary-class.html)).

It also may hint to the engine to further optimise animation performance when the
subtree behind it is complex and static while the surrounding tree changes often
([RepaintBoundary](https://api.flutter.dev/flutter/widgets/RepaintBoundary-class.html)).

**Where it HURTS — this is documented, not folklore.** Repaint boundaries are only
useful when parent and child paint at *different* times. When both paint at the
same time the boundary is redundant and *may actually be making performance
worse*. Flutter exposes the counters to prove it:

- `debugSymmetricPaintCount` — times this object repainted **at the same time as**
  its parent (bad; boundary is redundant).
- `debugAsymmetricPaintCount` — times one repainted **without** the other (good;
  this is the case the boundary exists for).

Run in debug mode, exercise the UI normally, then call `debugDumpRenderTree`:
every `RenderRepaintBoundary` prints the useful-vs-not ratio. `debugResetMetrics`
zeroes the counters
([RenderRepaintBoundary](https://api.flutter.dev/flutter/rendering/RenderRepaintBoundary-class.html)).

A second documented subtlety: sometimes you need **two or more** boundaries to get
any benefit. The docs' example is an email app with an unread count and a list —
if only one of the two is boundaried, the whole app still repaints; boundary both
and the rest of the app stays still
([RenderRepaintBoundary](https://api.flutter.dev/flutter/rendering/RenderRepaintBoundary-class.html)).

Related, and directly relevant to a card that is faded/scaled/rotated: for a
static scene being faded, rotated or otherwise manipulated, a `RepaintBoundary`
might help ([Flutter performance profiling](https://docs.flutter.dev/perf/ui-performance)).
But raster-cache entries are expensive to construct and consume a lot of GPU
memory, so cache images only where absolutely necessary
([Flutter performance profiling](https://docs.flutter.dev/perf/ui-performance)).

**Rules for the card:**
1. Keep the `RepaintBoundary` immediately around the frost `CustomPaint`, so the
   ticking painter does not dirty the carousel and the screen above it.
2. Because the frost painter repaints *every frame while animating*, its boundary
   is asymmetric-useful during a run and symmetric-redundant at rest. Verify with
   `debugDumpRenderTree` rather than assuming.
3. Do **not** sprinkle boundaries around every needle/sub-layer. A boundary per
   small child that repaints together with its parent is documented to be a net
   loss.
4. If the card content (number, name, chip art) is static while frost animates,
   that static content behind its own boundary is the textbook win — the frost
   layer re-records, the content list is reused.

### 1.3 `CustomPainter.shouldRepaint` and the right repaint trigger

`shouldRepaint` is called when a **new instance** of the painter delegate is
supplied to the `RenderCustomPaint`, to check whether the new instance actually
represents different information
([CustomPainter](https://api.flutter.dev/flutter/rendering/CustomPainter-class.html)).
The canonical example returns `false` for a painter with no fields, and the doc
comment spells out the rule: if the painter had fields set from the constructor,
return `true` when any of them differ from the same field on `oldDelegate`
([CustomPainter](https://api.flutter.dev/flutter/rendering/CustomPainter-class.html)).

**The more important, less-used half of that API page:** the *most efficient* way
to trigger a repaint is **not** to rebuild with a new painter at all. Either

- extend `CustomPainter` and pass a `repaint` argument to its constructor — an
  object that notifies listeners when it is time to repaint; or
- extend `Listenable` (e.g. via `ChangeNotifier`) and implement `CustomPainter`,
  so the painter provides notifications itself.

In either case the `CustomPaint` widget / `RenderCustomPaint` listens to the
`Listenable` and repaints when the animation ticks, **avoiding both the build and
layout phases of the pipeline**
([CustomPainter](https://api.flutter.dev/flutter/rendering/CustomPainter-class.html)).

**Rule for the card — this is the single biggest available structural win.**
An `AnimatedBuilder` around `CustomPaint` currently rebuilds the widget, creates a
new `_CardFacePainter` every tick, and runs `shouldRepaint`. Passing the frost
`Animation<double>` straight into `CustomPainter(repaint: frost)` and reading
`frost.value` inside `paint()` skips build and layout entirely for every
animating frame. Keep `shouldRepaint` correct anyway for the configuration
changes (colourway, radius, sheen) that *do* arrive as new instances.

Also from the same page: `paint` runs during the paint phase, so you cannot call
`setState` or `markNeedsLayout` from inside it — layout for that frame has already
happened ([CustomPaint](https://api.flutter.dev/flutter/widgets/CustomPaint-class.html)).

### 1.4 `isComplex` and `willChange` on `CustomPaint`

Both are **hints to the compositor's raster cache**
([CustomPaint](https://api.flutter.dev/flutter/widgets/CustomPaint-class.html)).

- `isComplex` — whether the painting is complex enough to benefit from caching.
- `willChange` — whether the raster cache should be told this painting is likely
  to change next frame. Setting it tells the compositor **not** to cache the layer
  containing this render object, because the cache will not be used in future. If
  the hint is not set, the compositor applies its own heuristics
  ([RenderCustomPaint.willChange](https://api.flutter.dev/flutter/rendering/RenderCustomPaint/willChange.html)).

**Rule for the card:** `willChange: t > 0 && t < 1` is exactly right — true only
mid-run so the cache does not retain a frame that is about to change, false at the
two rest states so a genuinely static card face *can* be cached. Do not set
`isComplex: true` on the animating frost layer: complex + will-change is a
contradiction (pay to cache something you have declared disposable). `isComplex`
belongs on genuinely static, expensive art (chip/mastercard marks) that sits at
rest.

### 1.5 `saveLayer` — why it is the most expensive call in the framework

`saveLayer` is called out as one of the most expensive methods in the framework
([Flutter performance profiling](https://docs.flutter.dev/perf/ui-performance)).
The documented mechanism, in two places:

- It allocates an offscreen buffer, and drawing into that buffer might trigger a
  **render target switch**. The GPU wants to run like a firehose; a render target
  switch forces the stream to be redirected and then redirected back. On mobile
  GPUs this is particularly disruptive to rendering throughput
  ([Performance best practices](https://docs.flutter.dev/perf/best-practices)).
- Most GPU architectures batch and reorder commands. Layers force a render target
  switch, which can flush the GPU's command buffer — losing the optimisations you
  would get from larger batching — and generates a lot of memory churn, because
  the GPU must copy the current framebuffer contents out of write-optimised memory
  and copy them back when the previous target is restored
  ([Canvas.saveLayer](https://api.flutter.dev/flutter/dart-ui/Canvas/saveLayer.html)).

When it is genuinely required: dynamically-sourced shapes, each semi-transparent,
that may or may not overlap — then you pretty much have to use it
([Performance best practices](https://docs.flutter.dev/perf/best-practices)).

Things that call it **implicitly**, per the docs: `ShaderMask`, `ColorFilter`,
`Chip` (when `disabledColorAlpha != 0xff`), `Text` (when there is an
`overflowShader`), and `Clip.antiAliasWithSaveLayer`
([Performance best practices](https://docs.flutter.dev/perf/best-practices),
[Flutter performance profiling](https://docs.flutter.dev/perf/ui-performance)).
`Opacity` is an offscreen-buffer widget too — see §1.6.

Minimisation strategies, from the docs: if two shapes always overlap the same way
with the same transparency, precompute the composited semi-transparent result,
cache it, and draw that instead; or refactor the painting so there are no overlaps
at all ([Performance best practices](https://docs.flutter.dev/perf/best-practices)).
And the three questions to ask at each `saveLayer` you find: does the app need the
effect, can the call be eliminated, can the same effect be applied to an
individual element instead of a group
([Flutter performance profiling](https://docs.flutter.dev/perf/ui-performance)).

There is one documented case where a `CustomPainter` legitimately *needs*
`saveLayer`: render objects are composited using a minimum number of `Canvas`es
for performance, so your painter's canvas may be shared with other widgets
including other `CustomPaint`s. Using `BlendMode.dstOut` to "punch a hole" can
therefore erase more than intended, because earlier widgets painted onto the same
canvas. `Canvas.saveLayer`/`restore` fixes it — but creating layers is relatively
expensive and should be done sparingly to avoid introducing jank
([CustomPainter](https://api.flutter.dev/flutter/rendering/CustomPainter-class.html)).

**Rules for the card:**
1. Zero `saveLayer` in the frost painter. No `ShaderMask`, no `ColorFilter`, no
   `Opacity` wrapper, no `Clip.antiAliasWithSaveLayer`.
2. If a frost layer needs to be masked to the rounded card, use the `borderRadius`
   property of the surrounding widget or `drawRRect`, not a clip-with-save-layer.
3. Avoid `dstOut`-style hole punching on the frost. If you need a "thinned" centre,
   do it with gradient stops (as the current painter does), not a layer.

### 1.6 Opacity: `Opacity` widget vs `AnimatedOpacity` vs painting with alpha

Ordered by cost, all documented:

**Cheapest — draw with a semi-transparent colour.** For values other than 0.0 and
1.0, `Opacity` paints its child into an intermediate buffer and blends it back,
which is *relatively expensive*. At 0.0 the child is not painted at all; at 1.0 it
is painted with no intermediate buffer
([Opacity](https://api.flutter.dev/flutter/widgets/Opacity-class.html)). The docs
give a direct comparison: `Container(color: Color.fromRGBO(255, 0, 0, 0.5))` is
much faster than `Opacity(opacity: 0.5, child: Container(color: Colors.red))`
([Opacity](https://api.flutter.dev/flutter/widgets/Opacity-class.html)). Best
practices repeats it: instead of wrapping simple shapes or text in `Opacity`, it
is usually faster to draw them with a semi-transparent colour — **though this only
works if the shape has no overlapping bits**
([Performance best practices](https://docs.flutter.dev/perf/best-practices)).

The reason the caveat exists is the same reason `saveLayer` exists: without a
layer each part of a group is painted individually, so overlaps come out darker
than non-overlaps; grouping via `saveLayer` lets the whole group be drawn opaque
and then made transparent as a unit
([Canvas.saveLayer](https://api.flutter.dev/flutter/dart-ui/Canvas/saveLayer.html)).

**Never animate `Opacity` directly.** Animating an `Opacity` widget causes the
widget (and possibly its subtree) to rebuild every frame, which is not very
efficient; use `AnimatedOpacity` (which animates opacity efficiently via an
internal animation) or `FadeTransition` (same, driven by a supplied animation)
([Opacity](https://api.flutter.dev/flutter/widgets/Opacity-class.html)).
Best practices states it as a hard rule: avoid the `Opacity` widget, and
particularly avoid it in an animation; use `AnimatedOpacity` or `FadeInImage`
([Performance best practices](https://docs.flutter.dev/perf/best-practices)).

For images specifically, `FadeInImage` applies a gradual opacity using the GPU's
fragment shader ([Performance best practices](https://docs.flutter.dev/perf/best-practices)),
and an image can carry opacity directly via `color` + `colorBlendMode:
BlendMode.modulate` instead of an `Opacity` wrapper
([Opacity](https://api.flutter.dev/flutter/widgets/Opacity-class.html)).

Two gotchas worth knowing here: opacity zero does **not** stop hit testing on
descendants, and the intermediate buffer (transparent background by default) can
change how a child `BackdropFilter` behaves — it will only filter content between
the `Opacity` and the backdrop child, and may need `BackdropFilter.blendMode`
adjusted ([Opacity](https://api.flutter.dev/flutter/widgets/Opacity-class.html)).
`BackdropFilter`'s own page makes the same point from the other side: `srcOver` is
the only universally supported blend mode, but when a parent uses a temporary
buffer or save layer — as `Opacity` does — `BlendMode.src` can give more pleasing
results ([BackdropFilter](https://api.flutter.dev/flutter/widgets/BackdropFilter-class.html)).

**Rules for the card:** all frost alpha goes into `Color.withValues(alpha: …)` on
the `Paint`/gradient stops — which is what the current painter does. Never wrap
the card face or a frost sub-layer in `Opacity`. If the glass panes sit under an
`Opacity`, expect the backdrop blur to look wrong and to need `BlendMode.src`.

### 1.7 Clipping

Clipping does **not** call `saveLayer` unless you explicitly ask for
`Clip.antiAliasWithSaveLayer` — so it is not as expensive as `Opacity` — but it is
still costly, so use with caution. Clipping is off by default (`Clip.none`) and
must be explicitly enabled
([Performance best practices](https://docs.flutter.dev/perf/best-practices)).
Flutter's default is to not clip except for a few specialised widgets such as
`ClipRect` ([Clip behavior](https://docs.flutter.dev/release/breaking-changes/clip-behavior)).

Specific documented substitutions:

- For a rectangle with rounded corners, use the `borderRadius` property offered by
  many widget classes instead of applying a clipping rectangle
  ([Performance best practices](https://docs.flutter.dev/perf/best-practices)).
- Avoid clipping in an animation; if possible, pre-clip the image before animating
  it ([Performance best practices](https://docs.flutter.dev/perf/best-practices)).
- Consider overlaying opaque corners onto a square instead of clipping to a
  rounded rectangle ([Flutter performance profiling](https://docs.flutter.dev/perf/ui-performance)).
- Inside a painter: prefer `drawRRect` over `clipRRect` + `drawPaint`
  ([Canvas.saveLayer](https://api.flutter.dev/flutter/dart-ui/Canvas/saveLayer.html)).

Caveat in the other direction: `CustomPaint` painters are expected to paint within
the origin-anchored rectangle of the given size; painting outside those bounds may
mean insufficient memory was allocated to rasterise the commands, and the
resulting behaviour is **undefined**. To enforce the bounds, wrap the `CustomPaint`
in a `ClipRect` ([CustomPaint](https://api.flutter.dev/flutter/widgets/CustomPaint-class.html)).

**Rule for the card:** keep every frost draw inside the card rect analytically
(the painter already derives everything from `rect`/`size.width`), so no clip is
needed at all. If a needle can overshoot, clamp its geometry rather than adding a
clip per frame.

### 1.8 `Transform` vs relayout

`Transform` applies its transformation **just prior to painting**, so the
transformation is not taken into account when calculating how much space the child
consumes — as opposed to `RotatedBox`, which rotates during layout
([Transform](https://api.flutter.dev/flutter/widgets/Transform-class.html)).

That is the whole argument: animate `Transform.scale`/`translate`/`rotate` and you
pay paint; animate width/height/padding/`RotatedBox` and you pay layout, every
frame, up and down the subtree. Flutter's layout is designed for linear initial
layout and sublinear updates in the common case, but intrinsic (second) passes
break that and slow performance
([Inside Flutter](https://docs.flutter.dev/resources/architectural-overview),
[Performance best practices](https://docs.flutter.dev/perf/best-practices)).
Intrinsic passes can be detected with the **Track layouts** option in DevTools,
where events are labelled `$runtimeType intrinsics`
([Performance best practices](https://docs.flutter.dev/perf/best-practices)).

**Rule for the card:** the recoil "squeeze" must stay a `Transform.scale`, never an
animated `SizedBox`/padding. The existing early-out — skip the `Transform`
entirely when the squeeze is under ~a tenth of a pixel — is the right instinct: it
removes a render object from the paint path at rest.

### 1.9 Build cost: const constructors, widget splitting, and building only what changed

Documented `build()` rules ([Performance best practices](https://docs.flutter.dev/perf/best-practices)):

- Avoid repetitive and costly work in `build()`; it can be invoked frequently when
  ancestors rebuild.
- Avoid one very large widget with a large `build()`. Split by encapsulation **and
  by how things change**.
- `setState()` rebuilds all descendants. Localise the `setState` to the part of the
  subtree whose UI actually needs to change; do not call it high in the tree for a
  change contained to a small part.
- Rebuild traversal **stops** when the same instance of a child widget as the
  previous frame is re-encountered ("same instance" evaluated with `operator ==`).
  This is used heavily inside the framework to optimise animations that do not
  affect the child subtree — see `SlideTransition`.
- Use `const` constructors on widgets as much as possible: they let Flutter
  short-circuit most of the rebuild work. Enable the recommended lints from
  `flutter_lints` to be reminded.
- Prefer a `StatelessWidget` over a function for reusable UI pieces.
- **Do not override `operator ==` on widgets.** It looks like it avoids rebuilds
  but in practice hurts, producing O(N²) behaviour. The only exception is leaf
  widgets where comparing properties is significantly cheaper than rebuilding and
  configuration rarely changes — and even then, prefer caching the widgets,
  because a single `operator ==` override can degrade performance across the board
  since the compiler can no longer assume the call is static.

**Building only what changed — the `child` parameter.** Both builder families
document the same optimisation in the same words:

- `AnimatedBuilder`: if the builder function contains a subtree that does not
  depend on the animation, it is more efficient to build that subtree once. Pass
  it as `child` and the builder receives it back to incorporate. Optional, but can
  improve performance significantly and is therefore good practice
  ([AnimatedBuilder](https://api.flutter.dev/flutter/widgets/AnimatedBuilder-class.html)).
- `ValueListenableBuilder`: identical guidance for value-independent subtrees
  ([ValueListenableBuilder](https://api.flutter.dev/flutter/widgets/ValueListenableBuilder-class.html)).
- Best practices restates it as a rule: when using `AnimatedBuilder`, avoid putting
  a subtree in the builder that does not depend on the animation — that subtree is
  rebuilt for every tick
  ([Performance best practices](https://docs.flutter.dev/perf/best-practices)).

Note also that `AnimatedBuilder` is not limited to `Animation`s — any `Listenable`
(`ChangeNotifier`, `ValueNotifier`) triggers rebuilds; if the thing is not an
`Animation`, `ListenableBuilder` is the more readable equivalent with an identical
implementation ([AnimatedBuilder](https://api.flutter.dev/flutter/widgets/AnimatedBuilder-class.html)).

**Rules for the card:**
1. Every `AnimatedBuilder` in the card path must pass the static card content as
   `child` (the current `_FrostedFace` and `_Recoil` both do — keep it that way).
2. Better still, for the painter itself, skip the builder: `CustomPainter(repaint:
   frost)` per §1.3.
3. Card content widgets `const` wherever the analyzer allows.
4. Never override `operator ==` on the card widgets to "help" the frost.


---

## 2. The cost model: what makes a frame expensive on Impeller

### 2.1 Where the work happens

Four engine threads matter; only two are visible in the performance overlay
([Flutter performance profiling](https://docs.flutter.dev/perf/ui-performance)):

| Thread | Runs | Shown in overlay |
|---|---|---|
| **Platform** | platform main thread, plugin code | no |
| **UI** | all your Dart code + framework; produces a layer tree of device-agnostic painting commands | yes (bottom row) |
| **Raster** | consumes the layer tree, talks to the GPU; **Skia and Impeller both run here** — and the thread itself runs on the CPU | yes (top row) |
| **I/O** | expensive I/O that would otherwise block UI or raster | no |

The critical asymmetry for this codebase: *you cannot touch the raster thread
directly, but everything slow on it is a consequence of what your Dart code
emitted* ([Flutter performance profiling](https://docs.flutter.dev/perf/ui-performance),
[Use the Performance view](https://docs.flutter.dev/tools/devtools/performance)).
A layer tree can be cheap to construct and expensive to rasterise — that is
exactly the frost/glass failure mode: clean UI graph, red raster graph.

Frame lifecycle, engine-side: a frame is requested via `RequestFrame` in the
`Animator`, waits for a vsync, then `BeginFrame` reserves a slot in the frame
**pipeline** which coordinates UI and Raster threads; the framework produces a
`Scene` (a `LayerTree` engine-side) handed back through `FlutterView.render`; the
rasterizer then acquires a surface and walks the layer tree with recursive
`Preroll`/`Paint` calls that resolve to Skia or Impeller, then submits to the GPU
([Life of a Flutter Frame](https://github.com/flutter/flutter/blob/master/docs/engine/Life-of-a-Flutter-Frame.md)).
Because the pipeline is a pipeline, build and raster can each be under budget
while *latency* still exceeds a frame — documented as "animations will be smooth
but touch input will feel more sluggish"
([addTimingsCallback](https://api.flutter.dev/flutter/scheduler/SchedulerBinding/addTimingsCallback.html)).

### 2.2 `saveLayer`: render target switches

The documented mechanism, not a heuristic: `saveLayer()` allocates an offscreen
buffer, and drawing into that buffer **might trigger a render target switch**.
The docs' own metaphor — the GPU wants to run like a firehose, and a render target
switch forces it to redirect the stream and then redirect it back; **on mobile GPUs
this is particularly disruptive to rendering throughput**
([Performance best practices](https://docs.flutter.dev/perf/best-practices)).
It is called "one of the most expensive methods in the Flutter framework"
([Flutter performance profiling](https://docs.flutter.dev/perf/ui-performance)).

Implicit sources the docs name: `Opacity` (for values strictly between 0.0 and
1.0), `ShaderMask`, `ColorFilter`, `Clip.antiAliasWithSaveLayer`, `Chip` when
`disabledColorAlpha != 0xff`, and `Text` when there is an `overflowShader`
([Performance best practices](https://docs.flutter.dev/perf/best-practices),
[Flutter performance profiling](https://docs.flutter.dev/perf/ui-performance)).

The one documented case where `saveLayer` is genuinely *required*: dynamically
sourced shapes, each with transparency, that may or may not overlap
([Performance best practices](https://docs.flutter.dev/perf/best-practices)).
Note this describes ice needles almost exactly — which is why the escape hatch
matters: if the overlap is always the same amount, same way, same transparency,
**precalculate the composited semi-transparent result, cache it, and draw that
instead**; this works for any static shape you can precalculate
([Performance best practices](https://docs.flutter.dev/perf/best-practices)).

### 2.3 Blur and `MaskFilter`: the documented reason the 576-draw-call version failed

- `MaskFilter.blur` takes the shape being drawn and blurs it; `sigma` is the
  Gaussian standard deviation and corresponds to **roughly half the radius of the
  effect in pixels**; and, verbatim in intent: a blur is an expensive operation and
  should be used sparingly. The docs point at `Canvas.drawShadow` as the more
  efficient way to draw shadows
  ([MaskFilter.blur](https://api.flutter.dev/flutter/dart-ui/MaskFilter/MaskFilter.blur.html)).
- `ImageFilter` is listed outright among the costly operations to be careful with,
  alongside `Opacity` and `Clip.antiAliasWithSaveLayer`
  ([Performance FAQ](https://docs.flutter.dev/perf/faq)).
- `BackdropFilter` is "relatively expensive, **especially if the filter is
  non-local, such as a blur**"; and for the single-child case `ImageFiltered` is
  documented as both easier and **less expensive**, with performance "improved
  dramatically for complex filters like blurs"
  ([BackdropFilter](https://api.flutter.dev/flutter/widgets/BackdropFilter-class.html)).

**Diagnosis of the documented regression.** Blurring each needle individually is
N independent non-local filter operations. Each blurred shape is its own filtered
draw, and each one that needs an offscreen buffer risks its own render target
switch (§2.2). 288 blurred draws is 288 opportunities for that. The documented
remedies, in order of preference:

1. Don't blur per-shape. Blur **once** over the accumulated group, or bake the
   soft edge into the geometry/gradient instead of a filter.
2. If the group genuinely needs one blur, that is one `saveLayer` + one
   `ImageFilter`, not N `MaskFilter`s.
3. If the frost pattern is static in shape and only *moves* or *fades*, precalculate
   and cache it, then animate the cheap transform/alpha
   ([Performance best practices](https://docs.flutter.dev/perf/best-practices)).

### 2.4 "Liquid glass" panes: `BackdropGroup` is the documented multiplier fix

This is the single highest-leverage official API for your backdrop panes. Multiple
backdrop filters **can be combined into a single rendering operation by the engine**
when they share a common `BackdropKey`. The key identifies the filter input; when
shared it signals the filtering can be performed once, which "can significantly
reduce the overhead of using multiple backdrop filters in a scene." Supply it via
the `backdropKey` parameter or look it up from a `BackdropGroup` ancestor using
the `.grouped` constructor. The docs' own example wraps a 60-item `ListView` in a
`BackdropGroup` with `BackdropFilter.grouped` and `sigmaX/sigmaY: 40` — the engine
performs **one** backdrop blur, visually identical to 60
([BackdropFilter](https://api.flutter.dev/flutter/widgets/BackdropFilter-class.html)).

Two documented constraints: overlapping backdrop filters must **not** share a key
or the result may look as if only one filter applied in the overlap region; and
without a surrounding `ClipRect` a `BackdropFilter` applies to the **whole screen**
([BackdropFilter](https://api.flutter.dev/flutter/widgets/BackdropFilter-class.html),
[Writing and using fragment shaders](https://docs.flutter.dev/ui/design/graphics/fragment-shaders)).

Also: `BlendMode.srcOver` is the only `blendMode` value supported on all platforms;
it can surprise you when an ancestor uses a temporary buffer or save layer (as
`Opacity` does), where `BlendMode.src` may look better
([BackdropFilter](https://api.flutter.dev/flutter/widgets/BackdropFilter-class.html)).
`Opacity` also has a documented interaction: its intermediate buffer is
transparent by default, so a `BackdropFilter` child can only filter content
between it and the backdrop child
([Opacity](https://api.flutter.dev/flutter/widgets/Opacity-class.html)).

### 2.5 Blend modes on Impeller: pipeline vs advanced (directly relevant to glass)

Impeller splits blend modes into two classes
([Impeller: Color blending](https://github.com/flutter/flutter/blob/master/docs/engine/impeller/docs/blending.md)):

- **Pipeline blends** — implemented with the backend's raster pipeline blend
  configuration. "**Always cheap and don't require additional draw calls.**"
  Set: Clear, Source, Destination, SourceOver, DestinationOver, SourceIn,
  DestinationIn, SourceOut, DestinationOut, SourceATop, DestinationATop, Xor,
  Plus, Modulate.
- **Advanced blends** — computed with a fragment program that reads the backdrop.
  Set: Screen, Overlay, Darken, Lighten, ColorDodge, ColorBurn, HardLight,
  SoftLight, Difference, Exclusion, Multiply, Hue, Saturation, Color, Luminosity.
  More expensive than pipeline blends (which are "essentially free"), and the cost
  depends on **framebuffer fetch** support:
  - *Supported* (all Metal devices with Apple A8+ GPU, most Vulkan devices): a
    framebuffer-fetch shader reads the backdrop directly **without ending the
    render pass**; no backdrop texture copy, no intermediary blit. Cheaper than
    the legacy path but still costlier than a pipeline blend.
  - *Not supported* (OpenGL ES devices, iOS simulator, Adreno 630 and below,
    PowerVR): **the current render pass ends**, a potentially large backdrop
    texture is sampled, and an intermediary texture is allocated for the blend
    output before being blitted back.

**Actionable:** if the liquid-glass look currently uses `BlendMode.overlay`,
`softLight`, `screen`, `multiply`, `luminosity` etc., you are paying advanced-blend
cost per use, and on the low end you are paying a render pass break per use.
Reaching the same look with `srcOver`/`plus`/`modulate` plus a tuned gradient is
categorically cheaper, not marginally.

### 2.6 Shader compilation and warm-up: is shader jank still a problem on Impeller?

**For engine-drawn content: no, by construction.** The documented design:

- Impeller "precompiles a smaller, simpler set of shaders at engine-build time so
  they don't compile at runtime"; it compiles all shaders and reflection offline
  at build time, builds all pipeline state objects upfront, and controls caching
  explicitly ([Impeller rendering engine](https://docs.flutter.dev/perf/impeller)).
- Quantitatively: Impeller has a **bounded set of shaders (< 50)** known ahead of
  time; **all graphics pipelines it needs are ready before the Dart isolate
  launches**; there is **no runtime shader generation, reflection, or compilation**;
  and it adds only ~**100 KB** of binary size (compressed) with all shaders
  packaged. By contrast Skia can generate and compile shaders during frame
  workloads, "leading to worse worst-frame times." Removing Skia GPU (including
  the SkSL compilation machinery) cut engine binary size by 17%
  ([Impeller FAQ](https://github.com/flutter/flutter/blob/master/docs/engine/impeller/docs/faq.md)).
- The team's own summary: since enabling Impeller by default on iOS, "the vast
  majority of open issues around shader compilation causing jank" are fixed, and
  Impeller outperforms the old renderer both on worst-frame benchmarks and on
  average ([Impeller FAQ](https://github.com/flutter/flutter/blob/master/docs/engine/impeller/docs/faq.md)).
- Consequently the official first-run-jank advice is now just "make sure you're
  using Flutter's default graphic renderer, Impeller"
  ([Improving rendering performance](https://docs.flutter.dev/perf/shader)).
- Historical context worth knowing so you don't resurrect a dead workaround: the
  SkSL capture/warm-up scheme moved the burden onto developers, bloated app size,
  delayed launch (some first frames as high as **6 seconds** for apps that trained
  effectively), produced device-inconsistent shaders, and was abandoned — "no
  application in Google used this"
  ([Impeller FAQ](https://github.com/flutter/flutter/blob/master/docs/engine/impeller/docs/faq.md)).
  Do **not** add `ShaderWarmUp`, `--cache-sksl`, or
  `--dump-skp-on-shader-compilation` to this project.

**Three residual caveats that do apply to you:**

1. **Your own `.frag` shaders.** The `flutter` CLI compiles declared shaders to the
   backend format at build time and generates runtime metadata
   ([Writing and using fragment shaders](https://docs.flutter.dev/ui/design/graphics/fragment-shaders)).
   But the same page's Performance considerations section warns that **when
   targeting the Skia backend** loading a shader may be expensive because it is
   compiled at runtime, and advises precaching `FragmentProgram` objects before an
   animation starts. It also states plainly: **reuse a `FragmentShader` object
   across frames; that is more efficient than creating a new one each frame.**
2. **Android fallback.** Impeller is enabled by default on **Android API 29+**; on
   lower versions or devices without Vulkan, Flutter falls back to the legacy
   OpenGL renderer automatically ([Impeller rendering engine](https://docs.flutter.dev/perf/impeller)).
   On that path, Skia-era shader-compilation jank is back in scope. iOS is
   Impeller-only with no ability to switch to Skia; web still uses Skia.
3. **DevTools still has a shader-compilation signal.** Frames performing shader
   compilation are marked **dark red** in the Flutter frames chart
   ([Use the Performance view](https://docs.flutter.dev/tools/devtools/performance)).
   If you ever see those, you have found a real one — investigate rather than
   assume it is impossible.

There is also an engine switch `--impeller-lazy-shader-mode`, which *defers*
initialization of all required PSOs and **defaults to false**
([switch_defs.h](https://github.com/flutter/flutter/blob/master/engine/src/flutter/shell/common/switch_defs.h)).
Leave it alone; enabling it reintroduces runtime pipeline setup.

### 2.7 Custom shader authoring cost, per the Impeller team

From Impeller's own shader guidance
([Writing efficient shaders](https://github.com/flutter/flutter/blob/master/docs/engine/impeller/docs/shader_optimization.md)) —
directly applicable to hand-written liquid-glass fragment shaders:

- There is **no single optimal strategy**; drivers and vendors differ, and
  optimizing for one driver can regress others. Flutter supports mobile GPUs more
  than a decade old.
- Two architecture families: **instruction-level parallelism** (SIMD/VLIW; e.g.
  PowerVR GT7600 in the iPhone 6s) and **thread-level parallelism** (SIMT; warps
  or wavefronts, usually **32 or 64 threads**). Most GPUs released after ~2015 are
  SIMT.
- On SIMD/VLIW, instructions inside a non-uniform (varying) branch incur a
  **`1/[data width]` performance penalty** because they cannot be parallelized. On
  SIMT the best case is just the cost of the conditional; the worst case is both
  paths executed back-to-back for the warp.
- Recommendations: **don't flatten uniform or constant branches**; **don't flatten
  simple varying branches** (flattened branches can measure *worse* on SIMT);
  **avoid complex varying branches**; beware `return`-style early exits, which
  compile to two exclusive paths; and **use lower precision (`mediump`/`lowp`)
  wherever possible** since many mobile GPUs (e.g. Qualcomm Adreno) execute
  reduced-precision float ops more efficiently.
- Profile against **old** hardware (the doc names the iPhone 6s) and against both
  Metal and GLES backends, because early-stage shader compilation and the
  high-level code ImpellerC generates can differ noticeably between APIs.

Flutter-specific shader constraints you must respect: no UBOs/SSBOs; `sampler2D`
is the only sampler type; only the two-argument `texture(sampler, uv)`; no extra
varying inputs; no unsigned ints or bools; `fragColor` must be normalized 0.0–1.0
with **premultiplied** alpha (unlike Flutter's own 0–255 unpremultiplied colors);
prefer `FlutterFragCoord()` over `gl_FragCoord` because the Skia-side rewrite of
`gl_FragCoord` to local coordinates **is not possible with Impeller**; and on
OpenGL ES, engine-supplied texture y-coordinates are flipped and must be un-flipped
([Writing and using fragment shaders](https://docs.flutter.dev/ui/design/graphics/fragment-shaders)).
Impeller also assumes **premultiplied source colors** throughout for blending
([Impeller: Color blending](https://github.com/flutter/flutter/blob/master/docs/engine/impeller/docs/blending.md)).

### 2.8 Clips, opacity intersections, shadows

The documented list of workloads that are "more difficult for the GPU":
unnecessary `saveLayer` calls, **intersecting opacities with multiple objects**,
and clips or shadows in specific situations
([Flutter performance profiling](https://docs.flutter.dev/perf/ui-performance),
[Use the Performance view](https://docs.flutter.dev/tools/devtools/performance)).
Clipping does **not** call `saveLayer` unless you ask for
`Clip.antiAliasWithSaveLayer`, so it is not as expensive as `Opacity` — but it is
"still costly, so use with caution," and clipping is **disabled by default**
(`Clip.none`) so it only costs you if you opted in
([Performance best practices](https://docs.flutter.dev/perf/best-practices),
[Clip behavior](https://docs.flutter.dev/release/breaking-changes/clip-behavior)).
For a card face specifically: prefer the `borderRadius` property offered by many
widget classes over a clipping rectangle, and **avoid clipping in an animation** —
pre-clip if possible ([Performance best practices](https://docs.flutter.dev/perf/best-practices)).

### 2.9 Draw calls and overdraw: what "a lot" means

**Be explicit: Flutter's official docs do not publish a numeric draw-call budget,
and they do not publish an overdraw budget or an overdraw debug flag.** I found no
authoritative Flutter/Impeller statement of the form "N draw calls per frame is
too many." Anyone quoting one is not quoting the docs.

What *is* official and usable:

- Draw calls are counted by **GPU frame capture tools**, not by DevTools. Impeller's
  own guide walks through the Xcode Metal frame debugger (also naming RenderDoc and
  Android GPU Inspector) and shows the frame-overview panel reporting the number of
  draw calls, command buffers, and render command encoders; grouping by pipeline
  state is recommended for finding a *class* of draw calls in a complex app; and
  every Impeller GPU resource is labelled to make this readable
  ([Learning to read GPU frame captures](https://github.com/flutter/flutter/blob/master/docs/engine/impeller/docs/read_frame_captures.md)).
  That is the officially sanctioned way to verify a claim like "576 draw calls."
- The same doc endorses a hard rule you can apply directly: **texture allocations
  should not occur in a frame workload** — described as "universally prudent."
- The documented lever that removes draw calls in bulk: pipeline blends need **no
  additional draw calls**, and shared `BackdropKey`s collapse many backdrop filters
  into a single rendering operation (§2.4, §2.5).
- The nearest thing to an official overdraw story is the render-target-switch
  explanation for `saveLayer` (§2.2) plus "intersecting opacities with multiple
  objects" being called out as GPU-hostile (§2.8). Treat overdraw as a hypothesis
  you test with the DevTools layer toggles (§3.5), not as a metric Flutter reports.

**Practical stance for this codebase:** the meaningful budget is the one the docs
*do* give — ~8 ms of raster time (§1.1). Use draw-call counts from a frame capture
as the explanatory variable, and `FrameTiming.rasterDuration` as the pass/fail
criterion.

### 2.10 Impeller vs Skia: the differences that matter here

| Concern | Documented difference |
|---|---|
| Shader compilation | Impeller: offline, build-time, `< 50` shaders, all PSOs ready before the isolate starts, no runtime generation/reflection/compilation. Skia: can generate and compile shaders during frame workloads → worse worst-frame times. ([Impeller FAQ](https://github.com/flutter/flutter/blob/master/docs/engine/impeller/docs/faq.md)) |
| Blend modes | Impeller explicitly classifies pipeline (free, no extra draw calls) vs advanced (fragment program, framebuffer-fetch dependent, may end the render pass on older GPUs). ([blending.md](https://github.com/flutter/flutter/blob/master/docs/engine/impeller/docs/blending.md)) |
| Custom shaders | `gl_FragCoord` → local-coordinate rewriting is **not** possible on Impeller; precision hints are ignored **when targeting Skia**; runtime shader-load cost is called out for the **Skia** backend. ([fragment shaders](https://docs.flutter.dev/ui/design/graphics/fragment-shaders)) |
| Skia still present | Impeller has no direct Skia dependency and creates no Skia graphics context, but Flutter still uses SkParagraph for text layout/shaping and Skia-wrapped image codecs. ([Impeller FAQ](https://github.com/flutter/flutter/blob/master/docs/engine/impeller/docs/faq.md)) |
| Software rendering | Impeller has **no** software backend (Skia does); software rendering requires SwiftShader/LLVMPipe-style Vulkan/GL implementations. ([Impeller FAQ](https://github.com/flutter/flutter/blob/master/docs/engine/impeller/docs/faq.md)) |
| Platform reach | iOS: Impeller only, no switch to Skia. Android: default on API 29+, falls back to legacy OpenGL renderer below that or without Vulkan. Web: Skia. macOS: opt-out being removed. ([Impeller rendering engine](https://docs.flutter.dev/perf/impeller)) |
| Concurrency | Impeller can distribute single-frame workloads across multiple threads if necessary. ([Impeller rendering engine](https://docs.flutter.dev/perf/impeller)) |
| Instrumentation | Impeller tags and labels all graphics resources and can capture/persist animations to disk **without affecting per-frame rendering performance**. ([Impeller rendering engine](https://docs.flutter.dev/perf/impeller)) |

Not relevant but worth knowing so nobody proposes it: Flutter has **no plans** to
adopt Skia Graphite, and **no plans** for a WebGPU/Dawn Impeller backend (as of
May 2025), largely on binary-size and feature-access grounds
([Impeller FAQ](https://github.com/flutter/flutter/blob/master/docs/engine/impeller/docs/faq.md)).

---

## 3. How to measure — officially recommended tooling

### 3.1 Preconditions (non-negotiable, and the docs are blunt about it)

- **Profile mode, physical device.** "Almost all performance debugging for Flutter
  applications should be conducted on a physical Android or iOS device, with your
  Flutter application running in profile mode." Debug mode, simulators and
  emulators are "generally not indicative of the final behavior of release mode
  builds," and you should check performance **on the slowest device your users
  might reasonably use**. Profile mode compiles and launches almost identically to
  release, with just enough extra to allow performance debugging
  ([Flutter performance profiling](https://docs.flutter.dev/perf/ui-performance)).
- Launch it: `flutter run --profile`; or `"flutterMode": "profile"` in VS Code's
  `launch.json`; or *Run > Flutter Run main.dart in Profile Mode* in Android
  Studio/IntelliJ ([Flutter performance profiling](https://docs.flutter.dev/perf/ui-performance)).
- Debug-mode numbers are explicitly unreliable for `FrameTiming` too: metrics in
  debug mode "may be very different" due to debug overhead, so monitor only in
  profile and release ([FrameTiming](https://api.flutter.dev/flutter/dart-ui/FrameTiming-class.html)).

### 3.2 Frame budget, quantitatively

| Refresh rate | Budget the docs state |
|---|---|
| 60 Hz | each frame must render in **~16 ms** or less; a frame exceeding it fails to display → jank ([profiling](https://docs.flutter.dev/perf/ui-performance), [DevTools](https://docs.flutter.dev/tools/devtools/performance)) |
| 60 Hz, split | **16 ms for building and 16 ms for rendering**, but if latency matters: built in **≤8 ms** and rendered in **≤8 ms** for ≤16 ms total ([best practices](https://docs.flutter.dev/perf/best-practices)) |
| 120 Hz | render frames in **under 8 ms total** ([best practices](https://docs.flutter.dev/perf/best-practices)); Flutter targets 120 fps on capable devices ([DevTools](https://docs.flutter.dev/tools/devtools/performance)) |

Note the docs give both framings — "16 ms per thread" and "8 ms each for ≤16 ms
total." They are not contradictory: 16 ms is the throughput bound per thread, 8+8
is the latency bound. For an interactive card you tap and flip, **use 8+8**.
`addTimingsCallback`'s own doc uses "e.g. 16ms at 60Hz" as the frame budget against
which to compare `buildDuration` and `rasterDuration`
([addTimingsCallback](https://api.flutter.dev/flutter/scheduler/SchedulerBinding/addTimingsCallback.html)).

To read the *actual* target rather than assuming, the docs point to "Get the
display refresh rate" ([Performance FAQ](https://docs.flutter.dev/perf/faq)).

### 3.3 Performance overlay — fastest triage

Toggle it from the DevTools **Performance view** overlay button, with the `P` key
from the command line, or programmatically
([Flutter performance profiling](https://docs.flutter.dev/perf/ui-performance)).
How to read it:

- Two graphs, each showing the **last 300 frames**. Top = **raster** thread
  (labelled "GPU"), bottom = **UI** thread. Horizontal axis is frames; the graph
  only updates while the app paints.
- **White lines mark 16 ms increments.** Crossing one means you are below 60 Hz.
- A **vertical red bar** marks a frame that failed to display. Red in the UI graph
  ⇒ Dart code too expensive. Red in the GPU/raster graph ⇒ scene too complicated
  to rasterise. **If both are red, diagnose the UI thread first**; and if the UI
  graph is red, profile the Dart VM first even when the GPU graph is also red.
- The engine paints the overlay itself, so it "only minimally impacts performance"
  — but view it in profile mode only, because debug performance is intentionally
  sacrificed for asserts and the results are misleading.

([Flutter performance profiling](https://docs.flutter.dev/perf/ui-performance))

### 3.4 DevTools Performance view

Four components: **Flutter frames chart**, **Frame analysis** tab, **Timeline
events** trace viewer, and **advanced debugging tools**; plus snapshot
import/export (DevTools only imports what DevTools exported)
([Use the Performance view](https://docs.flutter.dev/tools/devtools/performance)).

- Each bar **pair** is one frame, colour-coded into UI-thread and raster-thread
  portions. Selecting a frame drives the panes below. Pause updates with the pause
  button.
- Janky frames get a **red overlay** (>~16 ms at 60 fps). Frames performing
  **shader compilation are dark red**.
- **Frame analysis** tab: select a red frame and DevTools surfaces debugging hints
  and flags expensive operations it detected as likely contributors.
- **Timeline events**: everything the framework emits while building frames and
  drawing scenes, plus HTTP timings and GC — and your own events via
  `dart:developer`'s `Timeline` / `TimelineTask`.

### 3.5 Enhance tracing and the layer kill-switches

Under the **enhance tracing** dropdown ([DevTools](https://docs.flutter.dev/tools/devtools/performance)):

- **Track widget builds** — `build()` events, labelled with the widget name.
- **Track layouts** — render-object layout events. Also the documented way to
  detect excessive **intrinsic passes**, which appear as `$runtimeType intrinsics`
  ([best practices](https://docs.flutter.dev/perf/best-practices)).
- **Track paints** — render-object paint events.

Then, the experiment that actually isolates your suspects. Three rendering layers
can be **toggled off** (all enabled by default): **Render Clip layers**, **Render
Opacity layers**, **Render Physical Shape layers** (shadows/elevation). Reproduce
the activity with a layer disabled, select the new frames, and compare: "If raster
time has significantly decreased, excessive use of the effects you disabled might
be contributing to the jank"
([Use the Performance view](https://docs.flutter.dev/tools/devtools/performance)).
For a frost card with rounded clipping, elevation shadows and translucent panes,
this is the highest-signal five minutes available.

Two more official tricks:

- **Slow Animations** button in the Flutter inspector slows animations **5×** (also
  doable programmatically) — use it to answer "is the slowness on the first frame,
  or the whole animation?"
  ([Flutter performance profiling](https://docs.flutter.dev/perf/ui-performance)).
- **`checkerboardOffscreenLayers`** (`PerformanceOverlayLayer.checkerboardOffscreenLayers`,
  exposed in the DevTools Performance view) tells you when your scene uses
  `saveLayer`; `saveLayer()` also emits a DevTools timeline event
  ([best practices](https://docs.flutter.dev/perf/best-practices)).
  There is a matching `checkerboardRasterCacheImages` toggle for raster-cache
  images ([profiling](https://docs.flutter.dev/perf/ui-performance)).

### 3.6 `FrameTiming` + `SchedulerBinding.addTimingsCallback` — in-app measurement

The recommended programmatic path. Use `SchedulerBinding.addTimingsCallback`
rather than `PlatformDispatcher.onReportTimings` directly, because the latter
allows only one callback while the former supports many
([addTimingsCallback](https://api.flutter.dev/flutter/scheduler/SchedulerBinding/addTimingsCallback.html),
[FrameTiming](https://api.flutter.dev/flutter/dart-ui/FrameTiming-class.html)).

Documented behaviour, with numbers:

- Data is **batched** into lists of `FrameTiming`, reported **approximately once a
  second in release mode** and **approximately every 100 ms in debug and profile**
  builds, in ascending chronological order. The **first frame is sent immediately,
  unbatched**.
- **Overhead:** in release builds with no registered callbacks, `onReportTimings`
  is not set at all, so tracking is disabled and runtime cost is ~zero. With one or
  more callbacks registered, overhead is "very approximately **0.01% CPU usage per
  second** (measured on an iPhone 6s)." In debug and profile builds `SchedulerBinding`
  registers its own timings callback to update the Timeline.
- Adding the same callback twice executes it twice.

Fields worth logging for this feature
([FrameTiming](https://api.flutter.dev/flutter/dart-ui/FrameTiming-class.html)):

| Field | Meaning | Use for |
|---|---|---|
| `buildDuration` | time to build the frame on the UI thread | UI-thread budget (§3.2) |
| `rasterDuration` | time to rasterize on the raster thread | **the frost/glass metric** |
| `totalSpan` | vsync start → raster finish | latency / pipelining detection |
| `vsyncOverhead` | vsync signal → build start | scheduling pressure |
| `layerCacheCount` / `layerCacheBytes` / `layerCacheMegabytes` | layers in the raster cache and their bytes | proving a `RepaintBoundary` is buying or burning GPU memory |
| `pictureCacheCount` / `pictureCacheBytes` / `pictureCacheMegabytes` | cached pictures and their bytes | same, for `isComplex`/`willChange` hints |

The doc spells out the pipelining trap: no frames missed, yet latency exceeding one
frame because `buildDuration + rasterDuration` together exceed the budget —
"animations will be smooth but touch input will feel more sluggish." For a card you
tap to flip, that is a real regression the frames chart alone will not show.

**Suggested harness:** register a callback in profile mode, keep a rolling window,
and record p50/p95/p99 of `rasterDuration` and `totalSpan` plus the count of frames
over 8 ms and over 16 ms, with the frost animation running and again with it
disabled. That gives you the before/after number the 576-draw-call regression
lacked.

### 3.7 `dart:developer` Timeline

Add tracing directly into your Dart code with the `dart:developer` package and view
it in DevTools ([profiling](https://docs.flutter.dev/perf/ui-performance)); the
Timeline events tab explicitly supports your own `Timeline` and `TimelineTask`
events ([DevTools](https://docs.flutter.dev/tools/devtools/performance)). Wrap the
frost path generation and the painter body in named sync blocks so they appear
alongside the framework's own events.

### 3.8 `debugProfilePaintsEnabled` — useful, with a documented caveat

Adds Timeline events for **every** `RenderObject` painted. The caveat is stated
outright: **the timing information is not representative of actual paints**,
because the overhead of adding timeline events is significant relative to the time
each object takes to paint. In debug builds it also includes render-object
properties, which is expensive and makes traces further unrepresentative (that
extra data is omitted in profile builds). What it *is* good for: **exposing
unexpected painting**. Siblings: `debugProfileBuildsEnabled`,
`debugProfileLayoutsEnabled`, `debugPrintRebuildDirtyWidgets`, `debugPrintLayouts`,
`debugEnhancePaintTimelineArguments`
([debugProfilePaintsEnabled](https://api.flutter.dev/flutter/rendering/debugProfilePaintsEnabled.html)).

Use it to answer "is anything outside the card repainting every tick?" — then
switch to `FrameTiming` for numbers.

Related visual flags: `debugRepaintRainbowEnabled` to watch repaints live
([RepaintBoundary](https://api.flutter.dev/flutter/widgets/RepaintBoundary-class.html)),
and `debugDumpRenderTree` to read each `RenderRepaintBoundary`'s
useful-vs-not-useful ratio (§1.2,
[RenderRepaintBoundary](https://api.flutter.dev/flutter/rendering/RenderRepaintBoundary-class.html)).

### 3.9 `--trace-skia` and friends — and why `--trace-skia` is the wrong tool here

Engine switches, as defined in the engine's own switch table
([switch_defs.h](https://github.com/flutter/flutter/blob/master/engine/src/flutter/shell/common/switch_defs.h)):

| Switch | Documented purpose |
|---|---|
| `--trace-skia` | **Trace Skia calls**; useful when debugging the GPU thread. Off by default to reduce traced events. |
| `--trace-skia-allowlist` | filter to specific Skia trace categories |
| `--trace-allowlist` | filter all trace events to allowed prefixes |
| `--trace-systrace` | trace to the system tracer instead of the timeline (Android and Fuchsia only) |
| `--trace-to-file` | write the trace to a file |
| `--endless-trace-buffer` | endless trace buffer — recommended so the buffer doesn't fill in a few frames ([Debugging the engine](https://github.com/flutter/flutter/blob/master/docs/engine/Debugging-the-engine.md)) |
| `--dump-skp-on-shader-compilation` | dump the SKP that triggered new shader compilation — for writing custom `ShaderWarmUp`. **Skia-era; see §2.6, do not use.** |

**The important caveat, stated plainly because the docs don't spell it out for
you:** `--trace-skia` traces *Skia* calls, and Impeller "has no direct
dependencies on Skia" and creates no Skia graphics context when rendering
([Impeller FAQ](https://github.com/flutter/flutter/blob/master/docs/engine/impeller/docs/faq.md)).
So on your iOS/Impeller-Android target, `--trace-skia` will not illuminate the
frost or glass raster cost. **I found no documented `--trace-impeller` equivalent.**
The officially documented substitutes are: (a) the DevTools raster-thread timeline,
(b) `FrameTiming.rasterDuration`, and (c) GPU frame captures via Xcode /
RenderDoc / Android GPU Inspector, for which Impeller ships dedicated guides
([Impeller rendering engine](https://docs.flutter.dev/perf/impeller),
[read_frame_captures.md](https://github.com/flutter/flutter/blob/master/docs/engine/impeller/docs/read_frame_captures.md)).

`--trace-skia` remains relevant only on the Android OpenGL fallback path (§2.6).

### 3.10 Other officially listed tools

Analysis/capture tools named by the Performance FAQ: Dart/Flutter DevTools, Apple
Instruments, Linux `perf`, Chrome tracing (`about:tracing`), Android systrace
(`adb systrace`), Fuchsia `fx traceutil`, Perfetto, speedscope
([Performance FAQ](https://docs.flutter.dev/perf/faq)). Benchmarking via the
Flutter Driver library / integration tests generates metrics for jank, download
size, battery efficiency and startup time
([profiling](https://docs.flutter.dev/perf/ui-performance)). The IntelliJ/Android
Studio **Widget Rebuild Profiler** shows rebuild counts for the current screen and
frame; the Flutter Performance window's **Show widget rebuild information**
checkbox helps detect >16 ms frames and links to relevant tips
([profiling](https://docs.flutter.dev/perf/ui-performance),
[best practices](https://docs.flutter.dev/perf/best-practices)).

If you file an Impeller bug, the docs ask for: device including chip information,
screenshots/recordings of visible issues, and a **zipped export of the performance
trace**, with the title prefixed `[Impeller]` and a small reproducible test case
([Impeller rendering engine](https://docs.flutter.dev/perf/impeller)).

---

## 4. Animation UX guidance (Flutter + Material Design 3)

### 4.1 A sourcing note, stated up front

`m3.material.io` is a client-rendered application and **could not be fetched as
readable text**, so I am not going to paraphrase pages I could not read. Instead,
the M3 token *values* below come from two authoritative places that mirror the same
spec and are machine-readable:

1. **Flutter's own `Durations` and `Easing` classes** in the material library,
   documented as "the set of durations / easing curves in the Material
   specification," each linking to the M3 duration and easing token pages
   ([Durations](https://api.flutter.dev/flutter/material/Durations-class.html),
   [Easing](https://api.flutter.dev/flutter/material/Easing-class.html)).
2. **Material Components for Android's Motion doc**, which publishes the token
   values and the intended usage of each slot
   ([Motion.md](https://github.com/material-components/material-components-android/blob/master/docs/theming/Motion.md)).

Use the Flutter constants in code; they are the spec, already typed.

### 4.2 Duration tokens (exact values)

`Durations` in `package:flutter/material.dart`
([Durations](https://api.flutter.dev/flutter/material/Durations-class.html)),
matching MDC-Android's `motionDuration*` attributes
([Motion.md](https://github.com/material-components/material-components-android/blob/master/docs/theming/Motion.md)):

| Token | Value | Token | Value |
|---|---|---|---|
| `Durations.short1` | 50 ms | `Durations.long1` | 450 ms |
| `Durations.short2` | 100 ms | `Durations.long2` | 500 ms |
| `Durations.short3` | 150 ms | `Durations.long3` | 550 ms |
| `Durations.short4` | 200 ms | `Durations.long4` | 600 ms |
| `Durations.medium1` | 250 ms | `Durations.extralong1` | 700 ms |
| `Durations.medium2` | 300 ms | `Durations.extralong2` | 800 ms |
| `Durations.medium3` | 350 ms | `Durations.extralong3` | 900 ms |
| `Durations.medium4` | 400 ms | `Durations.extralong4` | 1000 ms |

**The selection rule is quantitative in spirit if not in number:** duration should
**increase as the area/traversal of the animation increases**, and maintaining that
relationship is what gives an app a consistent sense of speed
([Motion.md](https://github.com/material-components/material-components-android/blob/master/docs/theming/Motion.md)).

Mapping that onto the card, with the caveat that **the docs do not prescribe
durations for decorative texture effects** — this is my application of the
area/traversal rule, not a quoted number:

| Motion | Suggested token | Why |
|---|---|---|
| Icon/label state flip, tap feedback | `short3`–`short4` (150–200 ms) | small area |
| Card press/recoil | `short4`–`medium2` (200–300 ms) | small traversal, must feel immediate |
| Card face flip | `medium4`–`long2` (400–500 ms) | large area, full-component transform |
| Frost forming/thawing as a **transition** | `long2`–`extralong1` (500–700 ms) | large area, and the point is to be perceived |
| Frost **ambient shimmer** | not a transition; see §5.4 | a looping effect, governed by accessibility rules, not duration tokens |

### 4.3 Easing tokens (exact curves) and when to use each

`Easing` constants: `standard`, `standardAccelerate`, `standardDecelerate`,
`emphasized`, `emphasizedAccelerate`, `emphasizedDecelerate`, `linear`, plus
`legacy`, `legacyAccelerate`, `legacyDecelerate` for M2
([Easing](https://api.flutter.dev/flutter/material/Easing-class.html)).
Values and intended use ([Motion.md](https://github.com/material-components/material-components-android/blob/master/docs/theming/Motion.md)):

| Token | Curve | Use for |
|---|---|---|
| `standard` | `cubic-bezier(0.2, 0, 0, 1)` | **utility-focused** animations that **begin and end on screen** |
| `standardDecelerate` | `cubic-bezier(0, 0, 0, 1)` | utility animations that **enter** the screen |
| `standardAccelerate` | `cubic-bezier(0.3, 0, 1, 1)` | utility animations that **exit** the screen |
| `emphasized` | path: `M 0,0 C 0.05,0 0.133333,0.06 0.166666,0.4 C 0.208333,0.82 0.25,1 1,1` | **common, M3-styled** animations that begin and end on screen |
| `emphasizedDecelerate` | `cubic-bezier(0.05, 0.7, 0.1, 1)` | M3-styled animations that **enter** the screen |
| `emphasizedAccelerate` | `cubic-bezier(0.3, 0, 0.8, 0.15)` | M3-styled animations that **exit** the screen |
| `linear` | `cubic-bezier(0, 0, 1, 1)` | simple, **non-stylized** motion |

Note `emphasized` is a **two-segment path, not a single cubic-bezier** — it has a
slow, deliberate lead-in before accelerating. That is why hand-rolled
`Curves.easeInOutCubic` approximations of "M3 feel" look wrong. Use
`Easing.emphasized`.

The mental model for *why* these three shapes exist, from Flutter's own (M2-era but
still-instructive) constant doc: elements that **begin and end at rest** use
standard easing — they speed up quickly and slow down gradually, **in order to
emphasize the end of the transition**
([standardEasing](https://api.flutter.dev/flutter/material/standardEasing-constant.html);
note this top-level constant is deprecated after v3.18.0-0.1.pre in favour of
`Easing.legacy` for M2 or `Easing.standard` for M3).

Ordering guidance: **apply the right easing type before adjusting duration**, since
easing adjustments affect perceived duration
([Material Design: Speed](https://m2.material.io/design/motion/speed.html) — page
not machine-readable; quoted from its search-indexed summary, so treat as
lower-confidence than the token tables above).

**For the card:** `Easing.emphasized` for the flip (begins and ends on screen,
M3-styled, deserves emphasis); `Easing.standard` for press/recoil; `Easing.linear`
**only** for the ambient frost loop, because any non-linear curve on a `repeat()`
produces a visible velocity discontinuity at the loop seam.

### 4.4 Springs (M3's newer motion axis)

M3 also defines a **physics** motion system of six spring tokens — three speeds ×
two types ([Motion.md](https://github.com/material-components/material-components-android/blob/master/docs/theming/Motion.md)):

| Token | Damping / stiffness | Intended scope |
|---|---|---|
| `motionSpringFastSpatial` | 0.9 / 1400 | small components (switches, buttons) |
| `motionSpringFastEffects` | 1 / 3800 | small-component effects (color, opacity) |
| `motionSpringDefaultSpatial` | 0.9 / 700 | partial-screen (bottom sheet, nav drawer) |
| `motionSpringDefaultEffects` | 1 / 1600 | partial-screen effects |
| `motionSpringSlowSpatial` | 0.9 / 300 | full-screen animations/transitions |
| `motionSpringSlowEffects` | 1 / 800 | full-screen effects |

Two rules encoded there: **choose the speed by size/distance** (small → fast,
full-screen → slow, in-between → default), and **choose spatial vs effects by the
property** — spatial for things that move on screen, **effects for properties like
color or opacity, which must not overshoot** (a background's alpha shouldn't
oscillate above 100%). A press animation that changes both shape and color uses
*two* springs: `FastSpatial` for shape/size and `FastEffects` for color.

These are Android theme attributes; **Flutter does not expose an equivalent
`Springs` token class**, but Flutter has the primitives — `SpringDescription`,
`SpringDescription.withDampingRatio`, `SpringSimulation`, and
`AnimationController.animateWith`
([Introduction to animations](https://docs.flutter.dev/ui/animations)) — so the
damping/stiffness pairs above transfer directly.

### 4.5 What motion should communicate, and choreography

Flutter's framing: well-designed animations make a UI feel **more intuitive**,
contribute to the polished look and feel, and **improve the user experience**; many
widgets, especially Material widgets, already ship the standard motion effects
defined in their design spec, and those effects can be customized
([Introduction to animations](https://docs.flutter.dev/ui/animations)).

Documented common patterns, i.e. the vocabulary to reach for before inventing:

- **Animated list/grid** — animating insertion/removal (`AnimatedList`).
- **Shared element transition** — the user picks an element, usually an image, and
  the UI animates it to a detail page; `Hero` implements this between routes.
- **Staggered animation** — "animations that are broken into smaller motions, where
  some of the motion is delayed. The smaller animations might be sequential, or
  might partially or completely overlap."

([Introduction to animations](https://docs.flutter.dev/ui/animations))

Mechanics for staggering: one `AnimationController` drives several `Animation`s that
each map a sub-range of `[0,1]`, composed with `CurvedAnimation`, `Curves`,
`CurveTween` and `TweenSequence`; you can also write your own `Curve` subclass by
overriding `transform` — the docs' example is literally a `ShakeCurve` returning
`sin(t * pi * 2)`, which is a useful precedent for a frost-shimmer curve
([Introduction to animations](https://docs.flutter.dev/ui/animations)).

Also documented and directly relevant: an `AnimationController` "generates a new
value whenever the hardware is ready for a new frame," tied to screen refresh, so
**typically 60 numbers per second** (the class doc says "typically, this rate is
around 60–120 values per second"); and the `vsync` argument exists specifically so
that **offscreen animations don't consume unnecessary resources**
([Introduction to animations](https://docs.flutter.dev/ui/animations),
[AnimationController source](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/animation/animation_controller.dart)).
Two consequences for the card: (1) one controller, many derived animations — not
one controller per effect; (2) always pass `vsync` from a
`SingleTickerProviderStateMixin`/`TickerProviderStateMixin` state so the frost stops
ticking when the card scrolls off or the route is covered.

Finally, note that the framework's own transition widgets are the reference
implementation of the "don't rebuild the subtree" pattern — the docs point at
`SlideTransition`'s source and the `TransitionBuilder` pattern as examples of
avoiding descendant rebuilds while animating
([best practices](https://docs.flutter.dev/perf/best-practices)).

**Also official and under-used:** the `animations` package on pub.dev provides
prebuilt M3 patterns — container transforms, shared axis transitions, fade-through
and fade transitions ([Introduction to animations](https://docs.flutter.dev/ui/animations)).

---

## 5. Motion accessibility

### 5.1 The signals and how to read them

| API | Meaning |
|---|---|
| `AccessibilityFeatures.disableAnimations` | "The platform is requesting that animations be disabled or simplified." ([dart:ui](https://api.flutter.dev/flutter/dart-ui/AccessibilityFeatures/disableAnimations.html)) |
| `MediaQueryData.disableAnimations` | "Whether the platform is requesting that animations be disabled or reduced as much as possible"; originates from `PlatformDispatcher.accessibilityFeatures` ([MediaQueryData.disableAnimations](https://api.flutter.dev/flutter/widgets/MediaQueryData/disableAnimations.html)) |
| `MediaQuery.disableAnimationsOf(context)` | Returns that flag, or `false` if there is no `MediaQuery` ancestor. **Prefer this over reading it off `MediaQuery.of(context)`**, because it rebuilds the context only when *this* aspect changes, not when any media-query attribute changes ([disableAnimationsOf](https://api.flutter.dev/flutter/widgets/MediaQuery/disableAnimationsOf.html)) |
| `MediaQueryData.accessibleNavigation` | Whether the user is driving the app with TalkBack or VoiceOver. **"When this setting is true, features such as timeouts should be disabled or have minimum durations increased."** ([accessibleNavigation](https://api.flutter.dev/flutter/widgets/MediaQueryData/accessibleNavigation.html)) |
| `SemanticsBinding.instance.disableAnimations` | the binding-level flag the framework itself consults ([animation_controller.dart](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/animation/animation_controller.dart)) |

`accessibleNavigation` is not a motion flag — it is a *screen-reader-present* flag.
Use it to lengthen or remove timeouts (auto-dismissing frost states, auto-flipping
cards), not to decide whether to animate.

### 5.2 What Flutter honours for you, quantitatively

`AnimationBehavior` configures how an `AnimationController` responds when
animations are disabled. Documented intent: when
`AccessibilityFeatures.disableAnimations` is true "the device is asking Flutter to
reduce or disable animations as much as possible. To honor this, we reduce the
duration and the corresponding number of frames for animations." The enum lets
specific controllers opt out
([animation_controller.dart](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/animation/animation_controller.dart)):

- **`AnimationBehavior.normal`** — reduces duration when `disableAnimations` is
  true. Default for `AnimationController.new`.
- **`AnimationBehavior.preserve`** — preserves behavior. Default for
  `AnimationController.unbounded`, and documented as the default *for repeating
  animations* to stop them flashing rapidly on screen when a widget ignores the
  flag. Also what physics-driven scrollables use, so a scroll doesn't snap to the
  end instantly.

The actual numbers, from the framework source:

- `_animateToInternal` (i.e. `forward`, `reverse`, `animateTo`, `animateBack`)
  applies `scale = _enableAnimations ? 1.0 : 0.05` — **animations run at 5% of
  their normal duration**, with the comment explaining that this is chosen to
  limit most animations to a single frame, while avoiding a true zero duration
  because an eternally repeating animation could otherwise spin in an endless loop.
- `fling` applies `scale = _enableAnimations ? 1.0 : 200.0` — the initial velocity
  is multiplied by **200**, described in the source as arbitrary, chosen because it
  worked for the drawer widget. The public doc repeats this: if
  `SemanticsBinding.disableAnimations` is set, the velocity is "somewhat
  arbitrarily multiplied by 200."

([animation_controller.dart](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/animation/animation_controller.dart))

### 5.3 The trap: `repeat()` does *not* honour reduce-motion

This is the finding that matters most for an ambient frost shimmer, and it is
visible in the source rather than in prose. `AnimationController.repeat()` builds a
`_RepeatingSimulation` and **never consults `animationBehavior._enableAnimations`** —
the 5% scale factor is applied in `_animateToInternal`, and the ×200 factor in
`fling`, but nothing in `repeat()`
([animation_controller.dart](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/animation/animation_controller.dart)).
That is *deliberate* and consistent with the `AnimationBehavior.preserve`
documentation — squashing a loop to 5% would make it strobe, which is worse — but
it means:

> **A `controller.repeat()`-driven frost shimmer keeps running at full speed with
> reduce-motion enabled unless you explicitly stop it. Flutter will not do this for
> you.**

You must gate it yourself, e.g. read `MediaQuery.disableAnimationsOf(context)` in
`didChangeDependencies`/`build` and `stop()` the controller, pinning the painter to
a static representative value (a fully-formed frost, not a blank card).

### 5.4 Why this is a requirement, not a nicety

Flutter's accessibility page names **WCAG 2** as the internationally recognized
standard, alongside **EN 301 549** (the European harmonized standard, and the
technical basis for the European Accessibility Act), **VPAT**, the **ADA**, and
**Section 508**, which requires federal agencies and contractors to meet WCAG for
all ICT ([Accessibility](https://docs.flutter.dev/ui/accessibility-and-internationalization/accessibility)).
For a banking app, treat these as binding. Two success criteria apply directly to a
looping frost effect:

- **WCAG 2.2.2 Pause, Stop, Hide.** For moving, blinking or scrolling information
  that **(1) starts automatically, (2) lasts more than five seconds, and (3) is
  presented in parallel with other content**, there must be a mechanism for the
  user to pause, stop or hide it — unless the movement is essential to the
  activity. Five seconds was chosen as long enough to draw attention but short
  enough to wait out. Continuous movement distracts users with cognitive
  disabilities and attention deficits; moving content is also a barrier for anyone
  who reads stationary text slowly or has trouble tracking moving objects, and can
  cause problems for screen readers. Best practice when a page has several such
  elements: **a single control that pauses all of them**, not one per element.
  Relevant failure conditions include `F16` (scrolling/moving content without a
  pause-and-restart mechanism) and `F112`/`F50` (blinking beyond five seconds with
  no way to stop it)
  ([Understanding SC 2.2.2](https://www.w3.org/WAI/WCAG22/Understanding/pause-stop-hide.html)).
- **WCAG 2.3.3 Animation from Interactions.** Motion animation triggered by
  interaction must be **disableable** unless essential. The stated reason is
  medical, not stylistic: some users experience distraction or nausea, and
  vestibular (inner-ear) disorder reactions include dizziness, nausea, migraine
  headaches and "potentially needing bed rest to recover." Any one of three
  solutions suffices: avoid unnecessary animation; provide a control to turn off
  non-essential animation from user interaction; or **take advantage of the reduce
  motion feature in the user agent or operating system**
  ([Understanding SC 2.3.3](https://www.w3.org/WAI/WCAG22/Understanding/animation-from-interactions.html)).

Note the third option is exactly `MediaQuery.disableAnimationsOf` — honouring the OS
flag is an officially sufficient technique.

One more distinction from SC 2.2.2 worth internalising for an "ice crystal
sparkle" effect: **blinking** causes distraction and may be allowed briefly, while
**flashing** — more than **3 per second**, large and bright enough — can trigger
seizures and "cannot be allowed even for a second," and providing an off switch is
*not* an acceptable mitigation because a seizure can occur faster than a user could
use it ([Understanding SC 2.2.2](https://www.w3.org/WAI/WCAG22/Understanding/pause-stop-hide.html)).
**Hard constraint: no element of the frost effect may change luminance more than
3× per second.**

Flutter's own release checklist items that intersect the card face: contrast ratio
of at least **4.5:1** between text/controls and background (disabled components
excepted), and images vetted for sufficient contrast; tappable targets at least
**48×48**; usable and legible in colorblind and grayscale modes; legible at very
large text and display scale factors; nothing should change the user's context
automatically ([Accessibility](https://docs.flutter.dev/ui/accessibility-and-internationalization/accessibility)).
A frost overlay that reduces contrast over card numbers is an accessibility
regression regardless of frame rate.

### 5.5 Semantics for a `CustomPainter`

Because a painted frost card is invisible to assistive tech by default, use
`CustomPainter.semanticsBuilder` to emit `CustomPainterSemantics` — the API doc's
own example annotates a sub-rect of a painted scene with the label "Sun" so a
screen-reader user can locate it by touch — and pair it with
`shouldRebuildSemantics` (return `false` when the semantic content is unchanged, as
the example does) ([CustomPainter](https://api.flutter.dev/flutter/rendering/CustomPainter-class.html)).
Do **not** emit a semantics node for the decorative frost itself; label the card
data.

---

## 6. `CustomPainter` specifics

### 6.1 The repaint trigger (the biggest single win, and it is documented)

`CustomPainter` subclasses must implement `paint` and `shouldRepaint`, and may
implement `hitTest`, `shouldRebuildSemantics` and `semanticsBuilder`. `paint` is
called whenever the object needs repainting; `shouldRepaint` is called when a **new
instance** of the delegate is supplied, to check whether it actually represents
different information ([CustomPainter](https://api.flutter.dev/flutter/rendering/CustomPainter-class.html)).

The documented "most efficient way to trigger a repaint" is one of exactly two
things ([CustomPainter](https://api.flutter.dev/flutter/rendering/CustomPainter-class.html)):

1. Extend `CustomPainter` and pass a `repaint` argument to its constructor — an
   object that notifies listeners when it is time to repaint.
2. Extend `Listenable` (e.g. via `ChangeNotifier`) **and** implement
   `CustomPainter`, so the painter itself provides notifications.

In either case `CustomPaint`/`RenderCustomPaint` listens to the `Listenable` and
repaints on every animation tick, **avoiding both the build and layout phases of
the pipeline**. `CustomPainter`'s constructor is `const`, and it already inherits
from `Listenable` with `addListener`/`removeListener` overridden.

**This is the recommendation for the frost painter.** An `AnimationController` *is*
a `Listenable`, so:

```dart
class FrostPainter extends CustomPainter {
  const FrostPainter({required this.t, required Listenable repaint})
      : super(repaint: repaint);          // ← ticks skip build + layout
  final Animation<double> t;             // read t.value inside paint()
  @override
  bool shouldRepaint(FrostPainter old) => false; // repaint: drives it
  @override
  bool shouldRebuildSemantics(FrostPainter old) => false;
}
```

The sample in the API docs makes the `shouldRepaint` rule concrete: because that
painter has **no fields** it always paints the same thing, so it returns `false`;
if it had fields set from the constructor it "would return `true` if any of them
differed from the same fields on the `oldDelegate`"
([CustomPainter](https://api.flutter.dev/flutter/rendering/CustomPainter-class.html)).

### 6.2 The shared-canvas hazard (matters for frost blend tricks)

Widgets — really render objects — are composited using a **minimum number of
`Canvas`es for performance reasons**, so a `CustomPainter`'s `Canvas` **may be the
same one used by other widgets**, including other `CustomPaint`s. Mostly
invisible, except with unusual `BlendMode`s: trying to use `BlendMode.dstOut` to
"punch a hole" through previously-drawn image content **may erase more than
intended**, because earlier widgets painted onto the same canvas. The documented fix
is `Canvas.saveLayer` + `Canvas.restore` — followed immediately by the warning that
"creating new layers is relatively expensive, however, and should be done sparingly
to avoid introducing jank"
([CustomPainter](https://api.flutter.dev/flutter/rendering/CustomPainter-class.html)).

So: if the frost uses `dstOut`/`srcIn`-style masking, you are paying a `saveLayer`
per masked group. Prefer building the mask geometrically (one path, one fill) over
punching holes.

### 6.3 Bounds, and the constraints on `paint`

- Painters are expected to paint within a rectangle from the origin covering the
  given `size`. **If they paint outside those bounds "there might be insufficient
  memory allocated to rasterize the painting commands and the resulting behavior is
  undefined."** To enforce bounds, wrap the `CustomPaint` in a `ClipRect`
  ([CustomPaint](https://api.flutter.dev/flutter/widgets/CustomPaint-class.html),
  [RenderCustomPaint](https://api.flutter.dev/flutter/rendering/RenderCustomPaint-class.html)).
  Frost needles that overshoot the card edge are not merely a visual bug.
- Painting order within one `CustomPaint`: `painter` first, then the `child`, then
  `foregroundPainter` ([CustomPaint](https://api.flutter.dev/flutter/widgets/CustomPaint-class.html)).
  Frost over card content ⇒ `foregroundPainter`; frost under ⇒ `painter`.
- **You cannot call `setState` or `markNeedsLayout` during the callback**, because
  layout for this frame has already happened
  ([CustomPaint](https://api.flutter.dev/flutter/widgets/CustomPaint-class.html)).
- With no child, the painter sizes itself to `size` (default `Size.zero`) subject
  to parent constraints ([CustomPaint](https://api.flutter.dev/flutter/widgets/CustomPaint-class.html)).

### 6.4 Painting many shapes cheaply: the documented batching primitives

`dart:ui`'s `Canvas` offers these bulk operations
([Canvas](https://api.flutter.dev/flutter/dart-ui/Canvas-class.html)):

| API | Signature highlights | Why it batches |
|---|---|---|
| `drawPoints` | `(PointMode, List<Offset>, Paint)` | one call for a sequence of points/lines |
| `drawRawPoints` | `(PointMode, Float32List, Paint)` | same, but takes a **typed `Float32List`** — no per-point `Offset` objects |
| `drawVertices` | `(Vertices, BlendMode, Paint)` | "Draws a set of `Vertices` onto the canvas as **one or more triangles**" |
| `drawRawAtlas` | `(Image atlas, Float32List rstTransforms, Float32List rects, Int32List? colors, BlendMode?, Rect? cullRect, Paint)` | "Draws **many parts of an image — the atlas —** onto the canvas" |
| `drawPath` | `(Path, Paint)` | one call for arbitrarily many sub-paths |
| `drawPicture` | `(Picture)` | replays pre-recorded commands; create via `PictureRecorder` |
| `drawShadow` | `(Path, Color, double elevation, bool transparentOccluder)` | the documented **efficient** shadow path, vs `MaskFilter.blur` ([MaskFilter.blur](https://api.flutter.dev/flutter/dart-ui/MaskFilter/MaskFilter.blur.html)) |

`PointMode` variants and `drawRawPoints`' `Float32List` are the closest thing the
API offers to "draw N needles in one call" without building geometry yourself;
`drawVertices` is the escape hatch if the needles are true triangles;
`drawRawAtlas` is the right tool if the needles are sprites from one texture.

### 6.5 Is "accumulate into a single `Path` and stroke once" the *recommended* approach?

**Honest answer: the official docs never say this.** I found no statement in
`docs.flutter.dev`, `api.flutter.dev`, or the Impeller engine docs recommending
accumulating shapes into one `Path` and stroking once. Do not attribute that rule
to Flutter.

What the docs *do* support, which converges on the same practice:

1. `Canvas.drawPath` takes one `Path` and one `Paint`, and a `Path` can hold many
   disjoint sub-paths — so one `drawPath` over an accumulated path is structurally
   one draw operation instead of N
   ([Canvas](https://api.flutter.dev/flutter/dart-ui/Canvas-class.html)).
2. Bulk primitives exist precisely so many primitives become one call (§6.4).
3. Pipeline blends "don't require additional draw calls," and shared `BackdropKey`s
   let the engine perform one filter operation instead of many — the engine's own
   design pattern is *collapse N operations into 1*
   ([blending.md](https://github.com/flutter/flutter/blob/master/docs/engine/impeller/docs/blending.md),
   [BackdropFilter](https://api.flutter.dev/flutter/widgets/BackdropFilter-class.html)).
4. Blur must be used sparingly, and one filter over a group is documented as
   cheaper than a filter per element (§2.3, §2.4).

**Important caveat, stated because the docs are silent and it is easy to get
wrong:** one path stroked once is one draw call **only if the `Paint` is
identical**. If needles differ in colour, width, or opacity you cannot merge them
into a single stroke without changing the result. The documented ways to keep it
cheap in that case: group needles into **a small number of paths bucketed by
`Paint`** (docs are silent on the number — measure it); or encode per-needle
variation as a **shader/gradient** on one `Paint` rather than as separate draws
([fragment shaders](https://docs.flutter.dev/ui/design/graphics/fragment-shaders)
shows `Paint()..shader = …` applying to a stroked path's fragments); or, if the
needle set is static in shape, **precalculate and cache** it (§2.2,
[best practices](https://docs.flutter.dev/perf/best-practices)).

Also: **one path stroked once with a `MaskFilter` is one blur, not 288.** That
alone addresses the documented regression, independent of draw-call count.

### 6.6 Avoiding per-frame allocation and reusing `Paint`

**Be precise about provenance here.** There is **no official Flutter doc that says
"reuse your `Paint` objects in `CustomPainter.paint`."** I looked and did not find
one. The supporting official statements are adjacent:

- "**Avoid repetitive and costly work** in `build()` methods since `build()` can be
  invoked frequently" — the same logic applies to a `paint()` called every tick,
  but note the docs say `build()` ([best practices](https://docs.flutter.dev/perf/best-practices)).
- The one explicit per-frame-object-reuse rule in the docs is about shaders: "**You
  can reuse a `FragmentShader` object across frames; this is more efficient than
  creating a new `FragmentShader` for each frame**"
  ([fragment shaders](https://docs.flutter.dev/ui/design/graphics/fragment-shaders)).
  That page also advises **precaching `FragmentProgram` objects before starting an
  animation** (framed as a Skia-backend concern), and its `SDFPainter` example
  caches an intermediate `Image` from `Picture.toImageSync` behind an `isDirty`
  flag and only regenerates it when dirty — an officially published caching pattern
  for exactly this situation.
- Impeller's frame-capture guide states as universally prudent that **texture
  allocations should not occur in a frame workload**
  ([read_frame_captures.md](https://github.com/flutter/flutter/blob/master/docs/engine/impeller/docs/read_frame_captures.md)).
- For string building specifically, the docs do give an allocation rule: prefer
  `StringBuffer` over `+` in loops, because `+` creates a new `String` per
  concatenation ([best practices](https://docs.flutter.dev/perf/best-practices)).
  Relevant if the painter formats any labels.

So: hoisting `Paint` objects to `final` fields, reusing `Path` objects via
`Path.reset()`, and preferring `Float32List` (`drawRawPoints`) over
`List<Offset>` are **well-aligned with documented principles but are not themselves
quoted rules**. Treat them as safe engineering, and verify with the DevTools memory
view / `FrameTiming` rather than citing docs at them.

The one thing you *can* cite hard: cache the expensive intermediate, keyed on a
dirty flag, and regenerate only when inputs change — that is the published
`toImageSync` pattern ([fragment shaders](https://docs.flutter.dev/ui/design/graphics/fragment-shaders)),
and the "precalculate, cache, and use that" advice for static composited shapes
([best practices](https://docs.flutter.dev/perf/best-practices)).

### 6.7 Raster-cache hints from the painter

`isComplex` and `willChange` on `CustomPaint`/`RenderCustomPaint` are "hints to the
compositor's raster cache" — `isComplex`: whether the painting is complex enough to
benefit from caching; `willChange`: whether the raster cache should be told the
painting is likely to change next frame. Both default to `false`
([CustomPaint](https://api.flutter.dev/flutter/widgets/CustomPaint-class.html),
[RenderCustomPaint](https://api.flutter.dev/flutter/rendering/RenderCustomPaint-class.html)).
The underlying layer properties spell out the semantics
([isComplexHint](https://api.flutter.dev/flutter/rendering/PictureLayer/isComplexHint.html),
[willChangeHint](https://api.flutter.dev/flutter/rendering/PictureLayer/willChangeHint.html)):

- `isComplexHint`: painting is complex and **would benefit from caching**. If unset,
  the compositor applies its own heuristics.
- `willChangeHint`: **tells the compositor not to cache this layer, because the
  cache will not be used in the future.** If unset, the compositor applies its own
  heuristics.

**For an animating frost painter, `willChange: true` is the correct setting** — it
stops the raster cache from spending GPU memory caching a layer that is invalidated
every tick. This matters because raster cache entries "are expensive to construct
and take up loads of GPU memory," so you should "cache images only where absolutely
necessary" ([profiling](https://docs.flutter.dev/perf/ui-performance)). Conversely,
for a **static** decorative pass, `isComplex: true` with `willChange: false` invites
caching. Verify the effect with `FrameTiming.pictureCacheCount` /
`pictureCacheMegabytes` and `layerCacheCount` / `layerCacheMegabytes`
([FrameTiming](https://api.flutter.dev/flutter/dart-ui/FrameTiming-class.html)).

---

## 7. Consolidated action list for this codebase

Ordered by documented leverage, highest first. Each maps to a section above.

1. **Never blur per-needle.** One blur over the group, or bake the softness into
   geometry/gradient. Blur is documented as expensive and to be used sparingly.
   (§2.3)
2. **Wrap the liquid-glass panes in a `BackdropGroup` and use
   `BackdropFilter.grouped`**, each in its own non-overlapping `ClipRect`. The
   engine collapses them into one filter operation. (§2.4)
3. **Audit the glass blend modes.** Anything in the advanced-blend list costs a
   fragment program, and on pre-A8/OpenGL-ES/Adreno-630-and-below it ends the
   render pass and allocates an intermediary texture. Prefer `srcOver`/`plus`/
   `modulate`. (§2.5)
4. **Drive the painter with `CustomPainter(repaint: controller)`**, not
   `setState`/`AnimatedBuilder`, so ticks skip build and layout entirely. (§6.1)
5. **Set `willChange: true`** on the animating `CustomPaint`; keep `isComplex:
   false` there. Reverse for any static decorative pass. (§6.7)
6. **Prove each `RepaintBoundary` with `debugDumpRenderTree`** and the
   symmetric/asymmetric paint counts — a boundary that paints in lockstep with its
   parent is documented as possibly making things *worse*. (§1.2)
7. **Gate the loop on reduce-motion yourself.** `repeat()` does not honour
   `disableAnimations`; use `MediaQuery.disableAnimationsOf` and `stop()` at a
   representative static value. (§5.3)
8. **Add a user-visible pause/stop for the ambient effect** if it auto-starts, runs
   >5 s, and sits alongside other content — WCAG 2.2.2. And keep every luminance
   change under 3/second. (§5.4)
9. **Use `Easing.emphasized` + `Durations.medium4`–`long2` for the flip**,
   `Easing.standard` + `short4`–`medium2` for press, `Easing.linear` for the loop
   seam. (§4.2, §4.3)
10. **Instrument before and after:** `addTimingsCallback` recording p95
    `rasterDuration` and `totalSpan` with the effect on vs off, in profile mode on
    the slowest supported device; DevTools layer toggles to confirm which of
    clip/opacity/physical-shape is actually costing you; a GPU frame capture to
    re-verify the draw-call count. (§3.5, §3.6, §3.9)
11. **Do not add `ShaderWarmUp`, `--cache-sksl`, or
    `--dump-skp-on-shader-compilation`.** That entire mechanism was abandoned and
    Impeller makes it unnecessary. Do not enable
    `--impeller-lazy-shader-mode`. (§2.6)
12. **Reuse `FragmentShader` instances across frames** and precache
    `FragmentProgram`s before the animation starts. (§2.6)

## 8. Where the official docs are silent

Recorded explicitly so nobody later mistakes an estimate for a citation:

- **No numeric draw-call budget** per frame, for Impeller or Skia. (§2.9)
- **No overdraw budget, and no overdraw debug flag** in Flutter's documented
  tooling. (§2.9)
- **No documented `--trace-impeller`** analogue to `--trace-skia`. (§3.9)
- **No official recommendation** to accumulate shapes into a single `Path` and
  stroke once. It is consistent with documented principles; it is not a quoted
  rule. (§6.5)
- **No official rule** to hoist/reuse `Paint` objects in `paint()`. The only
  explicit per-frame reuse rule is for `FragmentShader`. (§6.6)
- **No prescribed durations** for decorative/ambient texture effects; M3 duration
  tokens cover transitions. The applicable published rule is only that duration
  should scale with area/traversal. (§4.2)
- **No `Springs` token class in Flutter** mirroring M3's six spring slots; the
  primitives exist, the tokens do not. (§4.4)
- **`m3.material.io` pages were not machine-readable**, so M3 values here are
  sourced from Flutter's `Durations`/`Easing` classes and MDC-Android's `Motion.md`
  rather than paraphrased from pages I could not read. (§4.1)

---

*Content from external sources was rephrased for compliance with licensing
restrictions. Doc-site pages reflect Flutter 3.44.7; framework and engine source
references are to the `master` branch at time of writing.*
