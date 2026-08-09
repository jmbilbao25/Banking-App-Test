# FrostBank — Android APKs (v0.1.0, capture allowed)

Prebuilt Android artifacts for [`jmbilbao25/Banking-App-Test`](https://github.com/jmbilbao25/Banking-App-Test),
built from the branch in [PR #7, "Let the application be screenshotted and recorded"](https://github.com/jmbilbao25/Banking-App-Test/pull/7).

Cut from `main`, so it carries the merged work from PR #5 (repaint pass) and PR #6
(glass on the bar only) as well.

Artifact-only branch: no source code, so cloning it stays cheap.

| Build | Branch |
| --- | --- |
| `main`, before any of this | [`apk/v0.1.0`](https://github.com/jmbilbao25/Banking-App-Test/tree/apk/v0.1.0) |
| Repaint pass (#5) | [`apk/v0.1.0-perf`](https://github.com/jmbilbao25/Banking-App-Test/tree/apk/v0.1.0-perf) |
| Glass on the bar only (#5 + #6) | [`apk/v0.1.0-glass`](https://github.com/jmbilbao25/Banking-App-Test/tree/apk/v0.1.0-glass) |
| **This one** — #5 + #6 + #7 | `apk/v0.1.0-capture` |

## Downloads

| File | ABI | Size | Use it for |
| --- | --- | --- | --- |
| `frostbank-0.1.0-capture-arm64-v8a.apk` | arm64-v8a | 29.4 MiB | Any phone from ~2016 onward — pick this one |
| `frostbank-0.1.0-capture-armeabi-v7a.apk` | armeabi-v7a | 25.5 MiB | Older 32-bit ARM devices |
| `frostbank-0.1.0-capture-universal.apk` | all three ABIs | 75.8 MiB | Emulators, or when you don't know the ABI |

## What changed

`FLAG_SECURE` is gone, so **screenshots and screen recording now work on every
screen**. It was blocking capture app-wide, signed in or not.

Requirement 5.5 — obscuring authenticated content in the task switcher preview —
is still met, by the privacy cover in `AppLockScope`, which is what was already
carrying it on iOS. Verified on the binary: `apkanalyzer` shows `MainActivity` in
the previous build carrying an `onCreate` that reaches for `getWindow`, and the
same class here carrying nothing but its constructor.

Worth knowing: with the flag gone, anything that can record the screen can record
a revealed card number or a PIN being entered. That is the trade for being able to
demonstrate the app. The three lines that restore the flag are documented in
`MainActivity.kt`.

## Signing — read this before installing

Signed with the **Android debug keystore**, because `android/app/build.gradle.kts`
still ships the template's `signingConfig = signingConfigs.getByName("debug")` for
the release build type. Fine for sideloading and QA, unfit for Play Store
distribution. Android will ask you to allow installs from unknown sources.

Because the signing key is unchanged, this installs over the previous builds
without an uninstall.

## Verifying a download

```
sha256sum -c SHA256SUMS
```
