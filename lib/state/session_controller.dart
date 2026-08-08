import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/persistence/persistence_store.dart';
import '../data/model_codecs.dart';
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
  PersistenceStore get _store => ref.read(persistenceStoreProvider);

  void _invalidateUserData() {
    ref.invalidate(profileProvider);
    ref.invalidate(accountsProvider);
    ref.invalidate(cardsProvider);
    ref.invalidate(goalsProvider);
    ref.invalidate(selectedAccountIdProvider);
  }

  /// The session retained by Persistence_Store, if any.
  ///
  /// Requirement 9.10 needs Login to know a previous session exists without
  /// restoring it, so this is a plain read with no state transition.
  UserProfile? peekPersistedSession() {
    final json = _store.readJson(StoreKeys.session);
    if (json == null) return null;
    return ModelCodecs.profileFromMap(json, now: DateTime.now());
  }

  Future<void> _persistSession(UserProfile profile) => _store.writeJson(
    StoreKeys.session,
    ModelCodecs.profileToMap(profile),
  );

  /// Called once by the splash screen. Always settles on a terminal state, so
  /// the router guard can never hold the application on the splash.
  Future<void> restore() async {
    try {
      // Requirement 9.5: a retained session is honoured before the repository is
      // consulted, which is what makes a signed in launch survive a restart.
      final persisted = peekPersistedSession();
      if (persisted != null) {
        ref.read(mockDataSourceProvider).adoptSession(persisted);
        state = SessionSignedIn(persisted);
        _invalidateUserData();
        return;
      }

      final profile = await _auth.restoreSession().timeout(restoreTimeout);
      state = profile == null
          ? const SessionSignedOut()
          : SessionSignedIn(profile);
      if (profile != null) await _persistSession(profile);
      _invalidateUserData();
    } on Object {
      state = const SessionSignedOut(
        notice: 'We could not restore your session. Please sign in again.',
      );
      _invalidateUserData();
    }
  }

  /// Promotes a session that Persistence_Store already holds, used after App_Lock
  /// accepts a PIN on a launch that started from the lock screen. Returns false
  /// when nothing is retained, so the caller can send the user to sign in.
  bool unlockPersistedSession() {
    final persisted = peekPersistedSession();
    if (persisted == null) return false;
    ref.read(mockDataSourceProvider).adoptSession(persisted);
    state = SessionSignedIn(persisted);
    _invalidateUserData();
    return true;
  }

  Future<void> signIn({required String email, required String password}) async {
    final profile = await _auth.signIn(email: email, password: password);
    await _persistSession(profile);
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
    await _persistSession(profile);
    state = SessionSignedIn(profile);
    _invalidateUserData();
  }

  /// Requirement 5.10: clears the session and the PIN from Persistence_Store.
  Future<void> signOut({String? notice}) async {
    await _auth.signOut();
    ref.read(preferencesProvider.notifier).clearRememberedEmail();
    await ref.read(pinVaultProvider).clear();
    state = SessionSignedOut(notice: notice);
    _invalidateUserData();
  }
}
