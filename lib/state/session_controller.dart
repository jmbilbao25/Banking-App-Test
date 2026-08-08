import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import '../domain/repositories.dart';
import 'providers.dart';

/// Authentication state. `unknown` is the launch state while the splash screen
/// resolves the session.
sealed class SessionState {
  const SessionState();
}

class SessionUnknown extends SessionState {
  const SessionUnknown();
}

class SessionSignedOut extends SessionState {
  const SessionSignedOut({this.notice});

  /// Set when a restore attempt failed, so login can explain why.
  final String? notice;
}

class SessionSignedIn extends SessionState {
  const SessionSignedIn(this.profile);

  final UserProfile profile;
}

/// Owns sign in, sign out, and session restore.
class SessionController extends Notifier<SessionState> {
  /// A restore that has not answered inside this window is treated as a failed
  /// restore. Requirement 8.5 caps the splash at 2000ms, so the decision has to
  /// be made before that cap rather than waiting on an unreachable backend.
  static const restoreTimeout = Duration(milliseconds: 1500);

  @override
  SessionState build() => const SessionUnknown();

  AuthRepository get _auth => ref.read(authRepositoryProvider);

  void _invalidateUserData() {
    ref.invalidate(profileProvider);
    ref.invalidate(accountsProvider);
    ref.invalidate(cardsProvider);
    ref.invalidate(goalsProvider);
    ref.invalidate(selectedAccountIdProvider);
  }

  /// Called once by the splash screen. Always settles on a terminal state, so
  /// the router guard can never hold the application on the splash.
  Future<void> restore() async {
    try {
      final profile = await _auth.restoreSession().timeout(restoreTimeout);
      state = profile == null
          ? const SessionSignedOut()
          : SessionSignedIn(profile);
      _invalidateUserData();
    } on Object {
      state = const SessionSignedOut(
        notice: 'We could not restore your session. Please sign in again.',
      );
      _invalidateUserData();
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    final profile = await _auth.signIn(email: email, password: password);
    state = SessionSignedIn(profile);
    _invalidateUserData();
  }

  Future<void> signUp({
    required String fullName,
    required String email,
    required String mobile,
    required String password,
  }) async {
    final profile = await _auth.signUp(
      fullName: fullName,
      email: email,
      mobile: mobile,
      password: password,
    );
    state = SessionSignedIn(profile);
    _invalidateUserData();
  }

  Future<void> signOut() async {
    await _auth.signOut();
    ref.read(preferencesProvider.notifier).clearRememberedEmail();
    state = const SessionSignedOut();
    _invalidateUserData();
  }
}
