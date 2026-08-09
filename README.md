# FrostBank — Android release APKs (v0.1.0)

Prebuilt Android artifacts for [`jmbilbao25/Banking-App-Test`](https://github.com/jmbilbao25/Banking-App-Test).
This is an artifact-only branch: it holds no source code, so cloning it stays cheap.

Built from `main` @ [`00d2865`](https://github.com/jmbilbao25/Banking-App-Test/commit/00d28659b2942cec9eae06a1b235f23525919601).

## Downloads

| File | ABI | Size | Use it for |
| --- | --- | --- | --- |
| `frostbank-0.1.0-arm64-v8a.apk` | arm64-v8a | 29.4 MiB | Any phone from ~2016 onward — pick this one |
| `frostbank-0.1.0-armeabi-v7a.apk` | armeabi-v7a | 25.5 MiB | Older 32-bit ARM devices |
| `frostbank-0.1.0-universal.apk` | arm64-v8a + armeabi-v7a + x86_64 | 75.8 MiB | Emulators, or when you don't know the ABI |

To download a single file from the GitHub UI, open it and use the download button
(GitHub does not render APKs inline).

## Build details

| | |
| --- | --- |
| Application ID | `com.FrostBank.mobile_bank_app` |
| Version | `0.1.0` (versionCode `1`) |
| minSdk / targetSdk / compileSdk | 24 / 36 / 36 |
| Build type | `release` (Dart AOT, icon tree-shaking on) |
| Flutter | 3.44.9 stable · Dart 3.12.2 |
| Toolchain | AGP 9.0.1 · Gradle 9.1.0 · Kotlin 2.3.20 · JDK 21 · NDK 28.2.13676358 |

## Signing — read this before installing

These APKs are signed with the **Android debug keystore**, because `android/app/build.gradle.kts`
still ships the template's `signingConfig = signingConfigs.getByName("debug")` for the release
build type. That makes them fine for sideloading and QA, and unfit for Play Store distribution.
Android will ask you to allow installs from unknown sources.

Swapping in a real upload key means adding a `signingConfigs.release` block backed by a keystore
kept outside the repo (`key.properties` + `android/.gitignore`).

## Verifying a download

```
sha256sum -c SHA256SUMS
```

Or check one file directly against `SHA256SUMS`.
