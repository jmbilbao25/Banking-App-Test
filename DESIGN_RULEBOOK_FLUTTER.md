# Design Rulebook - `design-taste-frontend` filtered for a Flutter native banking app (redesign-PRESERVE)

Source: `.agents/skills/design-taste-frontend/SKILL.md` (lines 280-1206 + Section 4.5).
Hard rules are quoted verbatim in `>` blocks or with the skill's own bold markers. Everything else is the Flutter translation.

## 0. Framing rule you must acknowledge first

Section 13 (OUT OF SCOPE) explicitly names our platform:

> This skill is NOT for:
> * Dashboards / dense product UI / admin panels ...
> * **Native mobile (use Apple HIG / Material directly).**
> ...
> If the brief is one of the above, **say so explicitly**, point to the right tool, and only apply this skill's marketing-page / about-page / landing-page parts to the surfaces where they apply.

So: the skill's *taste discipline* (consistency locks, state completeness, motion motivation, anti-slop, redesign protocol, perf/a11y) carries over. Its *landing-page composition rules* (hero viewport fit, eyebrow counts, logo walls, marquees, spec sheets, scroll cues, GSAP skeletons) mostly do not. Both sets are separated below.

---

## 1. Section 11 - REDESIGN PROTOCOL (full, verbatim rules)

> This skill handles **greenfield builds AND redesigns**. Misclassifying the mode is the single biggest source of bad redesign output.

### 11.A Detect the Mode (first action)
> * **Greenfield** - no existing site, or full overhaul approved. Dial baseline from Section 1.
> * **Redesign - Preserve** - modernise without breaking the brand. Audit first, extract brand tokens, evolve gradually.
> * **Redesign - Overhaul** - new visual language on top of existing content. Treat as greenfield for visuals; preserve content and IA.
>
> If ambiguous, ask **once**: *"Should this redesign preserve the existing brand, or are we starting visually from scratch?"*

**Our mode: Redesign - Preserve.** Declare it explicitly in the deliverable. Do not ask again; it is already settled (theme + card visuals frozen).

### 11.B Audit Before Touching (mandatory, before any edit)
> Document the current state before proposing changes:
> * **Brand tokens** - primary / accent colors, type stack, logo treatment, radii.
> * **Information architecture** - page tree, primary nav, key conversion paths.
> * **Content blocks** - what exists, what's doing work, what's filler.
> * **Patterns to preserve** - signature interactions, recognisable hero, copy voice.
> * **Patterns to retire** - AI-slop tells, broken layouts, dead links, generic stock imagery, perf traps.
> * **Dial reading of the existing site** - infer current `DESIGN_VARIANCE` / `MOTION_INTENSITY` / `VISUAL_DENSITY`. That's your starting point, not the baseline.
> * **SEO baseline** - current ranking pages, meta titles, structured data, OG cards. **SEO migration is the #1 redesign risk.**

Flutter mapping of the audit artefacts:
| Skill item | Flutter artefact to document |
|---|---|
| Brand tokens | `ThemeData` / `ColorScheme`, `TextTheme`, font family, `CardTheme.shape` radii, gradient constants used by the account cards |
| Information architecture | route table / named routes, `BottomNavigationBar` tabs + order + labels, nav-stack depth per flow |
| Content blocks | each screen's widget sections, which ones earn their space |
| Patterns to preserve | card visuals, theme, existing gestures (swipe/pull-to-refresh), copy voice |
| Patterns to retire | perf traps (rebuild storms, unbounded lists), inconsistent radii/spacing, missing states |
| Dial reading | infer current VARIANCE / MOTION / DENSITY per screen from the existing code |
| SEO baseline | **N/A on native.** Replacement risk of equal weight: analytics event names + deep-link/route URIs (see 11.F) |

### 11.C Preservation Rules (verbatim)
> * **Do not change information architecture** unless asked. Keep page slugs, anchor IDs, primary nav labels stable for SEO and muscle memory.
> * **Extract brand colors before applying Section 4.2.** A brand that is already purple stays purple - apply the LILA RULE's override.
> * **Preserve copy voice** unless asked for a rewrite. Visual modernisation != content rewrite.
> * **Honor existing accessibility wins.** Do not regress focus states, alt text, keyboard nav, contrast.
> * **Respect existing analytics events.** Do not rename buttons, form fields, section IDs that downstream tracking depends on.

Native reading: routes/tab labels stay; `ColorScheme` seed and card gradients stay (the anti-AI-purple rule from 4.2 is overridden by "brand already is what it is"); no copy rewrites; do not regress `Semantics` labels, focus traversal, contrast; do not rename analytics events or widget keys used by tests (`test/` exists in this repo - treat widget keys as contract).

### 11.D Modernisation Levers (priority order, verbatim)
> Apply in order - stop when the brief is satisfied:
> 1. **Typography refresh** - biggest visual lift per unit of risk.
> 2. **Spacing & rhythm** - increase section padding, fix vertical rhythm.
> 3. **Color recalibration** - desaturate, unify neutrals, keep brand accent.
> 4. **Motion layer** - add `MOTION_INTENSITY`-appropriate micro-interactions to existing components.
> 5. **Hero & key-section recomposition** - restructure top-of-funnel using Section 10 vocabulary.
> 6. **Full block replacement** - only when the existing block is unsalvageable.

Preserve-mode consequence: levers 1-4 are our working set. Lever 3 is constrained to neutrals/surfaces only (brand accent + card gradients frozen). Levers 5-6 need explicit approval.

### 11.E Decision Tree (verbatim)
> * IA, content, and SEO sound -> **targeted evolution** (Levers 1-4). ~70% of value at ~40% of risk.
> * Visual debt is structural (broken IA, no design system, broken mobile) -> **full redesign** with strict content preservation.
> * Brand itself is changing -> **greenfield**.

### 11.F What Never Changes Silently (verbatim)
> Never modify without explicit user approval:
> * URL structure / route slugs.
> * Primary nav labels.
> * Form field names or order (breaks analytics + autofill).
> * Brand logo or wordmark.
> * Existing legal / consent / cookie copy.

Flutter: named routes / deep links; bottom-nav + app-bar titles; `TextFormField` order, keys, autofill hints (`AutofillHints.username` etc.) - reordering a login form breaks password managers exactly like it breaks web autofill; logo asset; T&C / consent / privacy strings.

---

## 2. Section 14 - PRE-FLIGHT CHECK (every item, split by applicability)

> Run this matrix before outputting code. This is the last filter.
> **THIS IS NOT OPTIONAL. Run every box. If any box fails, the output is not done.**
> ... If a single checkbox cannot be honestly ticked, the page is not done. Fix it before delivering.

### 2.A Applies to us - run this checklist verbatim (with native reading)

- [ ] **Brief inference** declared (Section 0.B one-liner)?
- [ ] **Dial values** explicit and reasoned from the brief, not silently using baseline?
- [ ] **Design system** chosen from Section 2 if applicable, or aesthetic labeled honestly? -> native: Material 3 via `ThemeData`, declared once.
- [ ] **Redesign mode** detected and audit performed (if applicable, Section 11)?
- [ ] **ZERO em-dashes (`—`) anywhere on the page.** Headlines, eyebrows, pills, body, quotes, attribution, captions, buttons, alt text. Zero. (Section 9.G - non-negotiable.) -> grep every Dart string + every asset label.
- [ ] **Page Theme Lock**: ONE theme (light, dark, or auto) for the whole page. No section flips to inverted mode mid-page -> one `ThemeMode`; no screen or sheet hardcoding the opposite mode.
- [ ] **Color Consistency Lock**: one accent color used identically across all sections?
- [ ] **Shape Consistency Lock**: one corner-radius system applied consistently? -> one radius scale in theme; no ad-hoc `BorderRadius.circular(n)` per widget.
- [ ] **Button Contrast Check**: every CTA text is readable against its background (no white-on-white, WCAG AA 4.5:1)?
- [ ] **CTA Button Wrap**: no CTA label wraps to 2+ lines at desktop? -> native: no button label wraps or ellipsises at 320dp width **or** at `textScaleFactor` 1.3.
- [ ] **Form Contrast Check**: form inputs, placeholders, focus rings, labels all pass WCAG AA against the section background?
- [ ] **Serif discipline**: if a serif is used, it is NOT Fraunces or Instrument_Serif (or it is, with explicit brand justification)?
- [ ] **Italic descender clearance**: every italic word with `y g j p q` has `leading-[1.1]` min + `pb-1` reserve? -> Flutter: italic text needs `height >= 1.1` and bottom padding so descenders are not clipped by tight `SizedBox`/`Chip` bounds.
- [ ] **Copy Self-Audit**: every visible string re-read, no grammatically-broken or AI-hallucinated phrases shipped?
- [ ] **Motion motivated**: every animation can be justified in one sentence (hierarchy / storytelling / feedback / state transition), no animation-for-show?
- [ ] **Content density** sane: no 20-row data dumps, no fake-precise specs without justification, <= 25-word sub-paragraphs by default?
- [ ] **Motion claimed = motion shown**: if `MOTION_INTENSITY > 4`, the app actually animates, not just claimed?
- [ ] **Reduced motion** wrapped for everything `MOTION_INTENSITY > 3`? -> `MediaQuery.disableAnimationsOf(context)` / `accessibleNavigation`.
- [ ] **Dark mode** tokens defined and tested in both modes?
- [ ] **Mobile collapse** explicit for high-variance layouts? -> native: verify 320dp / 360dp / 430dp widths + landscape + `textScaleFactor` 0.85-1.5.
- [ ] **Viewport stability**: `min-h-[100dvh]`, never `h-screen`? -> native equivalent: no hardcoded pixel heights that break with keyboard/safe-area; use `SafeArea` + `LayoutBuilder`, respect `viewInsets`.
- [ ] **`useEffect` animations** have strict cleanup functions? -> native: every `AnimationController` / `Ticker` / `StreamSubscription` / `ScrollController` `dispose()`d.
- [ ] **Empty / loading / error** states provided? (see Section 4 below - this is the highest-value box for a banking app)
- [ ] **Cards omitted** in favor of spacing where possible? -> constrained: existing account-card visuals are frozen; applies only to *new* containers.
- [ ] **Icons** from an allowed library only, no hand-rolled SVG paths? -> no hand-rolled `CustomPainter` icon glyphs.
- [ ] **Motion** isolated in client-leaf components, memoized? -> native: animation confined to the smallest leaf widget; wrap in `RepaintBoundary`; never rebuild the whole screen per frame.
- [ ] **No AI Tells** from Section 9 (Inter as default, AI-purple, three-equal cards, Jane Doe, Acme, "Quietly in use at")?
- [ ] **Core Web Vitals plausibly hit** -> native equivalents: cold-start / first meaningful frame, jank-free scroll (no frame > 16ms budget), no layout jump when async data lands.
- [ ] **One design system** per project (no Material + shadcn mixed)? -> no Material/Cupertino widget mixing inside one screen.

### 2.B Web/landing-page-only boxes - do NOT apply, but note why

Hero-viewport fit; hero top padding `pt-24`; hero stack discipline (max 4 text elements); **eyebrow count <= ceil(sectionCount/3)**; split-header ban; zigzag alternation cap; no duplicate CTA intent (weak native analogue: don't ship two differently-labelled buttons for the same action - worth keeping); logo wall placement + logo-only rule; bento background diversity + exact cell count; "long lists need a different UI component" (partially transfers - see 6.C); real-images / picsum sourcing; pills overlaid on images; photo-credit captions; version footers; micro-meta sentences; hero-bottom decoration strip; floating top-right sub-text; locale/time/weather strips; scroll cues; hero version labels; section-numbering eyebrows; premium-consumer palette check (moot under preserve); marquee max-one-per-page; GSAP sticky-stack / horizontal-pan skeletons; `window.addEventListener('scroll')` ban (has a real native analogue - see 3.D); Navigation on ONE line <= 80px.

---

## 3. Every MOTION and ANIMATION rule

### 3.A The MOTION_INTENSITY bands (Section 7, verbatim)
> * **1-3 (Static):** No automatic animations. CSS `:hover` and `:active` states only. `prefers-reduced-motion` is the default mode anyway.
> * **4-7 (Fluid CSS):** `transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1)`. `animation-delay` cascades for load-ins. Focus on `transform` and `opacity`.
> * **8-10 (Advanced Choreography):** Complex scroll-triggered reveals, parallax, scroll-driven animation. Use Motion hooks. **NEVER use `window.addEventListener('scroll')`** - it is a hard ban, not a "prefer-not."

Flutter translation of the numbers (these are the concrete values to use):
* **1-3:** no implicit/ambient animation. Only press/tap feedback and default route transitions.
* **4-7:** `Duration(milliseconds: 300)` + `Cubic(0.16, 1.0, 0.3, 1.0)` (this is the skill's canonical ease; `Curves.easeOutExpo` is the closest stock curve). Staggered load-in via per-index delay. Animate only `Transform` / `Opacity`.
* **8-10:** scroll-linked reveals via `AnimationController` driven by scroll position without `setState`, parallax, sequenced choreography.
* **Scroll-reveal canonical spec (5.C)** translated: `opacity 0 -> 1`, `y +24px -> 0`, `duration 0.6s`, `delay i * 0.06s`, ease `[0.16, 1, 0.3, 1]`, **fires once** (`viewport: { once: true, amount: 0.3 }` -> trigger at 30% visible, never re-fire).
* **Spring spec (Section 5)** translated: `stiffness: 100, damping: 20` -> `SpringDescription(mass: 1, stiffness: 100, damping: 20)`. Verbatim rule: **"Apply Spring Physics ... - no linear easing."**

### 3.B Mandatory motion rules (verbatim)
> * **MOTION MUST BE MOTIVATED (mandatory).** Before adding any animation, ask: "what does this animation communicate?" Valid answers: hierarchy (drawing attention to the right thing), storytelling (revealing content in sequence that matches a narrative), feedback (acknowledging a user action), state transition (showing something changed). Invalid answer: "it looked cool". GSAP everywhere because GSAP is available is amateur. Each ScrollTrigger, each marquee, each pinned section needs a reason. **If you cannot articulate the reason in one sentence, drop the animation.**

> * **"Motion claimed, motion shown."** If `MOTION_INTENSITY > 4`, the page must actually move: entry transitions on hero, scroll-reveal on key sections, hover physics on CTAs, at minimum. A static page that claims `MOTION_INTENSITY: 7` is broken. Conversely, if you cannot ship working motion in the available scope, drop the dial to 3 and ship a clean static page. **Never half-build motion that breaks** (cut-off ScrollTriggers, jumpy enters, missing cleanups).

> * **Perpetual Micro-Interactions** (Pulse, Typewriter, Float, Shimmer, Carousel): Use when `MOTION_INTENSITY > 5` AND the section actively benefits from motion (status indicators, live feeds, AI-feel). **Not every card needs an infinite loop.** If a section is informational, leave it still.

> * **Magnetic Micro-physics:** Use when `MOTION_INTENSITY > 5` AND the brief reads premium / playful / agency. Implement EXCLUSIVELY with Motion's `useMotionValue` / `useTransform` outside the React render cycle. **Never `useState`.**

> * **MARQUEE MAX-ONE-PER-PAGE (mandatory).** ... Two or more marquees on the same page reads as lazy filler.

Native reading:
* **Ambient/looping motion is opt-in only, and only above MOTION 5.** In a banking app the only defensible loops are: shimmer on skeleton loaders while data is in flight (stops when data lands), and a genuine live-state indicator. Balance cards, tiles, and icons do not float, pulse, or breathe.
* **Never `useState` for continuous gesture values** (line 138) maps directly to: never `setState` per frame / per pointer-move / per scroll tick. Drive `Animation`/`ValueNotifier` and rebuild only the animated leaf via `AnimatedBuilder` / `ValueListenableBuilder`.
* Marquee rule: at most one horizontally auto-scrolling strip in the whole app, and only if it carries real content.

### 3.C Press / hover / tactile feedback (4.5, verbatim)
> * **Tactile Feedback:** On `:active`, use `-translate-y-[1px]` or `scale-[0.98]` to simulate a physical push.

Native: every tappable surface gets a press response - `scale: 0.98` (or a 1px lift) over ~100-150ms, plus Material ink/`splashColor` or a Cupertino opacity dip. No dead taps. Hover is not a mobile state: do not port hover-only affordances; anything the web version communicated on hover must be visible or press-revealed on mobile.

### 3.D Section 5.D - Forbidden Animation Patterns (verbatim, with native analogues)
> * **`window.addEventListener("scroll", ...)`** is banned. It runs on every scroll frame, jank-prone, no batching. Use Motion's `useScroll()`, GSAP's `ScrollTrigger`, IntersectionObserver, or CSS `scroll-driven animations`.
> * **Custom scroll progress calculations using `window.scrollY`** in React state. Same reason. Re-renders on every frame.
> * **`requestAnimationFrame` loops that touch React state.** Use motion values instead.
> * **Layout Transitions:** Use Motion's `layout` and `layoutId` props for visible state changes (re-ordering lists, expanding modals, shared elements between routes). **Do not wrap static content in `layout` props "for safety" - it costs measurement work.**
> * **Staggered Orchestration:** Use `staggerChildren` (Motion) or CSS cascade for reveal moments where sequence matters.

Native equivalents (these DO apply):
* **Banned:** `scrollController.addListener(() => setState(...))`. Use `NotificationListener<ScrollNotification>` feeding a `ValueNotifier`, or pass the controller straight into an `AnimatedBuilder`.
* **Banned:** per-frame `Ticker`/`AnimationController` listeners that call `setState` on a parent widget.
* **Banned:** `AnimatedSize` / `Hero` / implicit-animation wrappers sprinkled on static content "for safety" - each one costs layout work every build.
* **Allowed and preferred:** `Hero` / shared-element for real route transitions and expanding sheets (the `layoutId` analogue); `VisibilityDetector`-style triggers for enter-once reveals (the IntersectionObserver analogue); index-based delay for stagger.

### 3.E Reduced motion (6.B, verbatim - mandatory)
> * **Any motion above `MOTION_INTENSITY > 3` MUST honor `prefers-reduced-motion`.** This is non-negotiable.
> * In Motion: wrap with `useReducedMotion()` and degrade to static.
> * In CSS: gate animations behind `@media (prefers-reduced-motion: no-preference)` ...
> * **Infinite loops, parallax, scroll-hijack, and magnetic physics MUST collapse to static / instant under reduced motion.**

Native: read `MediaQuery.of(context).disableAnimations` (`MediaQuery.disableAnimationsOf(context)`) and also consider `accessibleNavigation`. When true: duration -> `Duration.zero`, loops off, parallax off, reveals render in final state. One shared helper (`motionDuration(context, base)`) so no widget can forget.

---

## 4. Interactive states, empty, loading, micro-interactions (Section 4.5, verbatim)

> LLMs default to "static successful state only." Always implement full cycles:
> * **Loading:** Skeletal loaders matching the final layout's shape. Avoid generic circular spinners.
> * **Empty States:** Beautifully composed; indicate how to populate.
> * **Error States:** Clear, inline (forms), or contextual (toasts only for transient).
> * **Tactile Feedback:** On `:active`, use `-translate-y-[1px]` or `scale-[0.98]` to simulate a physical push.
> * **BUTTON CONTRAST CHECK (mandatory, a11y):** ... verify the button text is readable against the button background. White button + white text ... transparent button against the page background with no border -> all banned. Audit every CTA: contrast ratio WCAG AA min (4.5:1 for body, 3:1 for large text 18px+). Same rule applies to ghost buttons over photographic backgrounds (use a backdrop, scrim, or stroke).
> * **CTA BUTTON WRAP BAN (mandatory):** Button text MUST fit on one line at desktop. ... Fix by EITHER shortening the label (3 words max for primary CTAs, ideally 1-2) OR widening the button (do not artificially constrain `max-width` on CTAs).
> * **NO DUPLICATE CTA INTENT (mandatory):** Two CTAs with the same intent on one page is a Pre-Flight Fail. ... pick ONE label and use it everywhere.
> * **FORM CONTRAST CHECK (mandatory, a11y):** Form inputs, placeholder text, focus rings, helper text, and error text all pass WCAG AA contrast against the section background. Light placeholders on a near-white form, white form on white page section, form labels grayer than 4.5:1 contrast -> all banned. Audit every form before shipping.

Section 4.6 (forms) - fully applicable to native:
> * Label ABOVE input. Helper text optional but present in markup. Error text BELOW input. Standard `gap-2` for input blocks.
> * **No placeholder-as-label. Ever.**

Flutter checklist per async surface (balances, transactions, savings, transfers):
1. **Loading** = shimmer skeletons shaped like the real rows/cards. No bare `CircularProgressIndicator` as the primary loading UI. (Skeleton shimmer is the one sanctioned infinite loop.)
2. **Empty** = composed illustration/icon + one-line explanation + the action that populates it ("Add your first savings goal").
3. **Error** = inline on the field for validation; a contextual banner/`SnackBar` only for transient failures; every network error offers Retry.
4. **Success/settled** = the state we already build; not the only state.
5. **Pressed / disabled / focused** for every control. Disabled must still pass 3:1 against its surface, and its reason should be stated near it.
6. `labelText` above the field via `InputDecoration`, `helperText` reserved in layout (so error text does not shift the form - CLS analogue), `errorText` below. **Never `hintText` as the only label.**
7. Currency/amount fields: `AutofillHints`, correct keyboard, and `Semantics` label spelling out the amount.

---

## 5. Performance rules (Section 6, verbatim + native mapping)

### 6.A Hardware Acceleration
> * Animate ONLY `transform` and `opacity`. Never animate `top`, `left`, `width`, `height`.
> * Use `will-change: transform` sparingly - only on elements that will actually animate.

Flutter: animate via `Transform`/`SlideTransition`/`ScaleTransition`/`FadeTransition`/`AnimatedOpacity`. Do **not** animate `Padding`, `SizedBox` dimensions, `Container` width/height, or `Flex` factors - each triggers layout every frame. `will-change` analogue = `RepaintBoundary` around animated leaves, used sparingly (each one costs a layer).

### 6.D Core Web Vitals Targets -> native equivalents
> * **LCP** < 2.5s. Hero image must be `next/image priority` or preloaded.
> * **INP** < 200ms. Heavy work off main thread.
> * **CLS** < 0.1. Reserve space for images, fonts, embeds.
> * Run Lighthouse before declaring a page done.

Native: first meaningful frame fast (defer non-critical providers; `precacheImage` the above-the-fold artwork); **heavy work off the UI isolate** (`compute`/`Isolate.run` for parsing, crypto, big list transforms) so tap-to-response stays under 200ms; **reserve space** with `AspectRatio`/fixed-height skeletons so nothing jumps when data or fonts land (this is the CLS rule, and it is the reason skeletons must match final shape); run DevTools performance overlay + profile-mode timeline before declaring done (the Lighthouse analogue).

### 6.E DOM Cost
> * Apply grain / noise filters EXCLUSIVELY to fixed, `pointer-events-none` pseudo-elements ... **NEVER on scrolling containers - continuous GPU repaints destroy mobile FPS.**
> * Be aware of bundle size. Motion is not tiny. Three.js is large. Lazy-load anything that's not above-the-fold.

Native: texture/noise/gradient overlays go in a non-scrolling `Stack` layer wrapped in `IgnorePointer`, never inside the scrollable. **`BackdropFilter` / blur inside a scrolling list is the direct analogue of the banned scrolling grain filter** - it repaints every frame; keep blur on static chrome (app bar, bottom sheet scrim) only. Bundle-size analogue: watch app size and lazy-init heavy deps; use `ListView.builder` (never a `Column` of N children in a `SingleChildScrollView`) and `const` constructors.

### 6.F Z-Index Restraint
> NEVER spam arbitrary `z-50` or `z-10`. Use z-index strictly for systemic layer contexts (sticky navbars, modals, overlays, grain). Document the z-index scale in a project constants file.

Native: `Stack` order and `elevation` are the z-index. Define one elevation scale in theme (surface, raised card, sticky bar, sheet, dialog, overlay) and reference it; no ad-hoc `elevation: 8` on random widgets.

### Image/asset weight (from 6.D/6.E + 4.8)
Ship correctly sized raster assets; use `cacheWidth`/`ResizeImage` so a 2000px PNG is not decoded for a 120dp avatar; prefer vector/font icons over bitmaps; declare asset variants in `pubspec.yaml`.

### Layout thrash checklist (native)
No per-frame `setState` above the animated leaf; no unbounded `IntrinsicHeight`/`Table` inside scrollables; no `MediaQuery.of(context)` in hot build paths where a `LayoutBuilder` scoped rebuild suffices; every controller disposed.

---

## 6. Icon / asset / illustration policy (beyond 3.C and 4.8)

### 9.E, verbatim
> * **NO hand-rolled SVG icons.** Use Phosphor / HugeIcons / Radix / Tabler. Lucide on explicit request only.
> * **Hand-rolled decorative SVGs strongly discouraged** as default (see Section 4.8).
> * **NO div-based fake screenshots.** Never build a fake product UI out of `<div>` rectangles to simulate a screenshot. Use real images, generated images, or skip the preview.
> * **NO broken Unsplash links.** Use `https://picsum.photos/seed/{descriptive-string}/{w}/{h}`, or generated photo placeholders, or actual assets.
> * **shadcn/ui customization:** Allowed, but NEVER in default state. Customize radii, colors, shadows, typography to the project aesthetic.
> * **Production-Ready Cleanliness:** Code visually clean, memorable, meticulously refined.

### 4.8 tail, verbatim
> * **LOGO-ONLY rule (mandatory):** logo wall = logos and nothing else. Do NOT print industry / category labels below each logo ...
>
> **Hand-rolled illustrations:**
> * SVG icons from libraries: fine (see Section 3.C).
> * Hand-rolled decorative SVGs (custom illustrations, logos, marks): **strongly discouraged**, never as default. Acceptable only when:
>   - The brief explicitly calls for it ("draw me an SVG logo")
>   - It's a single, simple geometric mark (a square, a circle, a wordmark in display type)
>   - You're confident in the output quality
>
> **Div-based fake screenshots are banned.** A "hand-built product preview" rendered with `<div>` rectangles, fake task lists, fake dashboards, fake terminal windows is a Tell. If you need to show a product: [real screenshot | generated image | real component preview | skip it]
>
> **Hero needs a real visual.** Text + gradient blob is not a hero - it's a placeholder.

Native reading:
* **Applies:** use one icon family for the whole app (`phosphor_flutter`, `hugeicons`, `tabler_icons`, or Material Icons - Material is the platform-native choice per Section 13). **No mixing families.** No hand-drawn `CustomPainter` glyphs to fake an icon.
* **Applies:** no widget-built fake screenshots/mock dashboards as decoration. In a banking app, a "preview" must be either the real widget or a real asset.
* **Applies:** decorative custom-painted illustration is not the default. Use a real asset or nothing. An empty state gets one real illustration asset or one library icon at large size - not a hand-painted composition.
* **Applies:** "Text + gradient blob is not a hero - it's a placeholder" -> a screen header that is just a gradient rectangle with text is unfinished. (Constraint: existing card gradients are frozen and are *not* what this rule targets.)
* **N/A:** logo-wall labelling rule, picsum/Unsplash sourcing, shadcn customization.

---

## 7. Mechanically checkable anti-slop / AI-tell list

These are the Section 9 items you can literally grep or count in a Flutter codebase.

### 7.A Grep-able hard bans
| Check | Command / rule | Verbatim source |
|---|---|---|
| Em-dash / en-dash in any visible string | `grep -rn "—\|–" lib/ assets/` -> must be zero | "**Em-dash (`—`) is COMPLETELY banned.** ... If your output contains a single `—` or `–` anywhere visible to the user, the output fails the Pre-Flight Check and must be rewritten." |
| Pure black / pure white | `grep -rn "0xFF000000\|0xFFFFFFFF\|Colors.black\b\|Colors.white\b"` in theme/surfaces | "**No pure `#000000` and no pure `#ffffff`** - use off-black (zinc-950, near-black warm gray) and off-white. Pure values kill depth." / "**NO pure black (`#000000`).** Off-black, zinc-950, or charcoal." |
| Placeholder names | `grep -rni "john doe\|jane doe\|sarah chan\|jack su"` | "**NO generic names.** ... use creative, realistic, locale-appropriate names." |
| Placeholder brands | `grep -rni "acme\|nexus\|smartflow\|cloudly\|lorem ipsum"` | "**NO startup-slop brand names.**" |
| Filler verbs in copy | `grep -rni "elevate\|seamless\|unleash\|next-gen\|revolutioni"` | "**NO filler verbs.** 'Elevate', 'Seamless', 'Unleash', 'Next-Gen', 'Revolutionize' -> concrete verbs only." |
| Fake-perfect numbers | search demo data for `99.99%`, `50%`, `1234567`, `$1,000.00`, `1234 5678 9012 3456` | "**NO fake-perfect numbers.** ... Use organic, messy data (`47.2%`, `+1 (312) 847-1928`)." |
| Fake-precise invented specs | any `92%` / `4.1x` / `48k` style stat | "Are AI-invented spec aesthetics - banned. Don't fake engineering precision the brand doesn't claim." Mock data must be labelled mock. |
| Middle dot spam | `grep -rn "·" lib/` -> max 1 per string | "**The middle-dot (`·`) is rationed.** Maximum 1 per line in metadata strips." |
| Version/build strings in UI | `grep -rni "v0\.\|BETA\|ALPHA\|build 00\|last sync"` | "**NO version footers on marketing pages.**" / "**NO version labels in the hero.**" (settings screens legitimately show a build number - that is a real functional surface, keep it there only) |
| Section-number labels | `grep -rn "\"0[0-9] \|00 / \|001 ·"` | "**NO section-number eyebrows.** ... Eyebrows should name the topic in plain language, not enumerate." |
| Generic step labels | `grep -rni "step 1\|stage 1\|phase 01\|pass one"` | "**NO generic step labels.** ... Banned. The actual step content is the label." (exception: a real multi-step transfer flow with a progress indicator is functional, not decorative) |
| Scroll cues | `grep -rni "scroll to explore\|↓ scroll"` | "**Scroll cues are banned.**" |
| Locale/weather strips | `grep -rn "°C\|°F"` + city strings in chrome | "**Locale / city-name / time / weather strips are banned for 99% of briefs.**" |
| Straight quotes used as typographic quotes | search `\"` inside quote/testimonial copy | "Quote marks: use real typographic quotes ( \" \" ) or none at all. Not straight ASCII." |
| Hand-rolled icon paths | `grep -rn "CustomPaint\|Path()" lib/` -> justify each | "**NO hand-rolled SVG icons.**" |
| Per-frame setState | `grep -rn "addListener" lib/` -> none may call `setState` | 5.D `window.addEventListener("scroll")` ban + "NEVER use `useState` to track continuous values" |
| Missing dispose | every `AnimationController`/`ScrollController`/`StreamSubscription` has a matching `dispose()` | "**`useEffect` animations** have strict cleanup functions?" |
| Neon glow | `grep -rn "BoxShadow" lib/` -> no untinted saturated glows | "**NO neon / outer glows** by default. Use inner borders or subtle tinted shadows." |
| Custom cursors | N/A on native | "**NO custom mouse cursors.**" |

### 7.B Countable structural checks
* **Radius count:** number of distinct corner radii in the codebase must match the documented scale (1 value, or a documented 3-value rule). Source: "**SHAPE CONSISTENCY LOCK (mandatory):** Pick ONE corner-radius scale ... Mixed systems are allowed only when there is a documented rule ... and that rule is followed everywhere."
* **Accent count:** one accent colour, referenced from theme, used identically everywhere.
* **Theme flips:** zero screens/sheets that hardcode the inverse theme. "The page has ONE theme. Sections do not invert."
* **Three-equal-cards:** `grep` for `Row` of three identical `Expanded` feature cards. "**NO 3-column equal feature cards.** The generic 'three identical cards horizontally' feature row is banned." (Native reading: a 3-up row of identical quick-action tiles is *functional* navigation and is fine; three identical marketing/benefit cards are the Tell.)
* **Hairline spam:** `grep -rn "Divider\|border" lib/` - no list where every row has both a top and bottom rule. "**NO `border-t` + `border-b` on every row** of a long list / spec table. Pick one ... and use it sparsely."
* **Decorative dots:** "**ZERO decorative status dots by default.** ... Only acceptable when conveying real semantic state ... and limited to one per page section." (A transaction-status dot is real semantic state; a dot before every nav label is not.)
* **Card discipline:** "Use cards ONLY when elevation communicates real hierarchy. Otherwise group with `border-t`, `divide-y`, or negative space." Applies to new containers only.
* **Copy register:** "**One copy register per page.**" Don't mix mono-technical, editorial, and marketing voices in one screen.
* **Progress bars as decoration:** "**NO scoring/progress bars with filled background tracks** as comparison visuals." (A savings-goal progress bar is real data; a decorative "strength" bar is not.)
* **Typography:** "**AVOID Inter as default.**" / "**NO oversized H1s** that just scream. Control hierarchy with weight + color, not raw scale." / "**Serif constraints:** Serif for editorial / luxury / publication. Not for dashboards." A banking app is dashboard-adjacent: no serif for balances or data.
* **Copy Self-Audit (mandatory before ship), verbatim:** re-read every visible string and flag anything "Grammatically broken", with "unclear referents", that "Sounds like AI hallucination", or that "Reads like an LLM trying to sound thoughtful ... **If unsure whether a string makes sense, replace it with a plain functional sentence. AI-generated cute copy is worse than boring copy.**"

### 7.C Density guidance that transfers (4.9)
* "**No data-dump sections.**" -> Top 3-5 highlights + "View all" beats a 20-row wall on a home screen.
* "**Long lists need a different UI component, not a longer list.**" -> above ~5 items reach for grouping, tabs, horizontal scroll-snap pills, or a card layout; "A spec sheet with 10 rows + a hairline under every row is the WORST default." Group rows into 2-3 chunks with sparse dividers.
* "short headline (<= 8 words) + short sub-paragraph (<= 25 words) + one visual asset OR one CTA" -> the same discipline for screen headers, empty states, and modal copy.

---

## 8. Contradiction guard (preserve mode wins)

Where the skill's default fights the frozen brand, preserve mode wins - per 11.C ("Extract brand colors before applying Section 4.2 ... apply the LILA RULE's override") and 11.F. Specifically **do not** touch: card gradients/visuals, brand accent, logo, radii on existing card components, route names, tab labels, form field order/keys, legal copy, analytics event names. Apply the rules above to *new and unstyled* surfaces, states, motion, spacing, and copy.
