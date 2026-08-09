import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_bank_app/core/design/theme.dart';
import 'package:mobile_bank_app/core/persistence/persistence_store.dart';
import 'package:mobile_bank_app/data/mock_data_source.dart';
import 'package:mobile_bank_app/presentation/screens/qr_screen.dart';
import 'package:mobile_bank_app/presentation/widgets/money_form.dart';
import 'package:mobile_bank_app/presentation/widgets/qr_painter.dart';
import 'package:mobile_bank_app/state/providers.dart';

/// The QR payment surface, after the migration onto the shared money form
/// vocabulary.
///
/// The camera is a platform channel, so these tests do two things rather than
/// pretend the camera is present. The generate surface, the manual code entry
/// path and the confirmation step are asserted for real, because none of them
/// need a camera. The scanner channel itself is stubbed to a no operation, which
/// is only enough for the pay surface to be built at all: the stub returns
/// nothing from `start`, so the preview resolves to its error view and no
/// assertion below depends on a camera frame.
///
/// What is therefore *not* covered here: the detection path
/// (`MobileScanner.onDetect`), the torch toggle, and the permission denied
/// branch of `errorBuilder`, all three of which need a real channel to reach.
/// The resolver those paths feed is exercised directly instead.
void main() {
  const scannerMethods = MethodChannel(
    'dev.steenbakker.mobile_scanner/scanner/method',
  );
  const scannerEvents = MethodChannel(
    'dev.steenbakker.mobile_scanner/scanner/event',
  );
  const scannerOrientation = MethodChannel(
    'dev.steenbakker.mobile_scanner/scanner/deviceOrientation',
  );

  /// Answers every scanner channel call with null.
  ///
  /// Without this the channels are unimplemented, and an unimplemented event
  /// channel reports a framework error the moment the preview subscribes, which
  /// would fail these tests for a reason that has nothing to do with the screen.
  void stubScannerChannel(WidgetTester tester) {
    final messenger = tester.binding.defaultBinaryMessenger;
    for (final channel in [
      scannerMethods,
      scannerEvents,
      scannerOrientation,
    ]) {
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    }
  }

  late MockDataSource source;

  /// The harness: the seeded world, no latency, and a viewport tall enough that
  /// the whole form is hit testable rather than scrolled out of reach.
  Future<void> pumpScreen(
    WidgetTester tester, {
    double textScale = 1.0,
    Size size = const Size(420, 3200),
  }) async {
    stubScannerChannel(tester);

    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    source = MockDataSource(now: DateTime(2026, 8, 5))
      ..latencyOverride = (() => Duration.zero);

    await tester.pumpWidget(
      ProviderScope(
        retry: noAutomaticRetry,
        overrides: [
          persistenceStoreProvider.overrideWithValue(InMemoryPersistenceStore()),
          mockDataSourceProvider.overrideWithValue(source),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery.withClampedTextScaling(
            minScaleFactor: textScale,
            maxScaleFactor: textScale,
            child: child!,
          ),
          home: const QRScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder amountInput() => find.descendant(
    of: find.byType(AmountField),
    matching: find.byType(TextField),
  );

  double walletBalance() => source.accountsView
      .firstWhere((account) => account.id == 'acc_wallet')
      .availableBalance;

  /// Walks from the opening surface to the confirmation step using a typed code,
  /// which is the path requirement 17.4 provides for a customer with no camera.
  Future<void> enterCode(WidgetTester tester, String code) async {
    await tester.tap(find.text('Scan to pay'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enter code'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(SheetField).first, code);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Find merchant'));
    await tester.pumpAndSettle();
  }

  testWidgets('the generate tab renders the amount field and the account picker',
      (tester) async {
    await pumpScreen(tester);

    expect(find.byType(AmountField), findsOneWidget);
    expect(find.byType(AccountSelectField), findsOneWidget);
    // The picker is populated from the repository rather than from a literal.
    expect(find.text('Everyday Wallet'), findsWidgets);
  });

  testWidgets('entering an amount produces a QR payload', (tester) async {
    await pumpScreen(tester);

    // Nothing to encode yet, so no code is rendered.
    expect(find.byType(QrCodeWidget), findsNothing);

    await tester.enterText(amountInput(), '25');
    await tester.pumpAndSettle();

    expect(find.byType(QrCodeWidget), findsOneWidget);
    expect(find.textContaining('amount=25.00'), findsOneWidget);
    // Req 1.8: the figure beside the code is a monetary figure, so it is
    // formatted by the money layer rather than printed from the field.
    expect(find.text(r'$25.00'), findsOneWidget);
  });

  testWidgets(
    'Req 17.6: an entered code shows the resolved merchant and amount for '
    'confirmation before any debit',
    (tester) async {
      await pumpScreen(tester);
      final opening = walletBalance();

      await enterCode(tester, '204815');

      final expected = QRScreen.paymentCodeDirectory['204815']!;
      expect(find.text('Confirm payment'), findsOneWidget);
      expect(find.text(expected.merchant), findsOneWidget);
      expect(find.text(r'$18.40'), findsOneWidget);
      expect(find.text('204815'), findsOneWidget);
      expect(find.text('Pay now'), findsOneWidget);

      // The confirmation is on screen and the ledger has not moved.
      expect(walletBalance(), opening);
    },
  );

  testWidgets(
    'Req 17.7: no debit happens until App_Lock confirms the customer',
    (tester) async {
      await pumpScreen(tester);
      final opening = walletBalance();

      await enterCode(tester, '204815');
      expect(walletBalance(), opening);

      await tester.tap(find.text('Pay now'));
      await tester.pumpAndSettle();

      // No PIN has been set in this world, so App_Lock cannot confirm anyone.
      // It says so and refuses, and the balance is exactly where it started.
      expect(
        find.text('Set a PIN in your profile before moving money.'),
        findsOneWidget,
      );
      expect(walletBalance(), opening);
    },
  );

  testWidgets('Req 17.8: an unrecognised code says so', (tester) async {
    await pumpScreen(tester);

    await enterCode(tester, '999999');

    expect(find.text(QRScreen.unrecognisedCodeMessage), findsOneWidget);
    // Nothing was resolved, so no confirmation step opened.
    expect(find.text('Confirm payment'), findsNothing);
    expect(find.text('Pay now'), findsNothing);
  });

  testWidgets(
    'Req 17.8: the resolver rejects a payload that is not a payment code',
    (tester) async {
      // The scanned half of requirement 17.8 needs a camera to reach through the
      // widget tree, so the decision it turns on is asserted at its source.
      expect(QRScreen.resolveCode('hello world'), isNull);
      expect(QRScreen.resolveCode('999999'), isNull);
      expect(QRScreen.resolveCode(''), isNull);

      final resolved = QRScreen.resolveCode('frostbank://pay?code=204815');
      expect(resolved, isNotNull);
      expect(resolved!.merchant, 'Solene Bakery');
      expect(resolved.amount, 18.40);
    },
  );

  testWidgets('Req 4.3: the screen renders at a 1.3 text scale with no overflow',
      (tester) async {
    await pumpScreen(tester, textScale: 1.3);
    expect(tester.takeException(), isNull);

    await tester.enterText(amountInput(), '1250.75');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Scan to pay'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Req 4.3: the screen renders at a 1.0 text scale with no overflow',
      (tester) async {
    await pumpScreen(tester);
    await tester.enterText(amountInput(), '1250.75');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
