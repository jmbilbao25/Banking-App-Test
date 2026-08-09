import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_bank_app/core/design/theme.dart';
import 'package:mobile_bank_app/core/persistence/persistence_store.dart';
import 'package:mobile_bank_app/core/security/biometric_service.dart';
import 'package:mobile_bank_app/data/mock_data_source.dart';
import 'package:mobile_bank_app/presentation/screens/change_pin_sheet.dart';
import 'package:mobile_bank_app/presentation/screens/profile_screen.dart';
import 'package:mobile_bank_app/state/providers.dart';

class _Enrolled implements BiometricService {
  @override
  Future<bool> isEnrolled() async => true;

  @override
  Future<BiometricResult> authenticate({required String reason}) async =>
      BiometricResult.success;
}

Widget _harness({
  required PersistenceStore store,
  required Widget child,
  BiometricService? biometrics,
}) => ProviderScope(
  retry: noAutomaticRetry,
  overrides: [
    persistenceStoreProvider.overrideWithValue(store),
    biometricServiceProvider.overrideWithValue(
      biometrics ?? const UnavailableBiometricService(),
    ),
    mockDataSourceProvider.overrideWithValue(
      MockDataSource(now: DateTime(2026, 8, 5))
        ..latencyOverride = (() => Duration.zero),
    ),
  ],
  // Sheets normally get their Material from showModalBottomSheet, so the
  // harness supplies one when a sheet is pumped directly.
  child: MaterialApp(
    theme: AppTheme.light(),
    home: Material(child: child),
  ),
);

void main() {
  group('biometric unlock control, Req 23.7', () {
    testWidgets('is disabled and explains itself when nothing is enrolled', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          store: InMemoryPersistenceStore(),
          child: const ProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('No biometric is enrolled on this device'),
        findsOneWidget,
      );

      final switches = tester
          .widgetList<Switch>(find.byType(Switch))
          .where((widget) => widget.onChanged == null);
      expect(
        switches,
        isNotEmpty,
        reason: 'the control must render disabled, not merely off',
      );
    });

    testWidgets('is operable when a biometric is enrolled', (tester) async {
      await tester.pumpWidget(
        _harness(
          store: InMemoryPersistenceStore(),
          child: const ProfileScreen(),
          biometrics: _Enrolled(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('No biometric is enrolled on this device'),
        findsNothing,
      );
    });
  });

  group('session timeout control, Req 23.4', () {
    testWidgets('shows the stored value rather than a fixed label', (
      tester,
    ) async {
      final store = InMemoryPersistenceStore({
        StoreKeys.sessionTimeoutSeconds: 900,
      });

      await tester.pumpWidget(
        _harness(store: store, child: const ProfileScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('15 minutes'), findsOneWidget);
    });

    testWidgets('defaults to the 120 second floor from Req 5.4', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          store: InMemoryPersistenceStore(),
          child: const ProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 minutes'), findsOneWidget);
    });
  });

  group('PIN row label', () {
    testWidgets('offers to set a PIN when none is stored', (tester) async {
      await tester.pumpWidget(
        _harness(
          store: InMemoryPersistenceStore(),
          child: const ProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Set PIN'), findsOneWidget);
      expect(find.text('Change PIN'), findsNothing);
    });
  });

  group('ChangePinSheet, Req 23.5 and 23.6', () {
    testWidgets('asks for the current PIN first when one exists', (
      tester,
    ) async {
      final store = InMemoryPersistenceStore();
      final container = ProviderContainer(
        overrides: [persistenceStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      await container.read(pinVaultProvider).setPin('418902');

      await tester.pumpWidget(
        _harness(store: store, child: const ChangePinSheet()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Enter your current PIN'), findsOneWidget);
    });

    testWidgets('rejects a wrong current PIN and keeps the old one', (
      tester,
    ) async {
      final store = InMemoryPersistenceStore();
      final container = ProviderContainer(
        overrides: [persistenceStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final vault = container.read(pinVaultProvider);
      await vault.setPin('418902');

      await tester.pumpWidget(
        _harness(store: store, child: const ChangePinSheet()),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '000000');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(
        find.text('That PIN is incorrect. Your PIN has not changed.'),
        findsOneWidget,
      );
      expect(
        vault.verify('418902'),
        isTrue,
        reason: 'Req 23.6: the current PIN stays in place',
      );
      expect(find.text('Choose a new PIN'), findsNothing);
    });

    testWidgets('accepts the current PIN then two matching new entries', (
      tester,
    ) async {
      final store = InMemoryPersistenceStore();
      final container = ProviderContainer(
        overrides: [persistenceStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final vault = container.read(pinVaultProvider);
      await vault.setPin('418902');

      await tester.pumpWidget(
        _harness(store: store, child: const ChangePinSheet()),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '418902');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a new PIN'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '775510');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm your new PIN'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '775510');
      await tester.tap(find.text('Save PIN'));
      await tester.pumpAndSettle();

      expect(vault.verify('775510'), isTrue);
      expect(vault.verify('418902'), isFalse);
    });

    testWidgets('a mismatched confirmation returns to the new PIN step', (
      tester,
    ) async {
      final store = InMemoryPersistenceStore();

      await tester.pumpWidget(
        _harness(store: store, child: const ChangePinSheet()),
      );
      await tester.pumpAndSettle();

      // No PIN stored, so the sheet opens straight on the new entry.
      expect(find.text('Choose a new PIN'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '775510');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '111111');
      await tester.tap(find.text('Save PIN'));
      await tester.pumpAndSettle();

      expect(
        find.text('Those PINs did not match. Choose a new PIN again.'),
        findsOneWidget,
      );
      expect(find.text('Choose a new PIN'), findsOneWidget);
    });

    testWidgets('rejects a PIN that is not six digits', (tester) async {
      await tester.pumpWidget(
        _harness(
          store: InMemoryPersistenceStore(),
          child: const ChangePinSheet(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '4189');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.textContaining('must be 6 digits'), findsOneWidget);
    });
  });

  group('About, Req 23.9', () {
    testWidgets('states that every figure is mock data', (tester) async {
      await tester.pumpWidget(
        _harness(
          store: InMemoryPersistenceStore(),
          child: const ProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('About this build'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('About this build'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Every balance, card number'),
        findsOneWidget,
      );
    });
  });
}
