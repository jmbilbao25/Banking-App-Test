import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_bank_app/core/persistence/persistence_store.dart';
import 'package:mobile_bank_app/core/security/biometric_service.dart';
import 'package:mobile_bank_app/data/mock_data_source.dart';
import 'package:mobile_bank_app/data/mock_seed.dart';
import 'package:mobile_bank_app/domain/models.dart';
import 'package:mobile_bank_app/domain/repositories.dart';
import 'package:mobile_bank_app/state/providers.dart';
import 'package:mobile_bank_app/state/session_controller.dart';

/// Signs in without a platform channel, so the lock can be exercised against a
/// real signed in session.
class _StubAuth implements AuthRepository {
  @override
  Future<UserProfile?> restoreSession() async => null;

  @override
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async => MockSeed.profile;

  @override
  Future<UserProfile> signUp({
    required String fullName,
    required String email,
    required String mobile,
    required String password,
  }) async => MockSeed.profile;

  @override
  Future<void> signOut() async {}
}

class _EnrolledBiometrics implements BiometricService {
  @override
  Future<bool> isEnrolled() async => true;

  @override
  Future<BiometricResult> authenticate({required String reason}) async =>
      BiometricResult.success;
}

ProviderContainer _container(PersistenceStore store) {
  final container = ProviderContainer(
    retry: noAutomaticRetry,
    overrides: [
      persistenceStoreProvider.overrideWithValue(store),
      authRepositoryProvider.overrideWithValue(_StubAuth()),
      biometricServiceProvider.overrideWithValue(
        const UnavailableBiometricService(),
      ),
      mockDataSourceProvider.overrideWithValue(
        MockDataSource(now: DateTime(2026, 8, 5))
          ..latencyOverride = (() => Duration.zero),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<ProviderContainer> _signedIn(PersistenceStore store) async {
  final container = _container(store);
  await container
      .read(sessionProvider.notifier)
      .signIn(email: MockSeed.demoEmail, password: 'winterlight');
  return container;
}

void main() {
  group('AppLockController', () {
    test('starts locked so Req 5.1 holds on a signed in launch', () {
      final container = _container(InMemoryPersistenceStore());
      expect(container.read(appLockProvider), isTrue);
    });

    test('unlock releases the guard', () {
      final container = _container(InMemoryPersistenceStore());
      container.read(appLockProvider.notifier).unlock();
      expect(container.read(appLockProvider), isFalse);
    });

    test('re-locks after 120 seconds away, per Req 5.4', () async {
      final store = InMemoryPersistenceStore();
      final container = await _signedIn(store);
      final lock = container.read(appLockProvider.notifier);
      lock.unlock();

      final left = DateTime(2026, 8, 8, 10, 0, 0);
      lock.noteBackgrounded(left);
      final engaged = lock.noteResumed(
        left.add(const Duration(seconds: 120)),
      );

      expect(engaged, isTrue);
      expect(container.read(appLockProvider), isTrue);
    });

    test('does not re-lock for a brief switch away', () async {
      final store = InMemoryPersistenceStore();
      final container = await _signedIn(store);
      final lock = container.read(appLockProvider.notifier);
      lock.unlock();

      final left = DateTime(2026, 8, 8, 10, 0, 0);
      lock.noteBackgrounded(left);
      final engaged = lock.noteResumed(left.add(const Duration(seconds: 15)));

      expect(engaged, isFalse);
      expect(container.read(appLockProvider), isFalse);
    });

    test('measures the gap across a process death', () async {
      final store = InMemoryPersistenceStore();
      final first = await _signedIn(store);
      first.read(appLockProvider.notifier).unlock();
      final left = DateTime(2026, 8, 8, 10, 0, 0);
      first.read(appLockProvider.notifier).noteBackgrounded(left);

      // A fresh container stands in for the process being killed while away.
      final second = await _signedIn(store);
      final engaged = second
          .read(appLockProvider.notifier)
          .noteResumed(left.add(const Duration(minutes: 30)));

      expect(
        engaged,
        isTrue,
        reason: 'the timestamp is in the store, not in memory',
      );
    });

    test('honours a longer chosen timeout, per Req 23.4', () async {
      final store = InMemoryPersistenceStore();
      final container = await _signedIn(store);
      container
          .read(preferencesProvider.notifier)
          .setSessionTimeout(const Duration(minutes: 15));
      final lock = container.read(appLockProvider.notifier);
      lock.unlock();

      final left = DateTime(2026, 8, 8, 10, 0, 0);
      lock.noteBackgrounded(left);

      expect(lock.noteResumed(left.add(const Duration(minutes: 5))), isFalse);
      lock.noteBackgrounded(left);
      expect(lock.noteResumed(left.add(const Duration(minutes: 16))), isTrue);
    });

    test('ignores the timeout when nobody is signed in', () {
      final container = _container(InMemoryPersistenceStore());
      final lock = container.read(appLockProvider.notifier);

      final left = DateTime(2026, 8, 8, 10, 0, 0);
      lock.noteBackgrounded(left);

      expect(lock.noteResumed(left.add(const Duration(hours: 1))), isFalse);
    });
  });

  group('biometric service', () {
    test('reports no enrolment when the channel is absent', () async {
      const service = UnavailableBiometricService();
      expect(await service.isEnrolled(), isFalse);
      expect(
        await service.authenticate(reason: 'Unlock FrostBank'),
        BiometricResult.unavailable,
      );
    });

    test('an enrolled device can confirm, per Req 5.3', () async {
      final service = _EnrolledBiometrics();
      expect(await service.isEnrolled(), isTrue);
      expect(
        await service.authenticate(reason: 'Unlock FrostBank'),
        BiometricResult.success,
      );
    });

    test('biometricEnrolledProvider surfaces the enrolment state', () async {
      final container = ProviderContainer(
        retry: noAutomaticRetry,
        overrides: [
          biometricServiceProvider.overrideWithValue(_EnrolledBiometrics()),
        ],
      );
      addTearDown(container.dispose);

      expect(await container.read(biometricEnrolledProvider.future), isTrue);
    });
  });

  group('logout clears the security namespace', () {
    test('session and PIN are both removed, per Req 5.10', () async {
      final store = InMemoryPersistenceStore();
      final container = await _signedIn(store);
      await container.read(pinVaultProvider).setPin('418902');

      expect(store.readString(StoreKeys.session), isNotNull);
      expect(container.read(pinVaultProvider).hasPin, isTrue);

      await container.read(sessionProvider.notifier).signOut();

      expect(store.readString(StoreKeys.session), isNull);
      expect(container.read(pinVaultProvider).hasPin, isFalse);
      expect(container.read(sessionProvider), isA<SessionSignedOut>());
    });

    test('a signed in session is retained for the next launch, per Req 9.5', () async {
      final store = InMemoryPersistenceStore();
      await _signedIn(store);

      // A fresh container stands in for the next launch.
      final next = _container(store);
      await next.read(sessionProvider.notifier).restore();

      expect(next.read(sessionProvider), isA<SessionSignedIn>());
    });

    test('logout carries a reason through to login, per Req 5.2', () async {
      final store = InMemoryPersistenceStore();
      final container = await _signedIn(store);

      await container
          .read(sessionProvider.notifier)
          .signOut(notice: 'You entered an incorrect PIN 5 times.');

      final state = container.read(sessionProvider);
      expect(state, isA<SessionSignedOut>());
      expect((state as SessionSignedOut).notice, contains('incorrect PIN'));
    });
  });
}
