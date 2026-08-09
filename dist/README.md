# Demo builds

`frostbank-v0.1.0-arm64-v8a.apk` — sideloadable Android build, 30 MB.

arm64 only, deliberately. It is the architecture of every Android phone sold for
years, and a universal APK carrying all three ABIs comes to 79 MB, which is not worth
committing to a source repository. Build the others yourself if you need them:

```
flutter build apk --release --split-per-abi   # arm64, armeabi-v7a, x86_64
flutter build apk --release                   # one universal APK
```

Verify the download against `frostbank-v0.1.0-arm64-v8a.apk.sha256`:

```
sha256sum -c frostbank-v0.1.0-arm64-v8a.apk.sha256
```

## Installing

Copy it to the phone and open it. Android will warn you about installing from an
unknown source, because the APK is signed with a **debug key** rather than a release
keystore — `android/app/build.gradle.kts` still carries the Flutter template's
`signingConfig = signingConfigs.getByName("debug")` on the release build type. That is
fine for sideloading and it is why the warning appears. It is not publishable to Play,
which needs a real keystore, and a real keystore should not be committed here.

## Signing in

**Any email address, and any password of 8 characters or more.** Then set any 6-digit
PIN when the lock screen appears.

There is no account to create and no credential in the source, because there is no
backend in this build. `SupabaseConfig` reads its URL and key from compile-time
`--dart-define`s with no defaults, so without them every repository resolves to the
mock one and the whole data layer is fixtures. `CredentialVault.verify` returns true
when no credential is stored for an address and adopts the first password used for it,
which is what keeps the seeded demo profiles reachable without writing a password into
the repository.

Seeded profiles worth trying, since each has its own name, balances and transaction
history: `ava.mercado@frostbank.app`, `yujin.an@frostbank.app`,
`wonyoung.jang@frostbank.app`, `gaeul.kim@frostbank.app`, `rei.naoi@frostbank.app`,
`liz.kim@frostbank.app`, `hyunseo.lee@frostbank.app`. Any other address still works and
gets a profile synthesised from it.

## Why there is no admin account

One was asked for and deliberately not added. It would not buy anything — access is
already unrestricted in this build, so there is nothing to bypass — and it would cost
three things:

1. The repository states in five separate files that no credential value may appear in
   application source. A literal password would regress that on purpose.
2. `SupabaseAuthRepository` is real code, and `supabase_seed_auth_users.sql` seeds real
   bcrypted passwords. A hardcoded shortcut in the shared sign-in path would become a
   live authentication bypass the moment anyone builds with the Supabase dart-defines.
3. It would be dead weight: the mock path already accepts anything.

If a one-tap demo entry is ever wanted, the shape that fits this codebase is a
`String.fromEnvironment` flag next to `SupabaseConfig`, consumed only inside the mock
repository and additionally guarded on `!SupabaseConfig.isInitialized`, so it is
structurally unreachable in a build that has a real backend. Off unless a build asks
for it, and no secret in source.

## Build provenance

Flutter 3.44.9, compileSdk 36, targetSdk 36, AGP 9.0.1, Gradle 9.1.0, JDK 21.
Built from the `design/liquid-glass-app-shell` branch.
