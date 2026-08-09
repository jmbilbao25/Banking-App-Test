# FrostBank — Android APKs (v0.1.0, performance pass)

Prebuilt Android artifacts for [`jmbilbao25/Banking-App-Test`](https://github.com/jmbilbao25/Banking-App-Test),
built from the branch in [PR #5, "Stop repainting what has not changed"](https://github.com/jmbilbao25/Banking-App-Test/pull/5).

This is an artifact-only branch: it holds no source code, so cloning it stays cheap.
For the build from `main` before the performance pass, see [`apk/v0.1.0`](https://github.com/jmbilbao25/Banking-App-Test/tree/apk/v0.1.0).

## Downloads

| File | ABI | Size | Use it for |
| --- | --- | --- | --- |
| `frostbank-0.1.0-perf-arm64-v8a.apk` | arm64-v8a | 29.5 MiB | Any phone from ~2016 onward — pick this one |
| `frostbank-0.1.0-perf-armeabi-v7a.apk` | armeabi-v7a | 25.6 MiB | Older 32-bit ARM devices |
| `frostbank-0.1.0-perf-universal.apk` | all three ABIs | 75.9 MiB | Emulators, or when you don't know the ABI |

## What changed

Six changes to how often the frame repaints, none of which changes a pixel — the
golden suite and all 258 tests pass unmodified. The full argument is in the PR;
in short:

1. `Motion.isReduced` / `Glass.isReduced` read their accessibility flags as
   MediaQuery *aspects* instead of taking the whole `MediaQueryData`. Measured:
   over six frames of a keyboard sliding up, a whole-data reader rebuilds seven
   times and an aspect reader once. Every glass pane in the tree calls this.
2. `FrostBackdrop` no longer shares a layer with its content, so a scroll frame
   stops redrawing five screen-sized gradient fills.
3. The brand and card-face gradients are cached instead of rebuilt per paint.
4. The navigation glyphs get their own layer, so the always-visible bar stops
   re-running ten shadowed draws whenever anything beneath it moves.
5. The staggered entrance animation drives its render objects instead of
   rebuilding an `Opacity` — and its save layer — per row per frame.
6. The lens fragment shaders are compiled during launch rather than on the first
   frame that needs them.

Where to expect it: typing in a form, opening any screen, scrolling under the
navigation bar, and the first navigation after launch.

## Signing — read this before installing

Signed with the **Android debug keystore**, because `android/app/build.gradle.kts`
still ships the template's `signingConfig = signingConfigs.getByName("debug")`
for the release build type. Fine for sideloading and QA, unfit for Play Store
distribution. Android will ask you to allow installs from unknown sources.

## Verifying a download

```
sha256sum -c SHA256SUMS
```
