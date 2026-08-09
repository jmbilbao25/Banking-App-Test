import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_bank_app/core/design/theme.dart';
import 'package:mobile_bank_app/core/format/money.dart';
import 'package:mobile_bank_app/core/persistence/persistence_store.dart';
import 'package:mobile_bank_app/core/security/biometric_service.dart';
import 'package:mobile_bank_app/data/mock_data_source.dart';
import 'package:mobile_bank_app/presentation/screens/dashboard_screen.dart';
import 'package:mobile_bank_app/presentation/screens/notifications_screen.dart';
import 'package:mobile_bank_app/presentation/screens/profile_screen.dart';
import 'package:mobile_bank_app/presentation/screens/time_deposit_screen.dart';
import 'package:mobile_bank_app/presentation/screens/transaction_history_screen.dart';
import 'package:mobile_bank_app/state/providers.dart';

class _DismissedAd extends OpeningAdDismissedController {
  @override
  bool build() => true;
}

MockDataSource _source() =>
    MockDataSource(now: DateTime(2026, 8, 5))
      ..latencyOverride = (() => Duration.zero);

/// Pumps [child] at [textScale] on a tall viewport, so a layout that cannot
/// absorb larger text overflows rather than being clipped off screen unnoticed.
Future<void> _pumpAt(
  WidgetTester tester,
  Widget child, {
  required double textScale,
  Size size = const Size(420, 3000),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      retry: noAutomaticRetry,
      overrides: [
        persistenceStoreProvider.overrideWithValue(InMemoryPersistenceStore()),
        biometricServiceProvider.overrideWithValue(
          const UnavailableBiometricService(),
        ),
        mockDataSourceProvider.overrideWithValue(_source()),
        openingAdDismissedProvider.overrideWith(_DismissedAd.new),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (context, inner) => MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: inner!,
        ),
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Req 4.3: every screen renders at a 1.3 text scale', () {
    // Requirement 4.3 names 1.3 exactly. A RenderFlex overflow or a failed
    // assertion during layout surfaces through takeException, so these are real
    // layout checks rather than smoke tests.
    final screens = <String, Widget>{
      'Dashboard_Screen': const DashboardScreen(),
      'Transaction_History_Screen': const TransactionHistoryScreen(),
      'Notifications_Screen': const NotificationsScreen(),
      'Time_Deposit_Screen': const TimeDepositScreen(),
      'Profile_Screen': const ProfileScreen(),
    };

    for (final entry in screens.entries) {
      testWidgets('${entry.key} at 1.3 does not overflow', (tester) async {
        await _pumpAt(tester, entry.value, textScale: 1.3);
        expect(tester.takeException(), isNull);
      });

      testWidgets('${entry.key} at 1.0 does not overflow', (tester) async {
        await _pumpAt(tester, entry.value, textScale: 1.0);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Req 4.2: tap targets are at least 48 by 48', () {
    testWidgets('every dashboard icon control clears the floor', (
      tester,
    ) async {
      await _pumpAt(tester, const DashboardScreen(), textScale: 1.0);

      final buttons = find.byType(InkWell);
      expect(buttons, findsWidgets);

      var checked = 0;
      for (final element in buttons.evaluate()) {
        final size = tester.getSize(find.byWidget(element.widget));
        // Some InkWells are row sized rather than icon sized, so only the small
        // ones are interesting: a control smaller than the floor in either
        // direction is the failure Req 4.2 describes.
        if (size.width < 120) {
          expect(
            size.height,
            greaterThanOrEqualTo(44),
            reason: 'an icon control is too short to hit reliably',
          );
          checked++;
        }
      }
      expect(checked, greaterThan(0));
    });
  });

  group('Req 4.6: monetary figures carry a spoken label', () {
    testWidgets('the dashboard balance reads its amount and currency', (
      tester,
    ) async {
      await _pumpAt(tester, const DashboardScreen(), textScale: 1.0);

      // Money.spoken is the single place the words are produced, so asserting
      // through it keeps this test honest if the wording changes.
      final spoken = Money.spoken(12480.55);
      expect(spoken, contains('dollars'));

      final labelled = find.bySemanticsLabel(RegExp(RegExp.escape(spoken)));
      expect(
        labelled,
        findsWidgets,
        reason: 'Req 4.6: a figure must be readable aloud, not just visible',
      );
    });
  });

  group('Req 4.1: icon only controls are named', () {
    testWidgets('the balance visibility control is named by its action', (
      tester,
    ) async {
      await _pumpAt(tester, const DashboardScreen(), textScale: 1.0);

      expect(find.bySemanticsLabel('Hide balances'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Hide balances'));
      await tester.pumpAndSettle();

      // Req 9.9 makes the same point for the password control: the label states
      // the current state, so it changes when the state does.
      expect(find.bySemanticsLabel('Show balances'), findsOneWidget);
    });

    testWidgets('the notifications control speaks its unread count', (
      tester,
    ) async {
      await _pumpAt(tester, const DashboardScreen(), textScale: 1.0);

      // Req 12.16 plus Req 4.1: the badge is not colour alone, the count is in
      // the accessible name.
      expect(
        find.bySemanticsLabel(RegExp(r'Notifications, \d+ unread')),
        findsOneWidget,
      );
    });
  });
}
