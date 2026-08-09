# The Impeccable Rulebook — Combined & Actionable

Synthesised from the 14 reference files in `.kiro/skills/impeccable/reference/`.
Scoped for: Flutter mobile banking app, `CustomPainter` ice/frost on a card face, freeze/unfreeze control relocation, new icons + micro-animations.

> **Source caveat you must hold onto:** `optimize.md`, `animate.md` (tooling half), `craft-floor.md`, `colorize.md` and `layout.md` are written for the **web** runtime. `animate.md` says explicitly: for native targets *"follow the Motion section of ios.md or android.md, including the platform's Reduce Motion behavior. Do not apply the web tooling below."* Where a web rule has no Flutter equivalent it is marked `[web-only]`. Where it translates, the Flutter translation is marked `→ Flutter`. Thresholds are quoted unchanged.

---

## 1. ANIMATION RULES
*(animate.md, delight.md; craft-floor.md Motion row)*

### 1.1 What earns an animation

Motion is permitted **only** where it does one of these five jobs (`animate.md`, "Find the job"):

1. acknowledge an action;
2. make a state change or spatial relationship legible;
3. preserve continuity through navigation or layout change;
4. direct attention at a meaningful moment;
5. embody the selected visual world.

Governing sentences:
- *"Use motion to explain state, relationship, and hierarchy, or to create one authored moment the surface has earned. Decoration without purpose is animation debt."*
- *"Do not animate a static area merely because it exists."*
- Visitor mode for a banking app is **Operate**: *"motion serves feedback, state, and continuity. Keep routine transitions fast and do not make users wait through page-load choreography."*

### 1.2 Write the motion thesis before you code

Four required lines (`animate.md`, "Set the motion thesis"):

| Line | Content |
|---|---|
| **Focal moment** | the one sequence that deserves authorship, if any |
| **Continuity** | the state / layout / navigation changes needing explanation |
| **Feedback** | the controls and outcomes needing acknowledgment |
| **Budget** | which effects may be expensive, and how often they run |

Hard gate: *"The focal moment must come from this product and surface concept. A generic fade-and-rise, hover lift, parallax layer, or scroll reveal is not a thesis."*

`craft-floor.md` compresses this to: *"one authored moment, not scattered effects and not one identical entrance on every section."*

### 1.3 Durations — the table, verbatim

| Duration | Typical use |
|---|---|
| 100–150 ms | immediate feedback |
| 150–300 ms | routine state change |
| 300–500 ms | layout, overlay, or view transition |
| 500–800 ms | a deliberately authored focal entrance |

Only **one** thing in a screen may sit in the 500–800 ms band, and only if it is the declared focal moment.

### 1.4 Easing

- **Default:** *"Use natural deceleration such as `cubic-bezier(0.16, 1, 0.3, 1)` for confident arrivals."*
  → Flutter: `Cubic(0.16, 1.0, 0.3, 1.0)` — or `Curves.easeOutExpo` / `easeOutCubic` as the nearest stock curve. `craft-floor.md` names it *"Exponential ease-out from an already-visible default."*
- **Exit faster than entrance.** Non-negotiable phrasing in the source.
- *"do not use bounce or elastic curves by reflex"* — so no `Curves.elasticOut` / `bounceOut` unless the brief demands it.
- *"Long feedback feels like latency."* A slow acknowledgment reads as a bug, not as polish.

### 1.5 Material palette — choose the property by what it communicates

`animate.md` explicitly refuses the transform+opacity-only orthodoxy: *"Transform and opacity are reliable foundations, not the entire palette."*

| Communicative job | Legal material |
|---|---|
| Continuity / relationship | shared-element motion, FLIP-style transforms, view transitions, deliberate spatial movement → Flutter `Hero`, `AnimatedSwitcher`, container transform |
| Focus / depth | **bounded** blur, filter, backdrop, light, shadow changes |
| Reveal / composition | masks, clip paths, cropping, controlled occlusion → `ClipPath`, `ShaderMask` |
| Material / energy | colour, gradient position, texture, distortion, shader effects *"when the world and runtime support them"* → `FragmentShader` |
| State / feedback | *"the smallest change that makes cause and result unmistakable"* |

The word **bounded** in row 2 is the load-bearing word. See §3.

### 1.6 Choreography and stagger

- *"Sibling stagger is appropriate when a list appears as a list. Cap the total delay, and never reinterpret every scrolled section as a staggered list."*
- Two rules fall out: (a) stagger needs a genuine list; (b) total delay is capped — the last child must still land inside the band its own duration belongs to, so a 300 ms routine change staggered across 8 siblings cannot end at 2.4 s.
- `craft-floor.md`: not *"one identical entrance on every section."*

### 1.7 Making motion physical, not decorative

- *"One strong material idea, carried through the focal sequence and quiet supporting states, is usually enough."*
- *"Do not stack techniques for spectacle."*
- `delight.md`, for interaction character: *"an interaction or transition with a recognizable material behavior"* — the animation should behave like a substance with properties, not like a keyframe list.
- `delight.md`: *"Derive the treatment from product mechanism and visual world, not a stock catalog."*
- `craft-floor.md` licences the wider palette on condition of smoothness: *"Reach past transform and opacity: blur, backdrop-filter, clip-path, mask, and shadow belong to the palette when they stay smooth."* Smoothness is the entry fee.

### 1.8 Restraint, ambient and looping motion

- **Any nonessential loop must stop when offscreen or hidden.** Stated twice — `animate.md` ("Accessibility and control") and `delight.md` ("Nonessential loops stop when hidden"). This is the single most directly applicable rule to an ambient frost shimmer.
- *"Respect autoplay and sound preferences."*
- *"Make celebration intensity proportional to frequency and consequence."* (`delight.md`)
- *"keep the response satisfying after the hundredth use. Variation is useful only when it remains coherent and predictable enough to trust."*
- *"Repetition does not turn charm into friction."*

### 1.9 Banned / refused patterns

From `animate.md`:
- animating a static area because it exists;
- generic fade-and-rise, hover lift, parallax layer, scroll reveal *as the thesis*;
- stacking techniques for spectacle;
- reinterpreting every scrolled section as a staggered list;
- bounce/elastic by reflex;
- adding a dependency for an effect the existing stack expresses cleanly;
- casual animation of layout-driving properties (`width`, `height`, `top`, `left`, margins) → Flutter: animating `Container` box constraints, `Padding`, `Positioned` offsets, or anything forcing relayout each frame; prefer transform/`FractionalTranslation`/`Transform.scale`;
- unbounded blur / filter / shadow / canvas / shader work;
- `will-change` outside a known animation `[web-only]`;
- hiding content behind an animation's default state.

From `delight.md` — **"Delight must not"** (full list):
- delay, block, or obscure the primary task;
- override platform conventions or accessibility;
- add unrequested factual claims;
- play sound without consent or ignore mute settings;
- become mandatory, unskippable, or exhausting on repeat;
- add a dependency or asset cost disproportionate to the moment.

From `craft-floor.md` Refuse list, motion-adjacent: *"Glass and blur as decoration rather than as a specific effect."*

Banking-specific, from `delight.md`: *"Error and recovery: lead with the problem and recovery. Warmth may reduce stress; jokes must not trivialize loss, money, privacy, or blocked work."* A frozen card is blocked work. No jokes there.

### 1.10 Waiting states

- *"show truthful progress, useful context, or product-specific activity. Never fake work or delay completion to stage a flourish."*
- If freeze/unfreeze is a network call, the frost animation may **not** be padded to cover latency, and may not be used to imply progress it does not measure.

### 1.11 Animation verify list (`animate.md`)

- [ ] The focal motion is specific to the selected world and surface.
- [ ] Every supporting animation explains feedback, state, or relationship.
- [ ] Interruption and repeated use behave correctly.
- [ ] Desktop, mobile, and keyboard paths remain usable.
- [ ] Expensive effects stay smooth on the target device.
- [ ] *"Removing an animation would lose meaning or authored character, not merely decoration."*

### 1.12 Delight verify list (`delight.md`)

- [ ] *"The moment is specific enough that a neighboring product could not use it unchanged."*
- [ ] It improves comprehension, confidence, motivation, or emotional recovery.
- [ ] *"The interface remains fast and obvious without the flourish."*
- [ ] Repetition does not turn charm into friction.
- [ ] Muted, keyboard, touch, and localized paths work.
- [ ] It feels like the selected world, not a generic "delight" treatment.
- [ ] One-sentence delight thesis exists: what the user should feel and why that feeling belongs to *this* product.

---

## 2. POLISH CHECKLIST
*(polish.md, craft.md, craft-floor.md — concrete checkable items only)*

> `craft.md` contributes no checks. It is a deprecation notice: *"`craft` is a deprecated alias for an ordinary request to make new visual work. It adds no setup, interview, checkpoint, tool, or quality behavior."* Route natural requests through `new-work.md` instead, and *"Do not tell users they need to invoke `craft`."*

### 2.1 Classify before fixing (`polish.md` §1)

Tag each drift, then *"Fix the cause at the narrowest correct level"*:
- **missing token** — the system needs a reusable value;
- **one-off implementation** — a shared component/pattern should replace it;
- **conceptual mismatch** — flow/IA/hierarchy differs from comparable areas;
- **local defect** — implementation simply incomplete or inconsistent.

### 2.2 Triage order (`polish.md` §3) — fix in this sequence

1. broken or blocked tasks, data loss, misleading state, inaccessible paths;
2. missing loading, empty, error, success, disabled, and permission states;
3. flow, hierarchy, responsive, and design-system drift;
4. visual and motion inconsistencies;
5. code and asset cleanup.

### 2.3 Flow and hierarchy
- [ ] Neighbouring mental models, terminology, disclosure, routing, save behaviour, optimistic/pessimistic patterns all match.
- [ ] Primary task and current state obvious *without flattening every element to equal weight*.
- [ ] Arrival, transition, empty and recovery paths connect rather than behaving as isolated screens.

### 2.4 Layout and type
- [ ] Aligned to the project grid and spacing scale — **optical** as well as mathematical alignment.
- [ ] Related content grouped tightly; distinct groups separated generously.
- [ ] Same-role typography consistent.
- [ ] Measure, wrapping, localization expansion, zoom, and font loading all tested.
- [ ] Every supported viewport verified, not only the current screenshot.

### 2.5 Colour, imagery, icons
- [ ] Semantic tokens used; colour meanings stable across themes.
- [ ] Text, control and focus contrast verified **in every state**.
- [ ] Icon families, stroke/weight, sizing and optical alignment coherent.
- [ ] No image layout shift; correct aspect ratios, responsive sources, useful alt text.

### 2.6 Interaction and state
- [ ] Every control has default, hover, focus, active, disabled, loading, error and success behaviour.
- [ ] Visible keyboard focus, logical tab order, labels, platform-appropriate touch targets.
- [ ] Motion coherent, **interruptible**, performant.
- [ ] Long, missing, localized, offline, slow and permission-limited content validated.

### 2.7 Content and code
- [ ] Terminology, capitalization, punctuation and factual copy consistent. *"Ask before changing claims."*
- [ ] Debug output, dead code, unused imports, obsolete styles, polish-created duplication all removed.
- [ ] Custom implementations replaced by shared components where the system owns the pattern.
- [ ] Genuinely reusable values promoted to tokens — *"do not create a system abstraction for one local exception."*

### 2.8 Final walk (`polish.md` §5)
- [ ] Complete path walked with mouse, keyboard and touch.
- [ ] Mobile, intermediate and wide layouts.
- [ ] Loading, empty, error, success, disabled, long-content, missing-content states.
- [ ] Zoom, contrast, focus, semantics, screen-reader names.
- [ ] Console errors, layout shift, interaction latency, image loading, supported browsers.
- [ ] Agreement with DESIGN.md, neighbouring features, and the user's scope.
- [ ] Source diff cleaned: accidental churn, orphaned code, redundant values, temporary artifacts removed.

### 2.9 Craft floor — mechanical checks (`craft-floor.md` "Verify")

Run these **together in batched inspection rounds, not as separate screenshot trips; the checks share one render.**

| Axis | Hard check |
|---|---|
| **Contrast** | body and placeholder text **≥4.5:1**, large text **≥3:1**. On coloured surfaces tint secondary text from that hue or the foreground; **never gray**. |
| **Depth** | shadows carry **an offset and a soft blur**. *"A zero-offset colored halo is decoration."* |
| **Spacing** | tight groups, generous separation, **more space above a heading than below it**. *"Read the computed values."* |
| **Type** | body measure **65–75ch**; display **max 6rem**; tracking floor **-0.04em**; balanced headings; obvious scale and weight steps. Run real copy at every breakpoint. |
| **Motion** | one authored moment; exponential ease-out from an already-visible default; wider palette allowed *"when they stay smooth."* |
| **States** | hover, disabled, loading, error, empty — plus real content, working controls, responsive composition, keyboard focus. |
| **Copy** | the product's own language. *"Controls name their action; errors name the problem and the recovery."* |
| **Coverage** | every brief requirement present and **findable within seconds**. |

### 2.10 Craft floor — Refuse list

Defaults you may only reach for if the brief's own words earn them:

**Page scaffolds**
- Same-size cards of icon + heading + text as the page structure. *"Cards are the lazy container; nested cards are always wrong."*
- The hero-metric template: big number, small label, supporting stats, accent.
- **Kicker / eyebrow above a heading — an outright ban:** *"This one is a ban, not a default: no brief earns it back. The heading carries its own weight; delete the label and let the heading speak."*
- Section numbers (01 / 02 / 03) unless the sequence carries needed information.
- A modal for a task needing neither interruption nor protected focus.

**Surface habits**
- Gradient text. *"Emphasis comes from weight or size."*
- Glass and blur as decoration rather than as a specific effect.
- A coloured `border-left`/`border-right` above 1px on cards, list items, callouts, alerts.
- Hard offset shadows (`box-shadow: 4px 4px 0`) outside a genuinely neobrutalist world.
- Sparklines, progress rings, soft-shadowed rounded rectangles standing in for content.
- Monospace as a costume for "technical" rather than for code, data, or measurement.
- A system display face as the display voice of an own-world page. *"the closest installed font is a failure, not a fallback."*
- **Unicode glyphs or emoji standing in for an icon system.** *"Icons are drawn, from a real library or authored SVG, in one consistent stroke and weight."*
- Light or dark picked by category. *"Pick it from the use scene: who, where, under what ambient light."*

Closing instruction: *"The floor holds the mechanics; it never picks the direction… when torn between refined and committed, commit."* Also: load it *"after the direction is settled, and build without announcing the checklist."*

---

## 3. PERFORMANCE RULES
*(optimize.md — quantitative, and the section your ice/frost work lives or dies on)*

### 3.0 The governing loop

> *"Performance is a feature. Identify the actual bottleneck for THIS interface, fix it, then measure. Don't optimize what isn't slow."*
>
> **"CRITICAL: Measure before and after. Premature optimization wastes time. Optimize what actually matters."**

Four diagnostic questions before any change:
1. What's slow? (Initial load? Interactions? Animations?)
2. What's causing it? (Large images? Expensive JavaScript? Layout thrashing?)
3. How bad is it? (Perceivable? Annoying? Blocking?)
4. Who's affected? (All users? Mobile only? Slow connections?)

Five measurement axes: **Core Web Vitals · load time · bundle size · runtime performance (frame rate, memory, CPU) · network (request count, payload sizes, waterfall)**.

### 3.1 Hard numeric budgets

| Metric | Threshold | Source |
|---|---|---|
| **Frame budget** | **16 ms per frame (60 fps)** — *"Target 16ms per frame (60fps)"* | Animation Performance |
| **LCP** | **< 2.5 s** | Core Web Vitals |
| **INP** | **< 200 ms** (INP replaced FID in March 2024) | Core Web Vitals |
| **CLS** | **< 0.1** | Core Web Vitals |
| **Image quality** | **80–85 % quality is usually imperceptible** | Optimize Images |
| **Image sizing** | *"don't load 3000px image for 300px display"* | Optimize Images |
| **Refresh rates to hold** | *"dropped frames on 60/120 Hz"* is an audit finding | `audit.native.md` §2 |

→ Flutter: 16 ms is the 60 Hz budget; on a 120 Hz device the budget is **8.3 ms**, and `audit.native.md` explicitly audits 120 Hz. Budget **both** the UI thread and the raster thread — a `CustomPainter` overrun shows up on raster, which the 16 ms figure still governs.

### 3.2 Named techniques — rendering performance

- **Avoid layout thrashing.** Batch all reads, then all writes. The anti-pattern is alternating read/write in a loop, *"causes reflows"*.
  → Flutter analogue: do not read layout geometry (`RenderBox.size`, `globalToLocal`) inside a paint or per-frame callback and then mutate layout from it. Compute once, cache, paint.
- **CSS `contain`** for independent regions `[web-only]` → Flutter: `RepaintBoundary`.
- **Minimise DOM depth** — *"flatter is faster"* → Flutter: flatten the widget tree; do not wrap every needle in its own widget.
- **Reduce DOM size** (fewer elements) → Flutter: fewer render objects; one painter, many primitives.
- **`content-visibility: auto`** for long lists `[web-only]`.
- **Virtual scrolling** for very long lists (react-window, TanStack Virtual) → Flutter: `ListView.builder` / `SliverList`. `audit.native.md` names the native equivalent: *"long content without FlatList / LazyColumn / List recycling"* is a finding.

### 3.3 Named techniques — paint & composite (**the 576-draw-call rule**)

Quoted verbatim from "Reduce Paint & Composite":
- *"Use `transform` and `opacity` for reliable movement, but allow blur, filters, masks, clip paths, shadows, and color shifts when they create meaningful polish"*
- *"Avoid casual animation of layout-driving properties (`width`, `height`, `top`, `left`, margins)"*
- *"Use `will-change` sparingly for known expensive operations"*
- **"Bound expensive paint areas for blur/filter/shadow effects (smaller and isolated is faster)"**

That last line is the exact rule the documented failure violated. `animate.md` states the same constraint twice — *"Bound blur, filter, shadow, canvas, and shader work to isolated regions"* — and it is the reason 288 individually-blurred needles became 576 draw calls per frame.

**The correction it prescribes: one bounded expensive region, not N expensive primitives.**
→ Flutter translation:
- Paint all needles into **one** layer, then apply **one** blur to that layer — `saveLayer` + a single `ImageFilter.blur`, or `Paint()..imageFilter`, or a `BackdropFilter`/`ImageFiltered` wrapping the whole card face.
- Better still: bake the blur into the *source*. A `MaskFilter.blur` per needle is still per-needle cost; a pre-rasterised frost texture, a gradient/noise shader, or a single `FragmentShader` over the card rect is O(1) in draw calls regardless of needle count.
- `drawPoints` / `drawVertices` / `drawRawPoints` / a single `Path` accumulating all needles collapses N `drawLine` calls into one.
- Wrap the static card art in a `RepaintBoundary` so the animating frost layer does not force the card, text and logo to repaint each frame.
- Cache the needle geometry: build the `Path` once in the painter's constructor or a memoised field, and implement `shouldRepaint` to return `false` when only non-geometric fields changed.

### 3.4 Named techniques — animation performance

- **GPU acceleration:** `transform` + `opacity` are the fast path; `left` / `width` are *"CPU-bound (slow)"*.
- **`requestAnimationFrame` for JS animations** → Flutter: `AnimationController` / `Ticker`, never a `Timer.periodic` repaint loop.
- **Debounce/throttle scroll handlers.**
- **Use CSS animations when possible** → Flutter: implicit/explicit animation widgets over manual `setState` per frame.
- **"Avoid long-running JavaScript during animations"** → Flutter: keep the UI thread free during the frost transition; move any heavy computation off it (`compute`/isolate).
- **Intersection Observer** to detect viewport entry and only then lazy-load or animate → Flutter: `VisibilityDetector` / scroll-position gating. This is the mechanism that satisfies *"Any nonessential loop must stop when offscreen or hidden."*

### 3.5 Framework optimisation

Web/React specifics — `memo()`, `useMemo`/`useCallback`, virtualize lists, code split routes, avoid inline function creation in render, React DevTools Profiler.
Framework-agnostic, which **does** apply to Flutter: **minimise re-renders · debounce expensive operations · memoize computed values · lazy load routes and components.**
`audit.native.md` names the native failure mode: *"unnecessary re-renders (React Native) or recompositions (Compose); missing memoization/keys"* → Flutter: rebuilding the whole card subtree when only the animation value changed. Use `AnimatedBuilder`/`ValueListenableBuilder` scoped to the painted layer only.

### 3.6 Loading performance (mostly `[web-only]`, kept for completeness)

- **Images:** modern formats (WebP, AVIF); proper sizing; lazy load below-fold; responsive `srcset`/`picture`; compress to 80–85 %; CDN.
- **JS bundle:** code splitting (route- and component-based); tree shaking; remove unused dependencies; lazy load non-critical code; dynamic imports for large components.
- **CSS:** remove unused; critical inline, rest async; minimize; CSS containment.
- **Fonts:** `font-display: swap` or `optional`; subset (`unicode-range`); preload critical; system fonts where appropriate; **limit font weights loaded**.
- **Loading strategy:** critical resources first (async/defer the rest); preload critical assets; prefetch likely next pages; service worker; HTTP/2 or HTTP/3.

### 3.7 Network optimisation
- Reduce requests: combine small files, **SVG sprites for icons**, inline small critical assets, remove unused third-party scripts.
- APIs: pagination, GraphQL field selection, gzip/brotli, HTTP caching headers, CDN.
- Slow connections: adaptive loading via `navigator.connection`, optimistic UI updates, request prioritisation, progressive enhancement.

### 3.8 Core Web Vitals playbook
- **LCP < 2.5 s:** optimize hero images · inline critical CSS · preload key resources · CDN · SSR.
- **INP < 200 ms:** break up long tasks · defer non-critical JS · web workers for heavy computation · reduce JS execution time.
- **CLS < 0.1:** set dimensions on images/videos · don't inject content above existing content · `aspect-ratio` · reserve space for ads/embeds · **avoid animations that cause layout shifts**.

### 3.9 Monitoring

Tools: Chrome DevTools (Lighthouse, Performance panel) · WebPageTest · Core Web Vitals (Chrome UX Report) · bundle analyzers (webpack-bundle-analyzer) · Sentry / DataDog / New Relic.
Key metrics: LCP, INP, CLS · TTI · FCP · **TBT** · bundle size · request count.
→ Flutter equivalents for this project: `flutter run --profile` + DevTools **Performance** view and the **raster/UI** timeline, `--trace-skia`, `debugProfilePaintsEnabled`, `SchedulerBinding` frame timings, and the on-device performance overlay. Read the **raster thread** bar — that is where `saveLayer` and blur cost appears.

> **IMPORTANT: Measure on real devices with real network conditions. Desktop Chrome with fast connection isn't representative.**

### 3.10 The `NEVER` list (verbatim)

- Optimize without measuring (premature optimization)
- Sacrifice accessibility for performance
- Break functionality while optimizing
- Use `will-change` everywhere (creates new layers, uses memory)
- Lazy load above-fold content
- Optimize micro-optimizations while ignoring major issues (optimize the biggest bottleneck first)
- Forget about mobile performance (often slower devices, slower connections)

### 3.11 Verify improvements
- **Before/after metrics** — compare Lighthouse scores (→ frame timings).
- **Real user monitoring.**
- **Different devices** — *"Test on low-end Android, not just flagship iPhone."*
- **Slow connections** — throttle to 3G.
- **No regressions** — functionality still works.
- **User perception** — *"Does it feel faster?"*

### 3.12 Performance findings `audit.native.md` will score you on (dimension 2)

- heavy work on launch before first frame;
- unvirtualized lists;
- *"synchronous work in scroll or gesture paths, dropped frames on 60/120 Hz"*;
- wasted rendering / missing memoization;
- *"full-size images decoded for thumbnails, no caching"*;
- bloated bundle or binary, unused dependencies.

Scoring: **0** = janky everywhere · **1** = major problems (unvirtualized lists, slow launch) · **2** = partial · **3** = good, minor improvements possible · **4** = excellent (fast launch, smooth scroll, lean).

---

## 4. NATIVE / MOBILE RULES
*(ios.md, android.md, adapt.native.md, audit.native.md)*

### 4.0 The frame both platform files set

*"On native, the visitor mode narrows what expression may override."* HIG (iOS) and Material Design 3 (Android) *"govern structure, navigation, and interaction in every mode; brand expresses through the layer the platform leaves open (tint, type, motion, content)."*

For a Flutter app shipping to both, `android.md` closes the loophole: *"A Material-everywhere cross-platform app that also ships to iPhone still owes iOS its OS guarantees on that hardware: safe-area insets, Reduce Motion, edge-swipe back."*

### 4.1 The two slop tests

- **iOS:** *"Would a fluent iPhone user trust this app, or pause at off-spec controls? The tell is 'ported from a website': reinvented navigation bars, custom back gestures, web-shaped buttons, hover-dependent affordances. Default to the platform's components; depart only for a reason the user would thank you for."*
- **Android:** *"Would a fluent Android user trust this app, or trip on off-spec components? The most common tell is an iOS app wearing Android's skin: a bottom-only navigation copied from iPhone, a back arrow that ignores the system Back gesture, Cupertino-shaped switches and dialogs."*

### 4.2 Touch targets — hard numbers

| Platform | Minimum | Spacing |
|---|---|---|
| iOS | **44 × 44 pt** | *"breathing room between adjacent targets"* |
| Android | **48 × 48 dp** | **at least 8 dp between them** |

`audit.native.md` flags *"below 44 pt (iOS) / 48 dp (Android), or crammed without spacing"* as an accessibility finding. `layout.md` adds: *"Keep touch targets usable even when their visible marks are small."*
→ Directly binding on the relocated freeze/unfreeze control and on any new icon buttons.

### 4.3 Safe areas and insets
- **iOS:** *"Lay out inside the safe-area insets. No controls under the notch, Dynamic Island, home indicator, or rounded corners."*
- **Android:** *"Edge-to-edge with window insets. Apply the status bar, navigation bar, display cutout, and IME insets so content never hides behind system bars or the keyboard."*
- `adapt.native.md`: *"Respect safe areas and window insets in every new configuration (notch, hinge, status bar, keyboard)."*
- `audit.native.md` P-list: *"content under the notch, Dynamic Island, home indicator, status bar, or keyboard."*

### 4.4 System gestures — never break
- **iOS:** *"Edge-swipe back stays alive. The left-edge back gesture is muscle memory; never disable or overlay it."*
- **Android:** *"System Back always works. Honor the predictive Back gesture and Back button; never trap the user or hijack the gesture."*
- → If freeze/unfreeze becomes a swipe or drag on the card, it must not sit in the left-edge back corridor on iOS or the predictive-back corridor on Android.

### 4.5 Navigation structure
- **iOS:** tab bar for **2–5** top-level sections (*"sections, never actions"*); navigation stack for hierarchy; sheet for self-contained tasks. *"No custom global nav, no mixed metaphors."* Large titles on top-level screens collapsing to inline on scroll; deep detail screens stay inline.
- **Android:** navigation bar (bottom, **3–5** destinations) on compact width; rail or drawer on expanded. Top app bar for screen context; pair with a FAB when the screen has a single primary action. **One FAB, one primary action** — *"Never stack FABs or spend one on a secondary task."*

### 4.6 Typography
- **iOS:** Dynamic Type via system text styles (Large Title → Caption). **No hard-coded point sizes.** SF Pro / SF Compact carries body, labels, controls; a brand face may appear in display moments. **11 pt floor; Body is 17 pt.**
- **Android:** Material type scale roles (Display, Headline, Title, Body, Label × large/medium/small). *"never hand-pick sizes per screen."* Roboto is the system face. **sp units, never fixed px.**
- `audit.native.md`: *"fixed point sizes defeating Dynamic Type (iOS) or px instead of sp (Android); layouts that clip or overlap at large sizes."*

### 4.7 Colour and materials
- **iOS:** semantic system colours (label, secondaryLabel, systemBackground, separator, tint) — *"raw hex breaks there."* **Dark Mode is a first-class appearance.** **One tint colour** drives interactive elements; *"decoration is not its job."* **System materials** for blur/translucency behind bars and sheets — *"no hand-rolled glassmorphism."*
- **Android:** Material colour roles (primary, on-primary, surface, surface-variant, secondary-container, outline, error). Dynamic Color (Material You) on Android 12+ **with a static fallback**. **Dark theme is first-class** — *"never a quick invert."* **Tonal elevation** through standard surface tonal levels — *"no arbitrary drop shadows."*

### 4.8 Components, controls, icons
- **iOS platform controls:** switch, segmented control, stepper, system pickers, action sheets, alerts, context menus, swipe actions. *"Reinventing these for flavor is the most common native slop."* **SF Symbols** for iconography — baseline-aligned, Dynamic Type-aware, weight and scale variants. *"Don't mix in a web icon set."* Grouped/inset lists for settings-shaped content; *"no bespoke card stacks."*
- **Android Material components:** buttons (filled / tonal / outlined / text), FAB, switches, chips, snackbars, bottom sheets, Material dialogs, navigation bar/rail/drawer. *"Never port iOS controls or invent equivalents."* Snackbars for transient feedback (*"never a toast for that"*); dialogs only for decisions that must interrupt.
- `audit.native.md` calls mixed icon sets **"Icon drift"**: *"mixed icon sets instead of SF Symbols / Material Symbols."*
- → For the icons you are adding: pick **one** family, per platform if you are being strict, and match stroke/weight/optical size. Cross-check against `craft-floor.md`'s ban on emoji-as-icons and `polish.md`'s "icon families, stroke/weight, sizing, and optical alignment coherent."

### 4.9 Motion, and respecting platform settings
- **iOS:** *"System transitions. Push slides, sheets rise, dismiss reverses the entrance. Custom transitions that fight the navigation model disorient."* **"Honor Reduce Motion. Crossfade instead of parallax and large slides."**
- **Android:** Material motion patterns — **container transform, shared-axis, fade-through**, with standard easing and durations; *"honor the system Remove animations setting with a crossfade or instant cut."*
- `audit.native.md` accessibility finding: *"Reduce Motion ignored: parallax and large slides with no crossfade alternative."*
- → Flutter: read `MediaQuery.of(context).disableAnimations` (and/or `accessibleNavigation`). When true, the frost transition becomes a **crossfade or instant cut**, and the ambient shimmer loop **does not run at all**.

### 4.10 Adaptation (`adapt.native.md`)
- *"The trap is treating adaptation as scaling. The job is rethinking the experience for the new context."*
- **Phone → tablet:** *"Restructure, don't stretch. A scaled-up phone UI on a tablet is the failure mode."* Drive from size classes / window size classes. Navigation changes shape. Use the width: split view / master-detail, multi-column grids, popovers where phones used sheets. *"Multitasking is a size, not an edge case."*
- **Orientation & foldables:** landscape restructures; *"never clip or letterbox."* Lock orientation only when the task truly demands it. Foldables: react to posture and hinge via window size classes; test folded, unfolded, tabletop.
- **iOS ↔ Android translation table** (translate idioms, never transplant): tab bar ↔ navigation bar/rail/drawer · edge-swipe back ↔ predictive Back · switch/segmented/pickers ↔ Material switch/chips/pickers · action sheet ↔ bottom sheet/Material dialog · SF Symbols+SF Pro+Dynamic Type ↔ Material Symbols+Roboto+sp · semantic colours+materials ↔ Material colour roles+tonal elevation · push/sheet transitions ↔ container transform/shared-axis/fade-through.
- **Web → native:** *"Reconform, don't reflow."* Replace web nav with the platform model, HTML-shaped controls with platform controls, hover affordances with touch-first ones, px type with Dynamic Type / sp.
- **Implement & verify:** structure from size classes *"never from device-model checks"*; insets respected in every configuration; simulators for breadth, **real hardware for truth** — at least one phone and one tablet per platform, both orientations, split-screen where supported.

**`adapt.native.md` NEVER (verbatim):**
- Ship a stretched phone layout on a tablet
- Port one platform's controls or navigation onto the other
- Hide core functionality on smaller devices (if it matters, make it work)
- Lock orientation to dodge a layout bug
- Trust simulators alone (posture, gestures, and performance need hardware)

### 4.11 Native audit procedure (`audit.native.md`)

Code-level, from source (SwiftUI / UIKit / Compose / React Native / Flutter). *"no browser tooling or `detect.mjs` applies."* **Don't fix issues; document them.** Score 5 dimensions 0–4:

1. **Accessibility (VoiceOver / TalkBack)** — labels/traits/state announcements; reading & focus order; text scaling; touch targets; Reduce Motion; contrast in both appearances.
2. **Performance** — see §3.12.
3. **Appearance & Theming** — hard-coded hex; broken dark appearance; Dynamic Color fallback; off-platform materials.
4. **Platform Conformance (CRITICAL)** — broken system gestures; inset violations; off-platform navigation; web-shaped controls; icon drift; system drift.
5. **Adaptivity** — stretched phone layouts; orientation breakage; keyboard/IME handling; multitasking; foldables.

**Total /20. Rating bands:** 18–20 Excellent (minor polish) · 14–17 Good (address weak dimensions) · 10–13 Acceptable (significant work needed) · 6–9 Poor (major overhaul) · 0–5 Critical (fundamental issues).

Report order: **Platform Conformance Verdict first** — *"Pass/fail: does this read as a native app or a ported website? List specific violations. Be brutally honest."* Then Executive Summary, Detailed Findings by severity, Patterns & Systemic Issues, Positive Findings, Recommended Actions.

Per issue, document: **Issue name · Location (screen, file, line) · Category · Impact · Guideline (the HIG/Material rule violated) · Recommendation · Suggested command.**

**Severity:** **P0** Blocking (prevents task completion — fix immediately) · **P1** Major (significant difficulty or platform-guideline violation — fix before release) · **P2** Minor (annoyance, workaround exists — next pass) · **P3** Polish (no real user impact — if time permits).

**`audit.native.md` NEVER:** report issues without explaining impact · give generic recommendations · skip positive findings · forget to prioritize (*"everything can't be P0"*) · report false positives without verification.

---

## 5. FORM, COLOUR, LAYOUT
*(shape.md, colorize.md, layout.md — hard rules only)*

### 5.1 Shape — the brief process (`shape.md`)

`shape.md` is a **discovery** command, not a visual-form command. Its hard rules:

- **Phase 1 discovery:** *"Do not write code or choose visual direction yet."*
- Cadence: two or three related questions per round, **then wait**. One round is the default; a second only when answers expose a material gap. *"Do not dump a questionnaire, repeat settled facts, or turn obvious facts into menus. Assert the likely reading and invite correction."*
- *"A sparse prompt requires at least one answer round."*
- **"Never ask for CSS values or canned aesthetic lanes."** Visual-world and concept choices belong to `new-work.md`.
- **Phase 3 brief, seven parts:** job and audience · outcome and proof · selected direction · scope and boundaries · states and ranges · interaction and layout (*"intent, not CSS"*) · constraints and open decisions.
- Length: *"Use three to five bullets when the task is settled; use the full structure only for ambiguous, multi-screen, or standalone planning. Do not restate the conversation."*
- **"Present the brief for explicit confirmation or one correction round, then stop: shape never writes code or a direction contract."**
- With no human answer mechanism: *"mark assumptions plainly, return the brief, and stop."*

### 5.2 Colour (`colorize.md`)

**Contrast — WCAG AA minimums (the table, verbatim):**

| Content | WCAG AA minimum |
|---|---|
| body text | **4.5:1** |
| large text | **3:1** |
| controls, icons, focus indicators | **3:1** |

Hard rules:
- Verify **computed** foreground/background pairs. *"Do not rely on eyesight alone."* Check interactive states, overlays, text on images, disabled content, **and both themes**. Simulate common vision deficiencies.
- **Information conveyed by colour also needs text, shape, iconography, or position.**
- Build **roles, not a bag of swatches**: canvas and elevated surfaces · primary and secondary text · action, focus, selection · borders and separators · success/warning/error/information · data categories or scales.
- *"Let the strongest color own a deliberate region or role instead of scattering tiny accents."*
- *"Keep the primary action easy to find; do not spend its color on decoration."*
- *"On colored surfaces, derive secondary text from the foreground or surface hue rather than using washed-out generic gray."*
- *"In dark mode, design surface elevation and contrast explicitly; do not invert the light theme mechanically."*
- For data: *"use distinct lightness, chroma, shape, label, or pattern so color is not the only code."*
- Use the project's existing colour space; for a **new web** palette prefer OKLCH. When deriving OKLCH ramps, *"vary lightness and reduce chroma near white and black. Do not keep high chroma at extreme lightness merely to make the math uniform."*
- *"Prefer explicit colors over chains of translucent overlays when alpha would make contrast context-dependent."*
- *"Choose hue from product meaning and visual direction, never from a default category association."*
- *"Decoration without a relationship to hierarchy, state, content, or the visual world is not a color strategy."*
- Name before editing: **emotional temperature, dominant relationship, contrast range, colour dosage.**
- If a new identity is required, that is `new-work.md`, not colorize.

### 5.3 Layout (`layout.md`)

- **Two isolated assessments, in this order:** (1) layout assessment on rendered/source evidence; (2) mechanical scan `node .kiro/skills/impeccable/scripts/detect.mjs --json --scope layout [targets]`. *"Keep mechanical evidence out of the first assessment, then synthesize both passes before editing. A clean scan cannot prove hierarchy or rhythm."*
- **The squint test:** *"With detail blurred, can you still identify the primary element, the secondary element, and the major groups in order?"*
- Six diagnostic axes, each answered with evidence: **reading order · grouping · rhythm · structure · density · adaptation · extremes.**
  - Grouping: *"Are related items close and distinct groups separated, or are containers compensating for weak proximity?"*
  - Rhythm: *"or is one spacing value repeated until everything has equal weight?"*
  - Adaptation: *"Does DOM and focus order still agree with the visual order?"*
- **Spacing scale:** *"Use a documented spacing scale rather than one-off values. A **4-unit base** usually provides the useful middle steps that an 8-only scale misses."*
- **Group by meaning. Use proximity before adding containers or decoration.**
- Create rhythm through deliberate contrast between tight and generous intervals.
- *"Let hierarchy follow product priority, not framework defaults."*
- *"Make responsive behavior structural: reorder, collapse, reflow, or reveal based on what remains important."*
- Prefer container-aware components when the same component appears in different contexts.
- Use `gap` for sibling rhythm when it expresses the relationship more directly than child margins.
- **Keep touch targets usable even when their visible marks are small.**
- **Use depth only when it clarifies state or hierarchy.**
- *"Make optical corrections only after inspecting the rendered result."*
- *"Variation is not a goal by itself. Repetition should support recognition; break it only when content or priority changes."*
- Native override: *"follow ios.md or android.md for navigation, insets, adaptation, and touch targets."*
- **Spatial thesis** named before editing: primary reading/task path · what belongs together and what must separate · which element leads and which supports · intended density and spacing rhythm · how structure changes across containers, viewports, input modes, content extremes.
- Verify: squint test holds · path clear at every size · grouping correct · intentional rhythm · density matches use frequency · extremes don't break structure · keyboard/touch/AT order agrees with visual order · **final mechanical scan has no unexplained findings**. *"Answer each item with rendered or source evidence, then rerun the scan. Do not substitute a bare 'yes' for verification."*

---

## 6. HOW TO CRITIQUE
*(critique.md — the prescribed procedure)*

### 6.1 Purpose
*"Resolve one stable target, run two independent assessments, synthesize a design critique, persist a snapshot, and ask the user what to improve next. The chat response is the primary deliverable; the snapshot is an archive/backlog for future commands."*

### 6.2 Hard Invariants (verbatim)
- Assessment A (design review) and Assessment B (detector/browser evidence) are both required.
- A and B **MUST run as two isolated sub-agents** whenever a sub-agent/Task tool is exposed. *"Running them inline in this context is 'possible' but is NOT permitted; it is a degraded run."* Inline only when no sub-agent tool exists (or the user declined).
- If you degrade, the report's **first line MUST** be `⚠️ DEGRADED: single-context (<reason>)`. *"A silent degraded critique is a failed critique."*
- *"Assessment A must finish before detector findings enter the parent synthesis context."*
- *"A skipped detector is a failed critique run unless `detect.mjs` is missing or crashes after a real attempt."*
- Viewable targets require browser inspection when available.
- Any local server started for visualization must run in the background, have a recorded stop method, and be stopped before final reporting.
- *"Do not claim a user-visible overlay exists unless script injection succeeded and the detector ran in the page."*

### 6.3 Procedure, step by step

**Setup**
1. Resolve the target to a concrete file path or URL. *"Prefer a source path over a dev-server URL when both identify the same surface; ports drift, paths do not."*
2. `node .kiro/skills/impeccable/scripts/critique-storage.mjs slug "<resolved-path-or-url>"` — never hand-write a slug. Non-zero exit → skip persistence/trend, continue the critique.
3. Read `.impeccable/critique/ignore.md` if present. *"Drop matching findings silently; it is the only prior-run input critique consumes."*

**Orchestration**
4. Spawn A and B as two isolated, **parallel** sub-agents. They must not see each other's output. *"Do not show findings to the user until synthesis."* Each creates its own **new** browser tab — *"Never reuse an existing tab, even if it is already at the right URL."*
5. Declare the path taken in the report header. *"Skipping sub-agents without the banner is the most common failure of this command."*

**Assessment A — Design Review**
Read source, inspect live page. Think like a design director. Evaluate: **design specificity** (*"Is the composition, interaction, and visual language grounded in this product, or could an unrelated product use it unchanged?"* — judged **before** seeing detector output) · **holistic design** · **cognitive load** (8-item checklist; report failures and any decision point with **>4 visible options**) · **emotional journey** (peak-end rule, emotional valleys, reassurance at high-stakes moments) · **Nielsen's 10 heuristics scored 0–4**, with `n/a` allowed rather than a forced number.
Returns: design-specificity verdict · heuristic scores · cognitive load · emotional journey · 2–3 strengths · 3–5 priority issues · persona red flags · minor observations · provocative questions.

**Assessment B — Detector + Browser Evidence**
`node .kiro/skills/impeccable/scripts/detect.mjs --json [target]`. Pass markup files/dirs; *"do not pass CSS-only files."* URLs skip the CLI scan and use browser visualization. 500+ scannable files → narrow scope or ask. Exit 0 = clean, 2 = findings.
Overlay flow: fresh tab → prefer the harness's native screenshot path → preflight mutable injection (`document.title` + append a `<script>`; *"Read-only evaluate APIs do not count"*) → if mutation unavailable, skip server/presentation/injection and report fallback signal → else start `live-server.mjs --background`, present browser, label `[Human]`, scroll top, inject `http://localhost:PORT/detect.js`, wait 2–3 s, read `impeccable` console messages, stop the server. Multi-view targets: inject on 3–5 representative pages.
Returns: CLI findings JSON/counts · browser console findings · false positives · skipped/failed steps with concrete reasons.
*"After Assessment B returns usable CLI findings, reuse them. Do not rerun `detect.mjs` in the parent"* unless B failed, was truncated, or omitted count/rule names/file locations.

**Synthesis**
6. *"Do NOT simply concatenate. Weave the findings together, noting where the LLM review and detector agree, where the detector caught issues the LLM missed, and where detector findings are false positives."* Present the **full structured critique in chat**; *"do not replace it with a summary and a link."*

**Report shape, in order**
- Line 1: `Method: dual-agent (A: <agent-id> · B: <agent-id>)` or the degraded banner.
- **Design Health Score** — Nielsen table, 10 rows + total. *"The applicable maximum is 4 times the number of heuristics you actually scored… Never print `/40` over a partial set."* Heuristics 7 and 10 may be `n/a` on Persuade/Experience surfaces; write `n/a` with a one-line reason and renormalise. *"Be honest with scores. A 4 means genuinely excellent. Most real interfaces score 20-32 out of 40."*
- **Design Specificity Verdict** — *"Start here."* LLM assessment · deterministic scan (counts + file locations, plus false positives) · visual overlays.
- **Overall Impression** — gut reaction, single biggest opportunity.
- **What's Working** — 2–3 things, specific about why.
- **Priority Issues** — 3–5, ordered, each: `[P?] What` · Why it matters · Fix (concrete) · Suggested command.
- **Persona Red Flags** — auto-select 2–3 personas by interface type; add 1–2 project-specific personas if `.kiro/settings.json` has a `## Design Context`. *"Name the exact elements and interactions that fail each persona. Don't write generic persona descriptions; write what broke for them."*
- **Minor Observations.**
- **Questions to Consider** — provocative.

**Persist**
7. Write the body to a temp file (full report, stopping before "Ask the User"/"Recommended Actions"), then:
```bash
IMPECCABLE_CRITIQUE_META='{"target":"...","total_score":<n>,"max_score":<n>,"na_heuristics":"...","p0_count":<n>,"p1_count":<n>}' \
  node .kiro/skills/impeccable/scripts/critique-storage.mjs write "<resolved target>" <body-file>
```
8. Delete the temp file whether the write succeeded or not; on failure mention `temp-file cleanup failed: <reason>` without blocking.
9. `critique-storage.mjs trend "<resolved target>" 5`, then append one line: **Trend for `<slug>` (last 5 runs): … (out of 40)** plus the written path. Differing maxima → print each score with its own denominator and note it is not like-for-like. Missing `max_score` on an older entry = 40. First run → say so. *"This is fire-and-forget… Do not show the user the helper's JSON output."*

**Ask the User**
10. 2–4 questions maximum, each referencing **specific findings**: priority direction · design intent (if a tonal mismatch was found) · scope · constraints (optional). *"Never ask generic 'who is your audience?' questions."* Offer concrete options. Skip questions entirely if findings are straightforward (1–2 clear issues).

**Recommended Actions**
11. Prioritised command list reflecting the user's stated priorities, then impact. Only from the approved command set. Skip commands addressing zero issues. Honour limited scope and off-limits areas. **End with `/impeccable polish`** if any fixes were recommended. Then tell the user they can run these in any order and re-run critique to see the score improve.

### 6.4 Critique tone rules (verbatim)
*"Be direct. Vague feedback wastes everyone's time. · Be specific. 'The submit button,' not 'some elements.' · Say what's wrong AND why it matters to users. · Give concrete suggestions. Cut 'consider exploring…' entirely. · Prioritize ruthlessly. If everything is important, nothing is. · Don't soften criticism. Developers need honest feedback to ship great design."*

### 6.5 Cognitive load — the 8-item checklist
Single focus · Chunking (**≤4 items per group**) · Grouping · Visual hierarchy · One thing at a time · Minimal choices (**≤4 visible options at any decision point**) · Working memory · Progressive disclosure.
**Scoring:** 0–1 failures = low (good) · 2–3 = moderate (address soon) · **4+ = high (critical fix needed)**.

**The working memory rule:** *"Humans can hold ≤4 items in working memory at once."* **≤4** manageable · **5–7** pushing the boundary · **8+** overloaded, *"users will skip, misclick, or abandon."* Applications: 1 primary + 1–2 secondary actions, rest in a menu · **≤5 top-level nav items** · **≤4 sibling choices per doc-sidebar level**.

Eliminate **extraneous** load ruthlessly; structure **intrinsic** load; support **germane** load.
Eight named violations: Wall of Options · Memory Bridge · Hidden Navigation · Jargon Barrier · Visual Noise Floor · Inconsistent Pattern · Multi-Task Demand · Context Switch.

### 6.6 Score bands
**36–40** Excellent (ship it) · **28–35** Good · **20–27** Acceptable · **12–19** Poor (major overhaul) · **0–11** Critical (redesign).
With `n/a` heuristics, read the band off the percentage: **90 %+** Excellent · **70 %+** Good · **50 %+** Acceptable · **30 %+** Poor · below that Critical.

**Severity tip:** *"If you're unsure between two levels, ask: 'Would a user contact support about this?' If yes, it's at least P1."*

### 6.7 Personas — pick 2–3
**Alex** (impatient power user) · **Jordan** (confused first-timer) · **Sam** (accessibility-dependent) · **Riley** (deliberate stress tester) · **Casey** (distracted mobile user).
For a mobile banking card screen, the selection table points to **Casey · Riley · Jordan** (e-commerce/checkout row) and **Sam** for accessibility. Casey's tests are the operative ones here: *"Are primary actions in the thumb zone (bottom half of screen)?"* · state preserved on interruption · works on 3G · *"Are touch targets at least 44×44pt?"* Casey's red flags include *"Important actions positioned at the top of the screen (unreachable by thumb)"* and *"Tiny tap targets or targets too close together"* — both live in your freeze/unfreeze relocation.
*"Only generate project-specific personas when real Design Context data is available. Don't invent audience details."*

---

## 7. MANDATORY / BLOCKING ITEMS
*Everything stated as a hard requirement or failure condition, quoted verbatim, grouped by source.*

### animate.md
- "Decoration without purpose is animation debt."
- "Do not apply the web tooling below." *(native targets)*
- "Do not animate a static area merely because it exists."
- "The focal moment must come from this product and surface concept. A generic fade-and-rise, hover lift, parallax layer, or scroll reveal is not a thesis."
- "Do not stack techniques for spectacle."
- "Cap the total delay, and never reinterpret every scrolled section as a staggered list."
- "Exit faster than entrance."
- "do not use bounce or elastic curves by reflex. Long feedback feels like latency."
- "Do not add a dependency for an effect the existing stack can express cleanly."
- "Keep content visible in the default state so failed scripts do not hide the page."
- "Avoid casually animating layout-driving properties such as `width`, `height`, `top`, `left`, and margins"
- **"Bound blur, filter, shadow, canvas, and shader work to isolated regions."**
- "Apply `will-change` only during known animation."
- "Measure on target viewports and devices rather than assuming transform means fast."
- **"Any nonessential loop must stop when offscreen or hidden."**
- "Removing an animation would lose meaning or authored character, not merely decoration."

### delight.md
- "Delight must not: delay, block, or obscure the primary task; override platform conventions or accessibility; add unrequested factual claims; play sound without consent or ignore mute settings; become mandatory, unskippable, or exhausting on repeat; add a dependency or asset cost disproportionate to the moment."
- "Never fake work or delay completion to stage a flourish."
- "jokes must not trivialize loss, money, privacy, or blocked work."
- "Generic whimsy is worse than neutral clarity."
- "Nonessential loops stop when hidden."
- "Do not manufacture a celebration for an ordinary click."
- "The moment is specific enough that a neighboring product could not use it unchanged."

### polish.md
- "Polish is refinement, never concealed redesign."
- "If the concept itself is wrong, say so and recommend redesign or `bolder` instead of smuggling in a replacement."
- "A detector result is defect evidence, not proof of quality."
- "Do not perfect one corner while leaving the rest below the same quality bar."
- "Every control needs appropriate default, hover, focus, active, disabled, loading, error, and success behavior."
- "Do not add animation merely to make polish visible."
- "do not create a system abstraction for one local exception."
- "Context requests a manual scan only when no automatic detector is active; never add another detector pass."
- "A clean scan does not replace visual judgment."
- **"Ship only when the feature is functionally complete and consistently finished across the path."**

### craft.md
- "Do not tell users they need to invoke `craft`."

### craft-floor.md
- "body and placeholder text ≥4.5:1, large text ≥3:1."
- "never gray." *(secondary text on coloured surfaces)*
- "shadows carry an offset and a soft blur. A zero-offset colored halo is decoration."
- "body measure 65–75ch, display max 6rem, tracking floor -0.04em"
- "one authored moment, not scattered effects and not one identical entrance on every section."
- "blur, backdrop-filter, clip-path, mask, and shadow belong to the palette when they stay smooth."
- "Cards are the lazy container; nested cards are always wrong."
- "A kicker or eyebrow above a heading. **This one is a ban, not a default: no brief earns it back.**"
- "Gradient text. Emphasis comes from weight or size."
- "Unicode glyphs or emoji standing in for an icon system. Icons are drawn, from a real library or authored SVG, in one consistent stroke and weight."
- "the closest installed font is a failure, not a fallback."
- "Each of these is a check on the built result, not an intention."
- "when torn between refined and committed, commit."

### optimize.md
- **"CRITICAL: Measure before and after. Premature optimization wastes time. Optimize what actually matters."**
- **"Bound expensive paint areas for blur/filter/shadow effects (smaller and isolated is faster)"**
- "Target 16ms per frame (60fps)"
- "Largest Contentful Paint (LCP < 2.5s)" · "Interaction to Next Paint (INP < 200ms)" · "Cumulative Layout Shift (CLS < 0.1)"
- **"IMPORTANT: Measure on real devices with real network conditions. Desktop Chrome with fast connection isn't representative."**
- "NEVER: Optimize without measuring (premature optimization); Sacrifice accessibility for performance; Break functionality while optimizing; Use `will-change` everywhere (creates new layers, uses memory); Lazy load above-fold content; Optimize micro-optimizations while ignoring major issues (optimize the biggest bottleneck first); Forget about mobile performance (often slower devices, slower connections)"
- "Test on low-end Android, not just flagship iPhone"

### ios.md
- "Lay out inside the safe-area insets. No controls under the notch, Dynamic Island, home indicator, or rounded corners."
- "No custom global nav, no mixed metaphors."
- **"Edge-swipe back stays alive. The left-edge back gesture is muscle memory; never disable or overlay it."**
- **"44×44 pt minimum for every tappable control, with breathing room between adjacent targets."**
- "No hard-coded point sizes."
- "11 pt floor; Body is 17 pt."
- "raw hex breaks there." *(non-semantic colours)*
- "Dark Mode is a first-class appearance. Design and test both."
- "no hand-rolled glassmorphism."
- "Don't mix in a web icon set."
- **"Honor Reduce Motion. Crossfade instead of parallax and large slides."**

### android.md
- "A Material-everywhere cross-platform app that also ships to iPhone still owes iOS its OS guarantees on that hardware: safe-area insets, Reduce Motion, edge-swipe back."
- "Never ship a phone bottom-bar untouched on a tablet."
- **"System Back always works. Honor the predictive Back gesture and Back button; never trap the user or hijack the gesture."**
- "Apply the status bar, navigation bar, display cutout, and IME insets so content never hides behind system bars or the keyboard."
- **"48×48 dp minimum for every touch target, with at least 8 dp between them."**
- "never hand-pick sizes per screen."
- "sp units, never fixed px"
- "Dark theme is a first-class scheme… never a quick invert."
- "no arbitrary drop shadows."
- "Never port iOS controls or invent equivalents."
- "One FAB, one primary action. Never stack FABs or spend one on a secondary task."
- **"honor the system Remove animations setting with a crossfade or instant cut."**

### adapt.native.md
- "NEVER: Ship a stretched phone layout on a tablet; Port one platform's controls or navigation onto the other; Hide core functionality on smaller devices (if it matters, make it work); Lock orientation to dodge a layout bug; Trust simulators alone (posture, gestures, and performance need hardware)"
- "Restructure, don't stretch. A scaled-up phone UI on a tablet is the failure mode."
- "never clip or letterbox."
- "Drive structure from size classes / window size classes, never from device-model checks."
- "Translate idioms; never transplant them"
- "Reconform, don't reflow."

### audit.native.md
- "Don't fix issues; document them for other commands to address."
- "Platform Conformance (CRITICAL)"
- "Start here. Pass/fail: does this read as a native app or a ported website? List specific violations. Be brutally honest."
- "Tag every issue with P0-P3 severity"
- "IMPORTANT: Be thorough but actionable. Too many P3 issues creates noise."
- "NEVER: Report issues without explaining impact (why does this matter?); Provide generic recommendations (be specific and actionable); Skip positive findings (celebrate what works); Forget to prioritize (everything can't be P0); Report false positives without verification"

### shape.md
- "Do not write code or choose visual direction yet."
- "Never ask for CSS values or canned aesthetic lanes."
- "A sparse prompt requires at least one answer round."
- **"Present the brief for explicit confirmation or one correction round, then stop: shape never writes code or a direction contract."**

### colorize.md
- "body text 4.5:1 | large text 3:1 | controls, icons, focus indicators 3:1"
- "Do not rely on eyesight alone."
- "Information conveyed by color also needs text, shape, iconography, or position."
- "do not spend its color on decoration." *(the primary action's colour)*
- "In dark mode… do not invert the light theme mechanically."
- "Do not keep high chroma at extreme lightness merely to make the math uniform."
- "Decoration without a relationship to hierarchy, state, content, or the visual world is not a color strategy."
- "do not replace a visual world under the guise of colorizing it."

### layout.md
- "Keep mechanical evidence out of the first assessment"
- "A clean scan cannot prove hierarchy or rhythm."
- "Use a documented spacing scale rather than one-off values."
- "Keep touch targets usable even when their visible marks are small."
- "Use depth only when it clarifies state or hierarchy."
- "Make optical corrections only after inspecting the rendered result."
- **"Answer each item with rendered or source evidence, then rerun the scan. Do not substitute a bare 'yes' for verification."**
- "The final mechanical scan has no unexplained findings."

### critique.md
- "Assessment A (design review) and Assessment B (detector/browser evidence) are both required."
- **"Assessment A and B MUST run as two isolated sub-agents whenever a sub-agent/Task tool is exposed. Running them inline in this context is 'possible' but is NOT permitted; it is a degraded run."**
- **"If you degrade for any reason, the report's first line MUST be a banner: `⚠️ DEGRADED: single-context (<reason>)`. A silent degraded critique is a failed critique."**
- "Assessment A must finish before detector findings enter the parent synthesis context."
- **"A skipped detector is a failed critique run unless `detect.mjs` is missing or crashes after a real attempt."**
- "Viewable targets require browser inspection when available."
- "Any local server started only for critique visualization must run in the background, have a recorded stop method, and be stopped before final reporting unless the user asks to keep it."
- "Do not claim a user-visible overlay exists unless script injection succeeded and the detector ran in the page."
- "never hand-write a slug."
- "Never reuse an existing tab, even if it is already at the right URL."
- "Do NOT simply concatenate."
- "Never print `/40` over a partial set."
- "Skipping sub-agents without the banner is the most common failure of this command."
- "Every question must reference specific findings from the report. Never ask generic 'who is your audience?' questions."
- "Humans can hold ≤4 items in working memory at once"
- "Don't soften criticism."

---

## 8. APPLIED: your ice/frost card, freeze control, icons

A direct read-through of the rulebook against the four things you are doing.

### 8.1 The frost painter — the 576-draw-call lesson, generalised
The documented failure is a textbook violation of one rule stated in two files: **bound expensive paint work to isolated regions.** 288 needles × (blur + fill) = 576 draw calls means the blur was applied *per primitive* instead of *per region*. The rulebook's remedy, in priority order:

1. **One blurred layer, not N blurred needles.** `canvas.saveLayer(rect, Paint()..imageFilter = ImageFilter.blur(...))`, draw all needles inside, `restore()`. Draw-call count collapses to O(1) blurs.
2. **Better: bake it.** A pre-rasterised frost texture (`ui.Image` built once, `drawImageRect` each frame) or a single `FragmentShader` over the card rect removes per-frame needle cost entirely. This is *"smaller and isolated is faster"* taken to its conclusion.
3. **Collapse the geometry.** Accumulate every needle into one `Path` (or use `drawRawPoints` / `drawVertices`) so it is one draw call regardless of count.
4. **`RepaintBoundary`** around the animating frost so the card art, number, logo and text do not repaint at 60 Hz. This is the Flutter form of *"Use CSS `contain` property for independent regions."*
5. **`shouldRepaint` must be honest.** Return `false` unless a field that actually affects the painting changed. Cache the needle geometry across frames.
6. **Measure it, both threads.** `flutter run --profile`, DevTools Performance, watch the **raster** bar against **16 ms** (8.3 ms on a 120 Hz phone). *"Measure before and after"* is stated as CRITICAL. Test on a low-end Android, not a flagship iPhone.

### 8.2 The frost as motion — does it earn its place?
- The freeze/unfreeze **transition** clearly earns motion: it makes a state change legible, which is job #2 on the list. It is a legitimate candidate for the **focal moment** and may use the **300–500 ms** band (a view-transition-scale change) or up to **500–800 ms** if you declare it as *the* authored entrance for this screen.
- The **ambient shimmer loop**, if you add one, is nonessential by definition. It therefore **must** stop when the card is offscreen or hidden, and must not run under Reduce Motion / Remove animations. It also faces *"keep the response satisfying after the hundredth use"* and *"Repetition does not turn charm into friction."* A frost that breathes forever on a screen a user visits daily is the exact thing `delight.md` warns about.
- Frost is a strong **material** idea — `animate.md` explicitly licences masks, clip paths, distortion and shaders as the "material and energy" register. Do not then stack blur + shimmer + particles + scale + colour shift: *"Do not stack techniques for spectacle."* One material idea.
- Physical rather than decorative: frost should **grow** — crystals nucleating and propagating from an origin with a clip/mask reveal reads as a substance; an opacity fade of a finished frost image reads as a sticker. Use the `mask` / `clip-path` register with exponential ease-out, and consider a slight lag between crystal growth and the card's colour desaturation so the two layers feel causally linked rather than co-triggered.
- The reverse (unfreeze) must **exit faster than the entrance**, and *"dismiss reverses the entrance"* (iOS motion). Thaw is not a second authored sequence.
- Frost must not reduce contrast below the floor: card number and name over frost still need **≥4.5:1** (**≥3:1** for large text), verified in **both** appearances, in the frozen state as well as the normal one. This is where a "beautiful" frost most often fails the audit.
- Frozen state cannot be communicated by the frost alone: *"Information conveyed by color also needs text, shape, iconography, or position."* A visible "Frozen" label or icon is required, not optional.

### 8.3 The freeze/unfreeze control relocation
- **44 × 44 pt** (iOS) / **48 × 48 dp** with **8 dp** separation (Android). Non-negotiable, and audited.
- Casey the distracted mobile user asks: *"Are primary actions in the thumb zone (bottom half of screen)?"* Moving freeze **downward** is defensible; moving it up is a persona red flag.
- If the new placement uses a gesture, it must not collide with **left-edge back** (iOS) or **predictive Back** (Android).
- Freezing a card is consequential. `polish.md` triage rank 1 covers *"misleading state"*; `delight.md` says lead with the problem and recovery, and no jokes about blocked work or money. The control needs an unambiguous current state, a confirmation path proportionate to consequence, and a truthful loading state during the network call — *"Never fake work."*
- The control needs the full state matrix: default, focus, active, disabled, **loading**, error, success. `audit.native.md` will score the missing ones.
- Use the platform switch/button, not a bespoke toggle: *"Reinventing these for flavor is the most common native slop."* Transient confirmation on Android is a **snackbar**, never a toast; a dialog only if the decision must interrupt.

### 8.4 The new icons
- **One family, consistent stroke and weight, optically aligned.** `craft-floor.md`: *"Icons are drawn, from a real library or authored SVG, in one consistent stroke and weight."* No emoji or Unicode glyphs standing in.
- Platform-native families are the conformant choice: **SF Symbols** on iOS, **Material Symbols** on Android. Mixing families is scored as **icon drift** under Platform Conformance (the CRITICAL dimension).
- Icons need **≥3:1** contrast (they count as controls/icons/focus indicators in the colorize table).
- Jordan the first-timer's red flag: *"Icon-only navigation with no labels."* A snowflake alone will not read as "freeze" to everyone — label it.

### 8.5 The micro-animations
- Each one must justify itself under §1.1 or be deleted. *"Removing an animation would lose meaning or authored character, not merely decoration."*
- Micro-feedback belongs in **100–150 ms**; a routine state change in **150–300 ms**. Anything longer on a tap reads as latency.
- All of them interruptible — a user double-tapping freeze must not queue two sequences.
- None of them may animate layout-driving properties. Transform, opacity, clip, mask, colour.
- Collectively they must not violate *"one authored moment, not scattered effects."* If the frost is the focal moment, the micro-animations are quiet supporting states, not five more small performances.
- Every one of them off (or crossfaded/cut) under Reduce Motion / Remove animations.

### 8.6 Suggested order of work
1. `optimize` the painter first — measure, then bound the blur to one region, then measure again. A janky frost cannot be polished into a smooth one.
2. `animate` — write the four-line motion thesis, pick the durations off the table, implement the freeze transition as the single focal moment.
3. `adapt`/native pass — touch targets, insets, gesture corridors, Reduce Motion, icon family.
4. `polish` — the §2 checklist across the whole path, all states, both appearances.
5. `critique` or `audit` — dual-agent critique for design, native audit for the /20 conformance score.

Both `animate.md` and `delight.md` end the same way: *"hand off to `/impeccable polish` for the final pass."*
