import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/persistence/persistence_store.dart';
import 'providers.dart';
import 'session_controller.dart';

/// Whether the authenticated surface is currently behind App_Lock.
///
/// Requirement 5.1 requires PIN or biometric confirmation before dashboard
/// content becomes visible on a launch that already holds a session, and
/// requirement 5.4 requires the same after 120 seconds or more in the background.
/// The router guard reads this, so a locked state cannot be routed around.
class AppLockController extends Notifier<bool> {
  PersistenceStore get _store => ref.read(persistenceStoreProvider);

  /// Starts locked. An unauthenticated launch is unaffected, because the guard
  /// only consults the lock once a session exists.
  @override
  bool build() => true;

  bool get isLocked => state;

  void unlock() {
    state = false;
    _store.remove(StoreKeys.lastBackgroundedAt);
  }

  void lock() => state = true;

  /// Records when the application left the foreground, so the elapsed time can be
  /// measured on the way back in. Stored rather than held in memory, because the
  /// operating system may kill the process while it is away.
  void noteBackgrounded(DateTime at) {
    if (ref.read(sessionProvider) is! SessionSignedIn) return;
    _store.writeInt(
      StoreKeys.lastBackgroundedAt,
      at.millisecondsSinceEpoch,
    );
  }

  /// Applies the timeout on return to the foreground. Returns true when the lock
  /// was engaged, which the caller uses to decide whether to route to App_Lock.
  bool noteResumed(DateTime at) {
    final storedAt = _store.readInt(StoreKeys.lastBackgroundedAt);
    if (storedAt == null) return false;
    _store.remove(StoreKeys.lastBackgroundedAt);

    if (ref.read(sessionProvider) is! SessionSignedIn) return false;

    final away = at.difference(
      DateTime.fromMillisecondsSinceEpoch(storedAt),
    );
    final timeout = ref.read(preferencesProvider).sessionTimeout;
    if (away >= timeout) {
      state = true;
      return true;
    }
    return false;
  }
}
