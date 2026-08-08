import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_bank_app/core/persistence/credential_vault.dart';
import 'package:mobile_bank_app/core/persistence/persistence_store.dart';
import 'package:mobile_bank_app/core/persistence/pin_vault.dart';
import 'package:mobile_bank_app/data/mock_data_source.dart';
import 'package:mobile_bank_app/data/mock_snapshot.dart';
import 'package:mobile_bank_app/state/preferences_controller.dart';
import 'package:mobile_bank_app/state/providers.dart';

ProviderContainer _container(PersistenceStore store) {
  final container = ProviderContainer(
    retry: noAutomaticRetry,
    overrides: [persistenceStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('PinVault', () {
    test('stores a digest rather than the PIN itself', () async {
      final store = InMemoryPersistenceStore();
      final vault = PinVault(store);

      await vault.setPin('418902');

      expect(vault.hasPin, isTrue);
      expect(
        store.readString(StoreKeys.pinDigest),
        isNot(contains('418902')),
        reason: 'the PIN must not be recoverable from the store',
      );
    });

    test('accepts the stored PIN and rejects any other', () async {
      final vault = PinVault(InMemoryPersistenceStore());
      await vault.setPin('418902');

      expect(vault.verify('418902'), isTrue);
      expect(vault.verify('123456'), isFalse);
      expect(
        vault.verify('000000'),
        isFalse,
        reason: 'the old build accepted 123456 on every screen',
      );
    });

    test('an empty vault cannot be unlocked by guessing', () {
      final vault = PinVault(InMemoryPersistenceStore());
      expect(vault.verify('123456'), isFalse);
    });

    test('locks out after five consecutive failures, per Req 5.2', () async {
      final vault = PinVault(InMemoryPersistenceStore());
      await vault.setPin('418902');

      for (var attempt = 0; attempt < PinVault.maxAttempts; attempt++) {
        expect(vault.isLockedOut, isFalse);
        await vault.recordFailure();
      }

      expect(vault.isLockedOut, isTrue);
      expect(vault.attemptsRemaining, 0);
    });

    test('a correct entry clears the failure count', () async {
      final vault = PinVault(InMemoryPersistenceStore());
      await vault.setPin('418902');
      await vault.recordFailure();
      await vault.recordFailure();
      expect(vault.failedAttempts, 2);

      await vault.clearFailures();

      expect(vault.failedAttempts, 0);
      expect(vault.attemptsRemaining, PinVault.maxAttempts);
    });

    test('clear removes the PIN, per Req 5.10', () async {
      final store = InMemoryPersistenceStore();
      final vault = PinVault(store);
      await vault.setPin('418902');

      await vault.clear();

      expect(vault.hasPin, isFalse);
      expect(store.readString(StoreKeys.pinSalt), isNull);
    });

    test('rejects a PIN that is not six digits', () {
      expect(PinVault.formatError('418902'), isNull);
      expect(PinVault.formatError('4189'), isNotNull);
      expect(PinVault.formatError('41890a'), isNotNull);
    });
  });

  group('CredentialVault', () {
    test('adopts the first password used for an address', () async {
      final vault = CredentialVault(InMemoryPersistenceStore());

      expect(vault.hasCredential('ava@frostbank.app'), isFalse);
      expect(
        vault.verify(email: 'ava@frostbank.app', password: 'anything'),
        isTrue,
        reason: 'an unknown address must not be rejected on a fresh install',
      );

      await vault.setPassword(
        email: 'ava@frostbank.app',
        password: 'winterlight',
      );

      expect(vault.hasCredential('ava@frostbank.app'), isTrue);
    });

    test('rejects an incorrect password once one is stored, per Req 9.8', () async {
      final vault = CredentialVault(InMemoryPersistenceStore());
      await vault.setPassword(
        email: 'ava@frostbank.app',
        password: 'winterlight',
      );

      expect(
        vault.verify(email: 'ava@frostbank.app', password: 'winterlight'),
        isTrue,
      );
      expect(
        vault.verify(email: 'ava@frostbank.app', password: 'wrongpassword'),
        isFalse,
      );
    });

    test('is case insensitive on the address', () async {
      final vault = CredentialVault(InMemoryPersistenceStore());
      await vault.setPassword(email: 'Ava@FrostBank.app', password: 'winterlight');

      expect(
        vault.verify(email: 'ava@frostbank.app', password: 'winterlight'),
        isTrue,
      );
    });

    test('a reset replaces the stored credential, per Req 11.6', () async {
      final vault = CredentialVault(InMemoryPersistenceStore());
      await vault.setPassword(email: 'ava@frostbank.app', password: 'oldpassword');

      await vault.setPassword(email: 'ava@frostbank.app', password: 'newpassword');

      expect(
        vault.verify(email: 'ava@frostbank.app', password: 'oldpassword'),
        isFalse,
      );
      expect(
        vault.verify(email: 'ava@frostbank.app', password: 'newpassword'),
        isTrue,
      );
    });
  });

  group('MockDataSnapshot', () {
    test('round trips the mutable data set', () {
      final source = MockDataSource(now: DateTime(2026, 8, 5))
        ..latencyOverride = (() => Duration.zero);
      final original = source.toSnapshot();

      final decoded = MockDataSnapshot.tryDecode(
        original.toJson(),
        now: DateTime(2026, 8, 5),
      );

      expect(decoded, isNotNull);
      expect(decoded!.accounts.length, original.accounts.length);
      expect(decoded.cards.length, original.cards.length);
      expect(decoded.transactions.length, original.transactions.length);
      expect(decoded.accounts.first.totalBalance, original.accounts.first.totalBalance);
      expect(decoded.profile.email, original.profile.email);
      expect(decoded.cardCounter, original.cardCounter);
      expect(decoded.goalCounter, original.goalCounter);
    });

    test('refuses a blob from another version rather than launching on it', () {
      final source = MockDataSource(now: DateTime(2026, 8, 5));
      final json = source.toSnapshot().toJson()..['version'] = 99;

      expect(
        MockDataSnapshot.tryDecode(json, now: DateTime(2026, 8, 5)),
        isNull,
      );
    });

    test('refuses a truncated blob', () {
      expect(
        MockDataSnapshot.tryDecode(
          {'version': MockDataSnapshot.currentVersion, 'accounts': <Object>[]},
          now: DateTime(2026, 8, 5),
        ),
        isNull,
      );
    });

    test('carries no PIN into storage, per Req 5.9', () {
      final source = MockDataSource(now: DateTime(2026, 8, 5));
      final encoded = source.toSnapshot().toJson();

      expect(encoded['profile'].toString(), isNot(contains('pin')));
    });
  });

  group('data set persistence', () {
    test('a write is persisted and reloaded, per Req 6.6 and 6.7', () async {
      final store = InMemoryPersistenceStore();

      final first = _container(store);
      final source = first.read(mockDataSourceProvider);
      source.latencyOverride = () => Duration.zero;
      final before = (await source.accounts()).first;

      await source.deposit(before.id, 250.25);
      // onMutate coalesces into a microtask, so let it run.
      await Future<void>.delayed(Duration.zero);

      expect(
        store.readString(StoreKeys.dataSnapshot),
        isNotNull,
        reason: 'Req 6.6: a successful write persists the mutated state',
      );

      // A fresh container stands in for the next launch.
      final second = _container(store);
      final reloaded = second.read(mockDataSourceProvider);
      reloaded.latencyOverride = () => Duration.zero;
      final after = (await reloaded.accounts()).firstWhere(
        (account) => account.id == before.id,
      );

      expect(
        after.totalBalance,
        closeTo(before.totalBalance + 250.25, 0.001),
        reason: 'Req 6.7: the persisted data set is loaded instead of reseeding',
      );
    });

    test('an empty store reseeds', () async {
      final container = _container(InMemoryPersistenceStore());
      final source = container.read(mockDataSourceProvider);
      source.latencyOverride = () => Duration.zero;

      expect((await source.accounts()).length, greaterThanOrEqualTo(3));
    });
  });

  group('preferences persistence', () {
    test('an explicit theme survives a restart, per Req 1.14', () {
      final store = InMemoryPersistenceStore();

      _container(store).read(preferencesProvider.notifier)
          .setThemeMode(ThemeMode.dark);

      expect(
        _container(store).read(preferencesProvider).themeMode,
        ThemeMode.dark,
      );
    });

    test('balance masking survives a restart, per Req 5.6', () {
      final store = InMemoryPersistenceStore();

      final first = _container(store);
      expect(first.read(preferencesProvider).balancesHidden, isFalse);
      first.read(preferencesProvider.notifier).toggleBalanceVisibility();

      expect(
        _container(store).read(preferencesProvider).balancesHidden,
        isTrue,
      );
    });

    test('the session timeout choice survives a restart, per Req 23.4', () {
      final store = InMemoryPersistenceStore();

      _container(store).read(preferencesProvider.notifier)
          .setSessionTimeout(const Duration(minutes: 15));

      expect(
        _container(store).read(preferencesProvider).sessionTimeout,
        const Duration(minutes: 15),
      );
    });

    test('defaults to the 120 second floor Req 5.4 names', () {
      expect(
        _container(InMemoryPersistenceStore())
            .read(preferencesProvider)
            .sessionTimeout,
        const Duration(seconds: 120),
      );
      expect(
        Preferences.sessionTimeoutOptions.first,
        const Duration(seconds: 120),
      );
    });

    test('a corrupt stored value degrades instead of throwing', () {
      final store = InMemoryPersistenceStore({
        StoreKeys.themeMode: 'not_a_theme_mode',
        StoreKeys.currencyCode: 'ZZZ',
      });

      final preferences = _container(store).read(preferencesProvider);

      expect(preferences.themeMode, ThemeMode.system);
      expect(preferences.activeCurrency.code, 'USD');
    });
  });
}
