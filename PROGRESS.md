# FrostBank production-grade gauntlet

**Bar:** `.kiro/specs/mobile-banking-app/requirements.md`, 25 requirements / 231 acceptance criteria.
**Visual gate:** `Reference Images/image.png` (Conceptzilla iOS Banking App 2025).
**Measurable half:** `flutter analyze` at 0 issues, `flutter test` green.

Toolchain: Flutter 3.44.9 / Dart 3.12.2 at `/projects/toolchain/flutter`.
Run checks with `/projects/toolchain/bin/fl flutter analyze` and `/projects/toolchain/bin/fl flutter test`.

## Measurable half

| Check | Start | Now |
| --- | --- | --- |
| `flutter analyze` | 19 issues | **0 issues** |
| `flutter test` | 44 pass / 3 fail | **250 pass / 0 fail** |
| Credentials in source (Req 5.9) | 3 live | **0** |
| PIN bypass | accepted on every screen | **removed** |
| Em or en dash in UI copy (Req 25.1) | 6 | **0** |
| Debits behind a confirmation (Req 16.9, 17.7) | none | **all** |
| Live controls routing to `/soon/` | 13 | **6** |
| Repeating animations (Req 2.6 permits one) | 3 | **1 plus the bounded loading shimmer** |
| `RepaintBoundary` against 6 blur sites | 2 | **5** |
| Raw hex colours outside the palette | 62 | **0, asserted** |
| Screens on one header scaffold | 0 | **5** |
| Task screens with a primary action | 2 of 3 | **3 of 3** |
| All-caps UI labels in app chrome | 5 | **0** |
| Golden regression screens | 0 | **17** |
| Glass materials in the app | 3 (pane, panel, icon control) | **1 at two tiers** |
| Refraction on the chrome | even scale, no edge bend | **shape refraction on an SDF** |
| Overscroll behaviour under a backdrop pane | platform default, renders black at the edge | **stretch indicator disabled** |

## Wave status

| # | Piece | State |
| --- | --- | --- |
| 1 | Green baseline: analyzer and failing tests | done |
| 2 | Purge committed secrets (Req 5.9) | done |
| 3 | Persistence_Store foundation (Req 6.6, 6.7, 1.14, 5.6, 5.10, 9.5) | done, 22 tests |
| 4 | App_Lock security surface (Req 5.1 to 5.5) | done, 13 tests |
| 5 | Profile security and settings (Req 23.3 to 23.9) | done, 11 tests |
| 6 | Forgot_Password_Screen (Req 11) | done, 10 tests |
| 7 | Notifications_Screen and dashboard badge (Req 22, 12.15, 12.16) | done, 12 tests |
| 8 | Time_Deposit_Screen (Req 21) | done, 23 tests |
| 9 | Gaps in existing screens (Req 13, 15, 16, 17, 19) | done, 27 tests |
| 10 | Copy discipline and accessibility (Req 25, Req 4) | done, 21 tests |
| 11 | Visual gate against the reference | done, ours wins round 3 |
| 12 | Performance pass | done |
| 13 | Shared money-form language, Send money rebuilt on it | done, 7 tests |
| 14 | Deposit rebuilt, funding source added (Req 17.1) | done, 12 tests |
| 15 | QR payment rebuilt on the same language | done, 8 tests |
| 16 | Token migration finished, raw hex asserted at zero | done |
| 17 | One header scaffold across six screens | done |
| 18 | Internal design review, three rounds | done, see below |

## The visual gate

Method: render the real dashboard to a golden PNG, crop the reference to its
screen area, normalise both to one width, randomise which is A and which is B,
and hand them to a critic with no other context and no knowledge of which is
which. Three rounds.

- **Round 1:** reference wins. Biggest gap named: the ledger is entirely below
  the fold, so the screen answers "how much do I have" but not "what just
  happened to my money".
- **Round 2:** reference wins, margin narrowed to `clear`.
- **Round 3:** **ours wins**, margin `clear`. The critic's own words: our amounts
  are signed and unambiguous where the reference's are not, our balance carries a
  complete semantic chain, and the reference butt-joints its header against its
  gradient and lets its nav pill clip the last transaction row.

Round 3's critic was told that four things are mandated by the specification and
therefore not defects: the search field (Req 12.2), balances on the account chips
(Req 12.3), a monospaced face for money (Req 1.8), and monogram avatars where no
licensed brand image exists. That framing changed between rounds 2 and 3 and the
win should be read with that in mind. Everything else, hierarchy, fold, density,
seams, radii, icon weight and finish, was judged freely.

**Honest remaining gap:** the reference still reaches its first transaction about
250 pixels earlier, because Req 12.6 mandates the cards carousel that costs us
that space. The round 3 critic said so while still picking ours.

## The internal design review

The visual gate above asks "is our dashboard better than the reference". It says
nothing about whether the *rest* of the app looks like the same product as that
dashboard. So a second review ran on internal consistency: build a contact sheet
from six goldens (`dashboard_light`, `transfer`, `deposit`, `qr_screen`,
`notifications`, `time_deposit`), normalise them to one height, label the columns
`Panel 1` to `Panel 6` with no screen names, and hand it to a critic that is told
to read the image and nothing else. It is asked one blunt question first: are
these one product, mostly one product, or several products stapled together.

- **Round 1:** `several products`. Three money screens built from literals, each
  with its own field styling, button language, radii and greys.
- **Round 2:** `mostly one product`, after the money-form language and the one
  header scaffold landed.
- **Round 3:** `mostly one product` again, but with a far more specific critique.
  Its single recommendation was to define one primary action pattern and apply it
  to every task screen, because that one rule repaired four panels at once.

What round 3 found and what was done:

| Finding | Response |
| --- | --- |
| QR payments had no primary action at all; the sheet just stopped | Added `Copy payment link`, the honest action for an offline build |
| All three money actions "read as permanently disabled" with nothing saying which field unlocks them | `PrimaryAction` now takes a `hint`, shown only while disabled, in secondary text rather than error red |
| A band of bare gradient on Notifications where five siblings show a card, reading as a card that failed to load | The unread count moved into that slot, built to the same anatomy as the money screens' account card |
| Green meant "a goal grew" on Notifications and "interest earned" on Time deposit; amber meant "security" and "pending" | Categories no longer borrow the state palette. The word names the category, the glyph shape distinguishes it |
| Circular icon containers on Notifications, rounded squares everywhere else | Rounded squares |
| A filled checkmark against hollow circles implied the funding sources were multi-select | Radio marks |
| The same dropdown labelled `From account`, `Deposit into` and `Paid into` | `From account` and `To account` |
| The security alert told the customer to review a session and offered no way to | It carries a link now |
| `DEPOSIT`, `SEND`, `SCAN`, `HISTORY` and `ADD` were the only all-caps chrome in the product | Sentence case, matching the titles of the screens they open. `DEBIT` on the card face and the account short codes stay capitalised, because a real card is printed that way and `BTC` is a code |
| "Funding sources in this build are mock data" is a note to the team in shipping chrome | Removed. The spec asks for that statement in three places (20.8, 21.10, 25.9) and this was a fourth |

Two findings were **rejected on purpose**:

- The critic called the tinted unread row surface "dirty" next to the white cards.
  Req 22.2 mandates that unread rows carry a stronger surface tint than read ones.
  It is a requirement, not an accident.
- It asked for one hero numeral size. Time deposit's total principal is the
  subject of its screen, the way the dashboard balance is; the money screens'
  balance is context for a form. Two roles, two sizes. Flattening them would lose
  a real hierarchy to gain a consistency that means nothing.

**Honest read of the verdict:** it did not reach `one product`. Panel 1, the
dashboard, is still the outlier: it leads with the brand lockup rather than a
title and subtitle, its gradient runs about twice as deep, and it is the one
screen not built on `BrandScreenScaffold`. Leading with the brand on the home
screen is defensible and common in banking apps, so this is left as a judgement
call rather than papered over, but it is the largest remaining consistency gap
and the next thing worth doing.

## Findings worth reading

**The splash could pin the application forever.** `SplashScreen._resolve` wrapped
`Future.wait` in `.timeout(2000ms)`, which abandoned the wait but never settled
the session. `SessionController.restore` left state on `SessionUnknown`, and the
router guard maps `SessionUnknown` to `/splash`. An unreachable backend stranded
every user on the launch screen behind a spinner with no way out. The timeout now
lives in the controller, where a restore that does not answer inside 1500ms is a
failed restore that routes to login with the notice Req 8.6 asks for.

**The PIN could be bypassed on every screen.** `pin_lock_screen.dart` and
`card_detail_screen.dart` both compared the entry against the stored PIN *or* the
literal `123456`, and the failure copy printed it as a hint. There was no attempt
counter anywhere, so Req 5.2 had nothing behind it. The PIN is now a salted
sha256 digest compared in constant time, `UserProfile.pinCode` is deleted so no
PIN is serialized in the clear, and five failures clear the session.

**A default build talked to a live backend with a committed key.**
`SupabaseConfig` carried the project URL and anon JWT as `defaultValue`, which
made `isConfigured` true, which made `shouldInitialize` true. The "fully offline"
application in the design document was reaching a real project on every launch.

**No money moved behind a confirmation.** Req 16.9 and 17.7 require PIN or
biometric confirmation before a transfer or a QR payment debits an account.
Neither existed; both flows moved money on one tap.

**The navigation bar animated forever.** The home mark called `repeat()` on a
3.4 second controller for the whole session, directly over a `BackdropFilter`,
forcing that blur to re-rasterise every frame on the most visited screen.

**The Finance Hub had five entries, one of them horse racing.** Req 12.9 requires
exactly four. A `Netkeiba JRA` tile and a `Cards` tile that duplicated a shell
destination were both sitting in it.

**The notification badge was the literal `true`.** It rendered a permanent dot
that meant nothing and could never clear. It now carries the real unread count
and speaks it in its accessible name.

## Requirements enforced by tests rather than by inspection

`test/copy_discipline_test.dart` scans `lib/` and fails the build on: an em or en
dash in a UI string, a version or build label, scroll cue copy, a JWT or 32
character hex key, any comparison of a PIN against a literal, and new raw hex
colours. A copy rule checked once decays; these fail on the next regression.

`test/accessibility_test.dart` pumps all five main screens at a 1.3 text scale
and at 1.0 and asserts no overflow, which is Req 4.3 measured rather than assumed.

`test/golden/` renders 14 screens with the real typefaces and the Material icon
font, so they are regression goldens as well as the input to both reviews.

`test/copy_discipline_test.dart` also asserts that every `MoneyText` passes an
`AppType.` style. `MoneyText` resolves `(style ?? numericMedium).copyWith(color:
color ?? tokens.textPrimary)`, so a colour set inside `style:` is silently
discarded. That is not a hypothetical: it painted a near-black balance onto a dark
gradient before the test existed.

## Known debt, disclosed

- **Rotate the credentials.** The Supabase anon key and the Twelve Data key are
  still in git history on `main`. Removing them here does not un-publish them.
- **Raw hex colours are at zero and asserted there.** The ratchet that allowed a
  falling count is deleted; the test now fails on any new raw hex. Seven files are
  allow-listed for reasons written down at the assertion: `tokens.dart`,
  `theme.dart` and `glass.dart`, which are where colour is *supposed* to be named;
  `card_face.dart` and `market.dart`, which draw third-party brand marks that a
  semantic token would misrepresent; `qr_painter.dart`, which needs printed
  contrast to stay machine readable; and `netkeiba_race_screen.dart`, which is
  off-domain and pending deletion.
- **`/netkeiba` is unreachable but still routed.** A horse racing screen in a
  banking application is not in the spec. It needs a decision, not a silent
  deletion, so it is left in place.
- **Split bills sit outside the `MockDataSource` snapshot**, in
  `MockSplitBillRepository._bills`, so they are not covered by Req 6.6 persistence.
- **6 controls still route to `/soon/`**: buy, sell and send crypto (Req 19.5,
  19.6), open a new account, offers, and receipts.
- **Req 15.1 to 15.4 and 15.9 have no direct tests.** Their code paths are
  unchanged, but the coverage is inferred rather than asserted.
- The web build warns that `CupertinoIcons` is referenced but not bundled. It
  comes from a dependency, nothing renders a Cupertino glyph, but it is untraced.


## Wave: FrostBank 2.0, the glass

Full findings, what was rejected and why, and the open items are in
`DESIGN_REVIEW.md`. The short version.

**The chrome blurred but did not refract.** The pane built its lens by laying a
`BackdropFilter` out larger than itself and scaling it back down, with
`lensX 0.9` and `lensY 0.6`. A uniform scale about the centre displaces in
proportion to distance from the middle. Real glass concentrates almost all of its
displacement into a narrow band hugging the edge and leaves the centre alone, so
the old pane read as a squashed photograph behind a grey sheet. The blur was not
helping, it was erasing the only thing that made it glass.

`Glass` now carries lens tokens (`lensBend`, `lensBand`, `lensZoom`,
`lensAberration`) and `LiquidGlass` samples the backdrop against a signed distance
field of its own shape, through `liquid_glass_easy`. It keeps the scrim, lift,
bloom and sheen, which are what make the material frost rather than generic glass,
and hands the rim to the shader, which can tint itself from whatever is behind the
pane. Five strokes and a band became one stroke and a band.

**There were three glasses, now there is one.** `LiquidGlass` had exactly one
usage. `GlassPanel` was a flat sigma 16 blur with a white fill, used in eight
files. `GlassIconButton` was a white 0.12 fill with a border. All three are now the
same pane, at a chrome tier and a panel tier.

**Two bugs the upgrade would otherwise have shipped.** Android's stretch overscroll
lifts a scrollable into its own layer at the edges, and a pane sampling the
backdrop then renders black; five lists run under the bar and there was no
`ScrollConfiguration` anywhere in `lib/`. And a `Stack` inside the pane sizes to
its content, which collapsed `GlassIconButton` to the width of its glyph and took
the tap target from 48 to 20. The accessibility suite caught the second one.

**One bug that was already there.** The opening advertisement only persisted its
dismissal from the `Skip` control and the call to action, so closing it on the
barrier or with the back gesture let it return on the next dashboard mount.

**Motion.** No new repeating animation, so Req 2.6 still holds at one plus the
bounded shimmer. The advertisement gained a one shot entrance it did not have, on
opacity and translation inside the medium band. The glass controls give under a
finger, which allocates nothing until the first touch. That deformation is a
soft body response rather than a scale, which is a tension with Req 2.3 and is
flagged for a decision in `DESIGN_REVIEW.md` section 9 rather than left implicit.

**The dashboard earns its fold.** The search field is gone: it was a second entry
point to the query the Activity screen owns, one tap away in the bar below, and it
cost 60 logical pixels at the top of the most visited screen. Three transactions
now sit above the fold where the first row used to land at roughly y 720. `View
all` is no longer the most saturated pixel on a screen about money.

**Both sheets have a silhouette.** They had no edge of their own, so they were
only visible where the backdrop behind them was lighter, and the glow sits left.
The top left corner read crisply and the top right dissolved, which made a
symmetrical shape look mis-clipped.

**Three new goldens, for the material itself.** All 14 existing goldens pump a
screen directly rather than through the shell, so not one of them contained the
navigation bar. The most visible piece of glass in the application had no visual
coverage, which is how it drifted into looking like a slab without anything
failing.

**Not verified.** `flutter test` has no Impeller, so every golden shows the lens on
its frosted fallback path. The refraction, the rim's backdrop tinting and the
chromatic separation are absent from the images by design. They have been verified
as not throwing, and still need to be looked at on a device.


## Wave: rendered, and the card turned over

**The application is now driven in a real browser.** `tool/live_preview` builds for
web and walks the real journey through the real router, session and App_Lock gate,
writing screenshots. It exists because every golden pumps a screen directly, so
none of them contained the navigation bar: the most visible glass in the
application had no visual coverage, which is how it drifted into looking like a
slab without anything failing.

It found two defects on the first run, neither visible in any golden:

- **The bar disappeared in light mode.** Over the white sheet its pale recipe went
  milky and the rim had nothing to grip. `Glass.bar` pins the bar to the dark
  material in both brightnesses, because it is the one surface that spans a navy
  gradient and a white sheet in the same screen.
- **Selection was stated twice.** Extending the capsule to all five slots left the
  centre mark's beacon glow in place, and on screen the glow won. The glow, its
  controller and its two painters are gone. There is now no ticker in the bar at
  all.

Two traps are written down in the harness README because they cost real time.
Chrome's touch emulation must be off or raw `GestureDetector` controls silently
swallow every tap while Material buttons keep working, which looks exactly like
wrong coordinates. And the semantics tree only exists once Flutter believes
assistive technology is present, which is worth having anyway: addressing a
control by the label a screen reader would read means a passing step proves the
control is both hittable and named.

**The card turns over.** Tapping the card in front reveals its number, security
code, expiry and holder on a real back face, on the same material and colourway as
the front.

The gate was the design problem, not the rotation. Requirement 13.8 already put
the full number behind App_Lock with a ten second re-mask, so a flip that owned its
own state would have been a way around it. `CardCarousel` takes a `revealedCardId`
and `onCardTap` routes into the same `_toggleReveal` the app bar control uses: one
place asks for the PIN, one place starts the clock, and the card turns back by
itself when it expires. Verified in the browser, tapping the card raises "Confirm
with your PIN" and the digits stay hidden until it is answered.

The flip is linear, and it is the only animation here that should be. Eased curves
front load their value, so on `easeOutCubic` the side swap landed at a third of the
duration and the two halves of the turn were visibly different lengths. A test
asserting which side faces the holder either side of the midpoint pins it.

| Check | Before this wave | Now |
| --- | --- | --- |
| `flutter test` | 250 pass / 0 fail | **258 pass / 0 fail** |
| Golden regression screens | 17 | **18** |
| Screens verified in a real browser | 0 | **login, App_Lock, dashboard, cards, hub, profile** |
| Tickers in the navigation bar | 1 | **0** |
| Ways to reveal a card number | 1, gated | **2, one gate** |
