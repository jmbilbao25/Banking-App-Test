import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_bank_app/core/design/theme.dart';
import 'package:mobile_bank_app/core/persistence/persistence_store.dart';
import 'package:mobile_bank_app/core/persistence/pin_vault.dart';
import 'package:mobile_bank_app/core/security/biometric_service.dart';
import 'package:mobile_bank_app/data/mock_data_source.dart';
import 'package:mobile_bank_app/domain/models.dart';
import 'package:mobile_bank_app/domain/repositories.dart';
import 'package:mobile_bank_app/presentation/widgets/app_lock_confirm.dart';
import 'package:mobile_bank_app/state/providers.dart';
import 'package:mobile_bank_app/state/session_controller.dart';

class _Biometrics implements BiometricService {
  _Biometrics({this.enrolled = false, this.result = BiometricResult.success});

  final bool enrolled;
  final BiometricResult result;
  int prompts = 0;

  @override
  Future<bool> isEnrolled() async => enrolled;

  @override
  Future<BiometricResult> authenticate({required String reason}) async {
    prompts++;
    return result;
  }
}

class _StubAuth implements AuthRepository {
  @override
  Future<UserProfile?> restoreSession() async => null;

  @override
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async => throw UnimplementedError();

  @override
  Future<UserProfile> signUp({
    required String fullName,
    required String email,
    required String mobile,
    required String password,
  }) async => throw UnimplementedError();

  @override
  Future<void> signOut() async {}
}

/// Hosts the gate behind a button, which is the shape every real caller uses.
class _Host extends ConsumerWidget {
  const _Host({required this.onResult});

  final void Function(bool) onResult;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: ElevatedButton(
        onPressed: () async {
          final ok = await confirmWithAppLock(
            context,
            ref,
            reason: 'Confirm sending 40.00 to Ana Reyes.',
          );
          onResult(ok);
        },
        child: const Text('Send money'),
      ),
    ),
  );
}

Widget _harness({
  required PersistenceStore store,
  required void Function(bool) onResult,
  BiometricService? biometrics,
}) => ProviderScope(
  retry: noAutomaticRetry,
  overrides: [
    persistenceStoreProvider.overrideWithValue(store),
    authRepositoryProvider.overrideWithValue(_StubAuth()),
    biometricServiceProvider.overrideWithValue(
      biometrics ?? const UnavailableBiometricService(),
    ),
    mockDataSourceProvider.overrideWithValue(
      MockDataSource(now: DateTime(2026, 8, 5))
        ..latencyOverride = (() => Duration.zero),
    ),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: _Host(onResult: onResult)),
);

PinVault _vaultOver(PersistenceStore store) {
  final container = ProviderContainer(
    overrides: [persistenceStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container.read(pinVaultProvider);
}

void main() {
  group('confirmWithAppLock, the gate before any debit', () {
    testWidgets('refuses and explains when no PIN has been set', (
      tester,
    ) async {
      final results = <bool>[];
      await tester.pumpWidget(
        _harness(
          store: InMemoryPersistenceStore(),
          onResult: results.add,
        ),
      );

      await tester.tap(find.text('Send money'));
      await tester.pumpAndSettle();

      expect(
        results,
        [false],
        reason: 'no PIN means nothing can be confirmed, so no money may move',
      );
      expect(
        find.text('Set a PIN in your profile before moving money.'),
        findsOneWidget,
      );
    });

    testWidgets('asks for the PIN and states what is being confirmed', (
      tester,
    ) async {
      final store = InMemoryPersistenceStore();
      await _vaultOver(store).setPin('418902');

      await tester.pumpWidget(
        _harness(store: store, onResult: (_) {}),
      );
      await tester.tap(find.text('Send money'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm with your PIN'), findsOneWidget);
      expect(
        find.text('Confirm sending 40.00 to Ana Reyes.'),
        findsOneWidget,
        reason: 'the customer must see what they are approving',
      );
    });

    testWidgets('returns true only for the stored PIN', (tester) async {
      final store = InMemoryPersistenceStore();
      await _vaultOver(store).setPin('418902');
      final results = <bool>[];

      await tester.pumpWidget(_harness(store: store, onResult: results.add));
      await tester.tap(find.text('Send money'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '418902');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(results, [true]);
    });

    testWidgets('an incorrect PIN keeps the sheet open and counts down', (
      tester,
    ) async {
      final store = InMemoryPersistenceStore();
      final vault = _vaultOver(store);
      await vault.setPin('418902');
      final results = <bool>[];

      await tester.pumpWidget(_harness(store: store, onResult: results.add));
      await tester.tap(find.text('Send money'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '000000');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(results, isEmpty, reason: 'the caller must not proceed yet');
      expect(find.text('Confirm with your PIN'), findsOneWidget);
      expect(find.textContaining('attempts remaining'), findsOneWidget);
      expect(vault.failedAttempts, 1);
    });

    testWidgets('cancelling returns false so nothing moves', (tester) async {
      final store = InMemoryPersistenceStore();
      await _vaultOver(store).setPin('418902');
      final results = <bool>[];

      await tester.pumpWidget(_harness(store: store, onResult: results.add));
      await tester.tap(find.text('Send money'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(results, [false]);
    });

    testWidgets('a spent attempt budget signs the customer out, per Req 5.2', (
      tester,
    ) async {
      final store = InMemoryPersistenceStore();
      final vault = _vaultOver(store);
      await vault.setPin('418902');
      // Four failures already recorded, so the next one spends the budget.
      for (var i = 0; i < PinVault.maxAttempts - 1; i++) {
        await vault.recordFailure();
      }

      final results = <bool>[];
      await tester.pumpWidget(_harness(store: store, onResult: results.add));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(_Host)),
      );

      await tester.tap(find.text('Send money'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '000000');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(results, [false]);
      expect(container.read(sessionProvider), isA<SessionSignedOut>());
      expect(
        (container.read(sessionProvider) as SessionSignedOut).notice,
        contains('incorrect PIN'),
      );
    });

    testWidgets('an enrolled biometric confirms without asking for the PIN', (
      tester,
    ) async {
      final store = InMemoryPersistenceStore();
      await _vaultOver(store).setPin('418902');
      final biometrics = _Biometrics(enrolled: true);
      final results = <bool>[];

      await tester.pumpWidget(
        _harness(store: store, onResult: results.add, biometrics: biometrics),
      );
      await tester.tap(find.text('Send money'));
      await tester.pumpAndSettle();

      expect(results, [true]);
      expect(biometrics.prompts, 1);
      expect(
        find.text('Confirm with your PIN'),
        findsNothing,
        reason: 'Req 5.3: biometric is primary, PIN is the fallback',
      );
    });

    testWidgets('a cancelled biometric falls back to PIN entry', (
      tester,
    ) async {
      final store = InMemoryPersistenceStore();
      await _vaultOver(store).setPin('418902');
      final biometrics = _Biometrics(
        enrolled: true,
        result: BiometricResult.cancelled,
      );

      await tester.pumpWidget(
        _harness(store: store, onResult: (_) {}, biometrics: biometrics),
      );
      await tester.tap(find.text('Send money'));
      await tester.pumpAndSettle();

      expect(biometrics.prompts, 1);
      expect(
        find.text('Confirm with your PIN'),
        findsOneWidget,
        reason: 'a dismissed prompt must not fail the whole action',
      );
    });

    testWidgets('the biometric prompt is skipped when the preference is off', (
      tester,
    ) async {
      final store = InMemoryPersistenceStore({
        StoreKeys.biometricUnlock: false,
      });
      await _vaultOver(store).setPin('418902');
      final biometrics = _Biometrics(enrolled: true);

      await tester.pumpWidget(
        _harness(store: store, onResult: (_) {}, biometrics: biometrics),
      );
      await tester.tap(find.text('Send money'));
      await tester.pumpAndSettle();

      expect(biometrics.prompts, 0);
      expect(find.text('Confirm with your PIN'), findsOneWidget);
    });

    testWidgets('rejects a PIN that is not six digits', (tester) async {
      final store = InMemoryPersistenceStore();
      await _vaultOver(store).setPin('418902');

      await tester.pumpWidget(_harness(store: store, onResult: (_) {}));
      await tester.tap(find.text('Send money'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '4189');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(find.textContaining('must be 6 digits'), findsOneWidget);
    });
  });
}
