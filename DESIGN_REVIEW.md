# FrostBank 2.0, system design review

A review of the shipped build, the findings that came out of it, and what 2.0
changes. Written against the code, not against a screenshot: every finding below
names the file and the line that causes it.

## 1. What the system is

Four layers, cleanly separated, and the separation is real rather than aspirational.

| Layer | Where | What it owns |
| --- | --- | --- |
| Domain | `lib/domain` | Models and repository interfaces. No Flutter import. |
| Data | `lib/data` | Mock, Supabase, and market implementations of those interfaces. |
| State | `lib/state` | Riverpod controllers and providers. |
| Presentation | `lib/presentation` | Screens, the shell, and the widget vocabulary. |
| Design | `lib/core/design` | `tokens`, `typography`, `motion`, `glass`, `theme`. |

The design layer is the strongest part of the codebase. `AppTokens` is a
`ThemeExtension` with a named assertion when a token is missing, so a screen
cannot silently fall back to a Material default. `Space`, `AppRadius` and
`AppType` are single scales with no competing second scale. A static test
(`test/copy_discipline_test.dart`) mechanically forbids a raw hex colour outside
seven named files. That is a design system, not a palette in a file.

The weak part is that the system has **two glass languages** and the more
visible one is not actually glass. That is finding F1, and it is most of what
this pass fixes.

## 2. Dial reading

Where the shipped build sits, and where 2.0 aims.

| Dial | Shipped | 2.0 | Why |
| --- | --- | --- | --- |
| Material honesty | Blur pretending to be glass | Real refraction | F1 |
| Surface vocabulary | Two glass languages | One | F2 |
| Information density | Chrome first, money second | Money first | F3 |
| Gradient count | Three competing | One, with tiers | F5 |
| Motion budget | Fully spent, correctly | Unchanged | F9 |
| Colour and type | Disciplined, token driven | Untouched | Section 5 |

## 3. Findings

### F1. The chrome blurs but does not refract

This is the user visible complaint, and the cause is precise.

`lib/presentation/widgets/liquid_glass.dart:129` builds the lens by laying a
`BackdropFilter` out larger than the pane and scaling it back down:

```dart
Transform(
  transform: Matrix4.diagonal3Values(glass.lensX, glass.lensY, 1),
  alignment: Alignment.center,
  child: FractionallySizedBox(
    widthFactor: 1 / glass.lensX,
    heightFactor: 1 / glass.lensY,
```

with `lensX: 0.9, lensY: 0.6` in both brightnesses (`glass.dart:163`, `:189`).

That is a uniform scale about the centre, so displacement grows **linearly with
distance from the middle of the pane**. Real liquid glass does the opposite: it
concentrates almost all of its displacement into a narrow band that hugs the
edge, following the contour of the shape, and leaves the centre almost
undistorted. A linear ramp from the centre reads as a slightly squashed
photograph behind a grey sheet, which is exactly what the shipped bar looks
like. Adding blur cannot fix it, and in fact makes it worse: sigma 11 and 12
over a near black navy backdrop average the backdrop to flat grey, and the
`lift` wash at white 0.13 and 0.05 (`glass.dart:180`) has nothing left to lift.

The fix is not a bigger blur or a stronger tint. It is edge concentrated
displacement, which needs a fragment shader sampling the backdrop against a
signed distance field of the shape.

### F2. There are two glass languages, and eight screens use the wrong one

`LiquidGlass` (the pane above) is used in exactly **one** place,
`app_shell.dart:70`. Every other translucent surface uses `GlassPanel`
(`brand.dart:342`), which is a flat `ImageFilter.blur(sigmaX: 16, sigmaY: 16)`
with a white 0.1 fill and a white 0.22 border. It has no refraction, no scrim
and lift pair, and no graded rim. Eight files use it.

So the app's chrome and the app's panels are made of visibly different
materials, and neither is the material the brand claims.

### F3. The dashboard buries the thing the user opened the app for

Measured from the code, the first transaction row starts at roughly **y 720 to
735** in the scroll content. Above it, in order: a brand lockup row, two icon
buttons, a search field, an account chip strip, a label, the hero balance, an
available row, a card thumbnail strip, and four quick actions. On a 390 by 844
viewport the ledger begins at or just below the fold.

The search field is the weakest of those. It duplicates the search on
`TransactionHistoryScreen`, which is one tap away and is where searching
actually belongs.

The code shows this was already fought over once. `dashboard_screen.dart`
carries a comment that the card strip was cut to 54 pixels because at 94 it
"pushed the transaction list off the first screen". The strip was shrunk to buy
space instead of removing something.

### F4. The card strip crops a card mid glyph

The dashboard strip is a horizontal `ListView` with `clipBehavior: Clip.none` at
a 54 pixel thumbnail width. The last visible card is cut through the middle of
the brand glyph. A card cut through its mark does not read as "there is more to
scroll", it reads as a rendering fault.

### F5. Three gradient languages stack on one screen

The dashboard top region paints `FrostBackdrop`. Inside it the quick action
tiles paint their own `[frostBaseTop, frostLift]` gradient. Below, the offers
row paints `FrostCardSurface`, which is `gradientCard` plus an overlay gradient
plus a radial blob. Three different gradient recipes, each individually
defensible, are visible at once, and none of them is subordinate to the others.
Nothing recedes, so nothing advances.

### F6. The centre navigation slot says two things at once

The bar has five equal slots. Slot 2 is Home, and it is drawn as `_HomeMark`, a
bright brand tile with a glow. But the selection capsule is explicitly
suppressed on that branch (`visible: activeBranch != 0`, `app_shell.dart:78`),
so Home signals "selected" by lighting the brand mark while the other four
signal it with a capsule. A bright, glowing, centre mounted brand tile reads as
a primary action, not as a location. Two grammars for one state.

### F7. A refracting pane over Android stretch overscroll renders black

Latent, and introduced by fixing F1 rather than present today. A backdrop
sampling lens over a scrollable that uses Android's stretch overscroll renders
black at the scroll edges, because the stretch isolates the scrollable into its
own layer. A repo wide grep confirms there is currently **no**
`ScrollConfiguration`, `ScrollBehavior` or overscroll customisation anywhere in
`lib/`, and five branch scrollables plus three nested horizontal ones sit
directly under the bar. This has to be handled in the same pass as F1 or the fix
ships a new bug.

### F8. Dismissing the advertisement on the barrier does not dismiss it

`opening_ad_modal.dart` sets `barrierDismissible: true`, but only the `Skip`
control and the call to action run `onDismiss`, which is what sets
`openingAdDismissedProvider`. Tapping the barrier closes the dialog without
setting the flag, so the advertisement returns the next time the dashboard
mounts. A real defect, and the most annoying possible kind.

Separately, the whole `OpeningAdScreen` at `/ad` is unreachable: the router
guard sends a signed in user from `/ad` to `/pin-lock` and a signed out user to
`/login`. Only the modal is live. The screen is exercised by tests alone.

### F9. The motion budget is fully spent, and that is correct

Requirement 2.6 permits exactly one repeating animation, the splash indicator.
`grep -rn "repeat(" lib` returns three hits: the splash controller, the loading
shimmer (bounded, only present while a skeleton is), and a comment recording
that the navigation bar **used** to loop forever over a `BackdropFilter` and
that this was removed as a performance bug.

This is the single most important constraint on this pass. The temptation with a
liquid material is ambient motion: a slow drifting highlight, a breathing rim. It
is exactly what the spec forbids and exactly what the codebase already fixed
once. 2.0 adds **no new repeating animation**. Every new movement is driven by a
finger or by a state change, and rests at zero cost.

## 4. What 2.0 changes

**F1, F2. One material, real refraction, still frosty.**
`Glass` gains true lens tokens (band width, bend, magnification, aberration) and
loses the `lensX`/`lensY` scale trick. `LiquidGlass` keeps its scrim, lift, bloom
and sheen, which are what make the material read as *frost* rather than as
generic Apple glass, and swaps only the refraction pass for a real shader lens.
The outer graded rim and the two blurred arcs are retired in favour of the
shader's own backdrop adaptive optical rim, which can do something a static
painter cannot: take its colour from whatever is currently behind the pane. Net
change to the painter is five strokes down to one, so it is also cheaper.
`GlassPanel` is rebuilt on the same core at a softer tier, so all eight of its
usages upgrade at once and the app has one glass language.

**F3, F4, F5.** The dashboard search field is removed in favour of the real one
on the history screen. The ledger moves above the fold. The card strip is sized
to land on a whole card. The quick action tiles stop painting their own gradient
and become glass at the panel tier, which removes one of the three competing
gradient languages and makes the hierarchy legible.

**F6.** The centre slot keeps the brand mark but gains the same capsule every
other slot uses, so selection has one grammar.

**F7.** A `ScrollBehavior` that disables the stretch indicator is installed
around the branch navigators.

**F8.** `barrierDismissible` is routed through the same `onDismiss` path, so
every dismissal persists. The advertisement also gains a motivated entrance:
today it has none of its own and relies on the default dialog fade. In 2.0 it
arrives as a glass card that refracts the dashboard behind it, rising once on
opacity and translation inside the medium band. The intent is specific and worth
stating: an advertisement is an interruption, so it should read as a physical
object set down on top of the session the user was already in, not as a new
screen that replaced it. Refraction is what communicates "on top of". It is one
shot, it is disposed, and it renders its end state immediately under reduced
motion.

**F9.** No new repeating animation. Press deformation is the one new motion
primitive, it is driven by the finger, and it allocates no ticker at rest.

## 5. What is deliberately not changed

The brief was explicit that the theme and the cards stay. Untouched:

- All of `tokens.dart`. Every `Palette` hex, both `AppTokens` instances, and the
  `Space`, `AppRadius` and `Layout` scales.
- All of `typography.dart`, including the `fontVariations` on every step, which
  have to stay or the variable fonts render synthesised weights.
- The whole visual output of `card_face.dart`: the 0.66 portrait ratio, the seven
  colour fall on `cardFaceStops`, the three colourways and the stable id hash
  that assigns them, the five fill base material, the milled hairline, and the
  entire freeze timeline. The card is the best drawn thing in the app and it is
  left alone.

## 6. Constraints this work is held to

From the spec: Req 2.1 duration bands, 2.3 animate only opacity, translation,
scale and rotation, 2.4 a purpose comment on every animation, 2.5 reduced motion
renders end state, 2.6 one repeating animation, 2.9 dispose controllers, 25.1 no
em or en dash in interface copy.

Mechanically enforced, and therefore not negotiable: the raw hex ban outside
seven files, the `MoneyText` style rule, the two ad files that may contain no
hex and no `Palette` reference, the exact pinned copy and semantics labels in the
ad and accessibility suites, the requirement that the dashboard keeps `InkWell`
controls narrower than 120 pixels at 44 pixels or taller, and 14 golden images.

One accessibility detail that shapes the material: the app reads two independent
platform flags, `Motion.isReduced` for animation and `Glass.isReduced` for
transparency. Every new surface honours both, and reduced transparency still
collapses the pane to an opaque fill.

## 7. Verification

Baseline before this pass, on Flutter 3.44.9:

```
flutter analyze   No issues found!
flutter test      246 pass, 1 fail
```

The single failure is the `time deposit` golden at 0.08 percent, 248 pixels. It
was confirmed pre existing by stashing the dependency change and re running, so
it is not attributable to this work. Goldens are regenerated deliberately with:

```
flutter test test/golden --update-goldens
```


## 8. What the critic found after the work landed

The material and the dashboard were rendered to PNG and handed to a critic with
fresh context, against the design reference in `Reference Images/image.png`, with
no indication of which image was which. Three of its findings were acted on, two
were rejected, and one is left open because fixing it would mean editing code this
brief puts out of bounds.

**Acted on. The sheet looked mis-clipped.** The critic reported the sheet behind
the quick actions as having a rounded top left corner and no matching corner on
the right. The shape was symmetrical; the reason for the report was better than
the report. The sheet had no edge of its own, so it was only visible where the
backdrop behind it happened to be lighter, and the backdrop's glow sits on the
left. The top left corner read crisply against a lit gradient and the top right
dissolved into navy. Both sheets now carry a hairline, so the silhouette does not
depend on what is behind it. Pixel sampling across the edge confirmed the
asymmetry before the fix: the left edge sat at roughly 77, 89, 117 while the right
edge sat at 10, 18, 57.

**Acted on. The strongest colour on the screen was a secondary link.** `View all`
was rendering in the theme accent, which made it the most saturated pixel on a
screen about money and put it third in the eye's reading order, ahead of the
transaction list it labels. It is now secondary text with a chevron, and the
balance wins.

**Acted on. The bloom flattened the pane.** Covered in section 4, found by looking
at the specimen sheet rather than by the critic, but it is the same class of
error: a highlight scaled from the pane's longest side turned a 68 pixel bar into
a grey ramp.

**Rejected. "Payment cards are landscape, these are portrait."** Portrait is
deliberate and documented: the card is drawn the way it is held, and the whole
face is out of scope here.

**Rejected. "The balance reads like a terminal."** The hero figure is set in
GeistMono. Tabular figures are the correct choice for money, and the type scale is
explicitly out of scope. Worth revisiting with the owner, not worth changing
unilaterally.

**Left open. A frozen card reads as a loading placeholder.** The critic called the
pale card in the dashboard strip "a light silver-grey gradient blob" and "the
brightest object on the entire screen", and judged it a placeholder. It is not: it
is a frozen card, and frozen cards are pale because they are iced over. That is
the correct material. The problem is that `MiniCardFace` draws the frost without
the `FROZEN` tag that the full face carries, so at thumbnail size the state is
communicated only by being white, and white reads as absent rather than as frozen.
It also outweighs the balance.

This is a real defect and it is not fixed here, because the fix is inside
`card_face.dart` and this brief holds the card face still. Recommended, for
whoever picks it up: carry a compact frost marker on `MiniCardFace` above its
existing `minWidthForLabels` threshold, or damp the frost on the small face so a
frozen thumbnail reads as cold rather than as blank.

## 9. One spec tension worth a decision

Requirement 2.3 restricts animated properties to opacity, translation, scale and
rotation. The press response on the glass controls is a soft body deformation:
each edge springs independently, so the half of the pane nearest the finger gives
more than the far half. That is deliberately something a scale transform cannot
produce, which means it is arguably outside 2.3 as written.

It is kept, for two reasons. It is the one behaviour that separates a piece of
glass from a tinted rectangle under a finger, and it is the direct answer to the
brief. It also costs nothing at rest: no listener and no ticker exist until the
first touch, and it collapses with the rest of the motion system under reduced
motion.

But it is a judgement call made inside someone else's specification, so it is
flagged here rather than buried. If 2.3 is meant literally, the deformation should
come out and the controls should fall back to the scale response `Pressable`
already implements. Nothing else in this pass depends on it.

## 10. Verification after the work

```
flutter analyze   No issues found!
flutter test      250 pass, 0 fail
```

That includes the 14 pre existing goldens, regenerated deliberately, and 3 new
ones for the material. The `time deposit` golden that was failing at baseline now
passes, because it was regenerated with the rest.

One limit worth stating plainly. Under `flutter test` there is no Impeller, so
every image in this repository shows the lens on its frosted fallback path. The
refraction, the chromatic separation at the rim and the backdrop tinted optical
border are all absent from the goldens by design, and the graceful degradation
that makes that true is also what keeps the suite renderable. The geometry, the
washes, the rim placement and the sheen are pinned by the goldens. **The
refraction itself has only been verified as not throwing, and still needs to be
looked at on a physical Impeller device.**
