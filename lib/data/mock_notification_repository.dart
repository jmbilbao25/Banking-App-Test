import 'dart:math';

import '../domain/notification_model.dart';
import '../domain/repositories.dart';

/// Seeded in memory notification store.
///
/// Reads resolve after a randomised delay between 300ms and 900ms so loading
/// skeletons are observable, per requirement 6.5, and no call touches the
/// network. The latency and failure hooks mirror `MockDataSource` exactly, so a
/// test can remove the delay or force the error state.
class MockNotificationRepository implements NotificationRepository {
  /// Pass [seed] to start from a specific feed, for example the empty list that
  /// requirement 22.6 asks the empty state to be rendered for. Pass [now] to
  /// make the relative ages of the seeded feed deterministic.
  MockNotificationRepository({
    DateTime? now,
    Random? random,
    List<AppNotification>? seed,
  }) : _random = random ?? Random(22),
       _rows = List.of(seed ?? NotificationSeed.notifications(now: now));

  final Random _random;
  final List<AppNotification> _rows;

  /// Domains that should fail, so the error state can be verified without a real
  /// backend. Add the key `notifications`.
  final Set<String> errorSimulation = <String>{};

  /// Set to zero in tests to keep them fast.
  Duration Function()? latencyOverride;

  /// Invoked after every successful write so an owner can persist the data set,
  /// matching the `onMutate` hook on `MockDataSource`.
  void Function()? onMutate;

  Duration _latency() {
    final override = latencyOverride;
    if (override != null) return override();
    return Duration(milliseconds: 300 + _random.nextInt(600));
  }

  Future<T> _read<T>(String domain, T Function() body) async {
    await Future<void>.delayed(_latency());
    if (errorSimulation.contains(domain)) {
      throw RepositoryFailure('We could not load your $domain right now.');
    }
    return body();
  }

  /// Write gate. Same latency and failure behaviour as [_read], and it notifies
  /// afterwards so a mutated data set can be persisted.
  Future<T> _write<T>(String domain, T Function() body) async {
    final result = await _read(domain, body);
    onMutate?.call();
    return result;
  }

  /// Unread total, read synchronously so a badge can be resolved without a
  /// second round trip. Requirement 12.16 hangs off this.
  int get unreadCount => _rows.where((row) => !row.read).length;

  @override
  Future<List<AppNotification>> fetchNotifications() =>
      _read('notifications', () {
        final rows = List.of(_rows)..sort((a, b) => b.at.compareTo(a.at));
        return List<AppNotification>.unmodifiable(rows);
      });

  @override
  Future<void> markRead(String id) => _write('notifications', () {
    final index = _rows.indexWhere((row) => row.id == id);
    // An unknown identifier is ignored rather than raised. The feed is the
    // only writer of these identifiers, so a miss means the row was already
    // dropped and there is nothing for the holder to act on.
    if (index == -1) return;
    _rows[index] = _rows[index].copyWith(read: true);
  });

  @override
  Future<void> markAllRead() => _write('notifications', () {
    for (var index = 0; index < _rows.length; index++) {
      if (_rows[index].read) continue;
      _rows[index] = _rows[index].copyWith(read: true);
    }
  });
}
