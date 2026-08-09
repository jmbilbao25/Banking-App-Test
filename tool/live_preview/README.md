# Live preview

Drives the real application in a real browser and writes screenshots. This exists
because the golden suite cannot answer two kinds of question.

The first is structural. Every golden pumps a single screen directly, so **none of
them contains the navigation bar**. The most visible glass surface in the
application had no visual coverage at all, which is how it drifted into looking
like a grey slab without any test failing.

The second is about the material. Under `flutter test` there is no Impeller, so the
lens in `LiquidGlass` always takes its frosted fallback path. A golden can pin the
geometry, the washes, the rim and the sheen. It cannot show refraction.

This harness does not fix the second problem, because a headless browser is Skia
too. It fixes the first, and it does something goldens cannot: it walks the real
journey, through the real router, the real session and the real App_Lock gate, and
it fails the way a person would if a control is not where it appears to be.

## Running it

```bash
flutter build web --release

cd build/web && python3 -m http.server 8099 --bind 127.0.0.1 &
chrome --headless=new --no-sandbox --disable-gpu \
  --remote-debugging-port=9222 --remote-allow-origins='*' about:blank &

cd tool/live_preview
TOUCH=0 STEPS='[
  {"click":[195,371]},{"type":"ava.mercado@frostbank.app"},
  {"click":[195,458]},{"type":"frostbank"},
  {"tap":"Sign in","exact":true},{"wait":4000},
  {"dump":true},
  {"shot":"dashboard"}
]' node drive.mjs
```

No dependencies. Node 22 ships a global `WebSocket`, so it speaks the DevTools
protocol directly.

## Steps

| Step | Effect |
| --- | --- |
| `{"shot":"name"}` | PNG into `SHOT_DIR` |
| `{"click":[x,y]}` | Mouse click at a CSS pixel coordinate |
| `{"tap":"label"}` | Click the centre of the semantics node matching `label` |
| `{"type":"text"}` | Insert text into whatever has focus |
| `{"dump":true}` | Print the semantics tree with roles, sizes and centres |
| `{"wait":ms}` | Sleep |

## Two things that will waste an hour if you do not know them

**Turn touch emulation off.** `TOUCH=0`. With Chrome's touch emulation enabled,
Material buttons still respond but the raw `GestureDetector` controls do not, so
the PIN keypad silently swallows every tap and the dots never fill. This cost real
time to find and it looks exactly like wrong coordinates.

**`{"tap":...}` needs the semantics tree, and Flutter only builds one when it
thinks assistive technology is present.** The driver clicks the hidden
`flt-semantics-placeholder` to turn it on. Note what that buys beyond convenience:
addressing a control by the label a screen reader would read means a passing step
proves the control is both hittable *and* named. The root node carries every
string on the screen concatenated together, so the matcher prefers interactive
roles and the tightest label. Without that it reliably clicks the middle of the
page.

## The journey to a signed in state

On a fresh browser profile there is no PIN, so `PinLockScreen` opens in its create
stage and takes the same six digits twice before it lets you in. Six digits auto
submit, which means a screenshot taken right after the sixth tap catches the dots
already cleared and looks like nothing happened.

Sign in with `ava.mercado@frostbank.app` and `frostbank`, then `123456` twice. The
opening advertisement lands on the first dashboard mount, so skip it before
photographing anything.

## Findings this harness produced

Recorded because they are the argument for keeping it.

- The navigation bar went milky white on the white sheet in light mode and lost
  its silhouette. It is now pinned to the dark material in both brightnesses. See
  `Glass.bar`.
- The centre brand mark kept its beacon glow after the selection capsule was
  extended to all five slots, so selection was being stated twice and the louder
  statement read as a primary action. The glow, its controller and its two
  painters are gone.
- `PinLockScreen` says "Enter your 6-digit security PIN to unlock" even while it
  is asking you to *set* one, and again while it is asking you to confirm it. Not
  fixed here. Worth fixing.
