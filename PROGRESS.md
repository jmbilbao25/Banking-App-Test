# FrostBank production-grade gauntlet

Live progress. Updated as the work evolves.

**Bar:** `.kiro/specs/mobile-banking-app/requirements.md`, 25 requirements / 231 acceptance criteria.
**Visual gate:** `Reference Images/image.png` (Conceptzilla iOS Banking App 2025).
**Measurable half:** `flutter analyze` at 0 issues, `flutter test` green.

Toolchain: Flutter 3.44.9 / Dart 3.12.2 at `/projects/toolchain/flutter`, wrapper `/projects/toolchain/bin/fl`.
Run checks with `/projects/toolchain/bin/fl flutter analyze` and `/projects/toolchain/bin/fl flutter test`.

## Measurable half

| Check | Start | Now |
| --- | --- | --- |
| `flutter analyze` | 19 issues | **0 issues** |
| `flutter test` | 44 pass / 3 fail | **68 pass / 1 fail** |
| Secrets in source (Req 5.9) | 3 live credentials | **0** |
| PIN bypass | accepted on every screen | **removed** |

## Wave status

| # | Piece | State |
| --- | --- | --- |
| 1 | Green baseline: analyzer + failing tests | done, 1 test waits on wave 8 |
| 2 | Purge committed secrets (Req 5.9) | done |
| 3 | Persistence_Store foundation (Req 6.6, 6.7) | done, 22 tests |
| 4 | App_Lock security surface (Req 5.1 to 5.5) | in progress |
| 5 | Profile security and settings (Req 23.3 to 23.7) | not started |
| 6 | Forgot_Password_Screen (Req 11) | not started |
| 7 | Notifications_Screen + badge (Req 22, 12.15, 12.16) | not started |
| 8 | Time_Deposit_Screen (Req 21) | not started |
| 9 | Gaps in existing screens (Req 13, 15, 16, 17) | not started |
| 10 | Copy discipline + accessibility (Req 25, Req 4) | not started |
| 11 | Visual gate vs the mock | not started |
| 12 | Performance pass | not started |

## Findings fixed so far

**The splash could pin the application forever.** `SplashScreen._resolve` wrapped
`Future.wait` in `.timeout(2000ms)`, which abandoned the wait but never settled the
session. `SessionController.restore` left `state` on `SessionUnknown`, and the router
guard maps `SessionUnknown` to `/splash`, so an unreachable backend or a stalled
profiles query stranded every user on the launch screen with a spinner. The timeout now
lives in the controller, where a restore that does not answer inside 1500ms becomes a
failed restore that routes to login with the notice requirement 8.6 asks for.

**A default build talked to a live backend with a committed key.** `SupabaseConfig`
carried the project URL and anon JWT as `defaultValue`, which made `isConfigured` true,
which made `shouldInitialize` true. So the default build was not offline at all. Both
defines are now defaultless, `shouldInitialize` follows real configuration, and a build
without credentials stays on the mock repository layer the design document describes.
`ApiConfig` likewise no longer carries the Twelve Data key it documented as checked in.

**Removing the market key would have broken crypto,** because
`marketRepositoryProvider` always returned the live repository and `_get` throws when
no key is present, so every rate would have become a permanent error state. Added
`MockMarketRepository`, deterministic and marked as mock throughout, plus
`marketDataIsMockProvider` so the crypto surface can state that its rates are mock data
per requirement 19.8 rather than presenting generated bars as live.

**Copy violations on the login screen.** The primary action read `Sign in with Password`
(4 words, over the 3 word cap in requirement 25.6) and the secondary read
`Login with 6-Digit PIN Pad`, which put two labels on one intent and broke requirement
25.8. Now `Sign in` and `Use PIN instead`.

**The PIN could be bypassed on every screen.** Both `pin_lock_screen.dart` and
`card_detail_screen.dart` compared the entry against the stored PIN *or* the literal
`123456`, so the second clause accepted that value no matter what the customer had set.
The failure message printed the value as a hint. There was also no attempt counter at
all, so requirement 5.2 had nothing behind it. The PIN now lives in `PinVault` as a
salted sha256 digest compared in constant time, `UserProfile.pinCode` is deleted so no
PIN reaches disk in the clear, and five wrong entries clear the session and say why.

**Auth was a hardcoded password table.** `MockDataSource.signIn` carried 120 lines of
email and password pairs. Those are gone; `CredentialVault` holds salted digests, and the
first password used for an address is adopted, so the seeded profiles stay reachable
without shipping a secret. This also turns requirement 9.8 and requirement 11.6 into
things that can actually be implemented rather than described. The lock screen no longer
fabricates a sign-in with a guessed password, because a real session is now retained.

## Known gaps still open

- `App_Lock` has no biometric path, no 120 second background re-lock, and does not
  obscure content in the task switcher.
- Requirement 11 (Forgot Password), 21 (Time Deposit) and 22 (Notifications) have no
  implementation. 13 live controls still route to `/soon/...`.
- `netkeiba_race_screen.dart`, a horse racing screen, is routed at `/netkeiba` inside a
  banking application and is not in the spec.
- Split bills live outside `MockDataSource`, in `MockSplitBillRepository._bills`, and
  `SplitBillsController` reseeds from `initialBills` on any provider rebuild, so bills
  are not covered by the snapshot yet.
- The crypto surface does not yet state that its rates are mock data, which
  requirement 19.8 asks for. `marketDataIsMockProvider` exists for it.
