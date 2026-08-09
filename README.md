# FrostBank — Android APKs (v0.1.0, glass on the bar only)

Prebuilt Android artifacts for [`jmbilbao25/Banking-App-Test`](https://github.com/jmbilbao25/Banking-App-Test),
built from the branch in [PR #6, "Keep the lens on the bar, paint the rest"](https://github.com/jmbilbao25/Banking-App-Test/pull/6),
which stacks on [PR #5](https://github.com/jmbilbao25/Banking-App-Test/pull/5). So this build carries both changes.

Artifact-only branch: no source code, so cloning it stays cheap.

| Build | Branch |
| --- | --- |
| `main`, before any of this | [`apk/v0.1.0`](https://github.com/jmbilbao25/Banking-App-Test/tree/apk/v0.1.0) |
| Repaint pass only (#5) | [`apk/v0.1.0-perf`](https://github.com/jmbilbao25/Banking-App-Test/tree/apk/v0.1.0-perf) |
| **This one** — #5 + #6 | `apk/v0.1.0-glass` |

## Downloads

| File | ABI | Size | Use it for |
| --- | --- | --- | --- |
| `frostbank-0.1.0-glass-arm64-v8a.apk` | arm64-v8a | 29.4 MiB | Any phone from ~2016 onward — pick this one |
| `frostbank-0.1.0-glass-armeabi-v7a.apk` | armeabi-v7a | 25.5 MiB | Older 32-bit ARM devices |
| `frostbank-0.1.0-glass-universal.apk` | all three ABIs | 75.8 MiB | Emulators, or when you don't know the ABI |

## What to look at

**The refracting lens now exists on the navigation bar and nowhere else.** The
dashboard was running four at once; every panel, icon control and modal is now the
same recipe painted, with no backdrop read at all. Compare a login screen or the
dashboard's two top-right controls against the previous build — they should look
the same. That was the point: a panel sits on the brand backdrop, so what its lens
was refracting was a gradient it already knew.

**The cards page has glass of its own**, painted rather than refracted, because
there is nothing behind a card on that screen but a flat page background. The card
now has a lit lower rim, a second surface just inside it, a glow off its base, and
a broad reflection across the dark body.

Where to feel the difference: the dashboard, and any screen with a panel on it —
sign in, transfer, deposit, notifications, time deposit.

## Signing — read this before installing

Signed with the **Android debug keystore**, because `android/app/build.gradle.kts`
still ships the template's `signingConfig = signingConfigs.getByName("debug")` for
the release build type. Fine for sideloading and QA, unfit for Play Store
distribution. Android will ask you to allow installs from unknown sources.

## Verifying a download

```
sha256sum -c SHA256SUMS
```
