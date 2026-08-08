import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_bank_app/core/design/theme.dart';
import 'package:mobile_bank_app/core/persistence/persistence_store.dart';
import 'package:mobile_bank_app/data/mock_data_source.dart';
import 'package:mobile_bank_app/presentation/screens/transfer_screen.dart';
import 'package:mobile_bank_app/presentation/widgets/money_form.dart';
import 'package:mobile_bank_app/state/providers.dart';

/// Send money, after the rebuild onto the shared money form vocabulary.
///
/// The focus here is the rule requirements 16.4, 16.6 and 16.7 state three times:
/// the next step is *kept disabled*, rather than being live and complaining when
/// pressed. That is also what keeps this screen consistent with Add money, which
/// disables its own action on the same condition.
Widget _harness({double textScale = 1}) => ProviderScope(
  retry: noAutomaticRetry,
  overrides: [
    persistenceStoreProvider.overrideWithValue(InMemoryPersistenceStore()),
    mockDataSourceProvider.overrideWithValue(
      MockDataSource(now: DateTime(2026, 8, 5))
        ..latencyOverride = (() => Duration.zero),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    builder: (context, child) => MediaQuery.withClampedTextScaling(
      minScaleFactor: textScale,
      maxScaleFactor: textScale,
      child: child!,
    ),
    home: const TransferScreen(),
  ),
);

void _tallViewport(WidgetTester tester, {double height = 2400}) {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = Size(430, height);
  addTearDown(tester.view.reset);
}

Finder get _review =>
    find.descendant(of: find.byType(PrimaryAction), matching: find.byType(FilledButton));

bool _reviewEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_review.first).onPressed != null;

Finder get _recipientField =>
    find.descendant(of: find.byType(SheetField), matching: find.byType(TextField));

Finder get _amountField =>
    find.descendant(of: find.byType(AmountField), matching: find.byType(TextField));

Future<void> _fill(
  WidgetTester tester, {
  String? recipient,
  String? amount,
}) async {
  if (recipient != null) {
    await tester.enterText(_recipientField.first, recipient);
  }
  if (amount != null) {
    await tester.enterText(_amountField, amount);
  }
  await tester.pump();
}

void main() {
  testWidgets('Req 16.4: an empty recipient keeps the next step disabled', (
    tester,
  ) async {
    _tallViewport(tester);
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(_reviewEnabled(tester), isFalse);

    await _fill(tester, amount: '40.00');
    expect(
      _reviewEnabled(tester),
      isFalse,
      reason: 'an amount alone is not enough to review',
    );

    await _fill(tester, recipient: 'Ana Reyes');
    expect(_reviewEnabled(tester), isTrue);
  });

  testWidgets('Req 16.7: a zero amount keeps the next step disabled', (
    tester,
  ) async {
    _tallViewport(tester);
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await _fill(tester, recipient: 'Ana Reyes', amount: '0');
    expect(_reviewEnabled(tester), isFalse);

    await _fill(tester, amount: '0.00');
    expect(_reviewEnabled(tester), isFalse);

    await _fill(tester, amount: '0.01');
    expect(_reviewEnabled(tester), isTrue);
  });

  testWidgets(
    'Req 16.6: an amount over the available balance keeps the step disabled '
    'and says why',
    (tester) async {
      _tallViewport(tester);
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      // The seeded wallet holds 12,106.20 available.
      await _fill(tester, recipient: 'Ana Reyes', amount: '99999.00');

      expect(_reviewEnabled(tester), isFalse);
      expect(
        find.textContaining('more than your available balance'),
        findsOneWidget,
        reason: 'Req 16.6 asks for an inline message as well as a dead control',
      );

      await _fill(tester, amount: '40.00');
      expect(_reviewEnabled(tester), isTrue);
      expect(find.textContaining('more than your available balance'), findsNothing);
    },
  );

  testWidgets(
    'Req 16.1 and 16.8: the review states recipient, source, amount, fee and '
    'total before anything moves',
    (tester) async {
      _tallViewport(tester);
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      await _fill(tester, recipient: 'Ana Reyes', amount: '40.00');
      await tester.tap(_review.first);
      await tester.pumpAndSettle();

      expect(find.text('Review'), findsOneWidget);
      expect(find.text('To'), findsOneWidget);
      expect(find.text('Ana Reyes'), findsOneWidget);
      expect(find.text('From'), findsOneWidget);
      expect(find.text('Everyday Wallet'), findsWidgets);
      expect(find.text('Amount'), findsOneWidget);
      expect(find.text('Fee'), findsOneWidget);
      expect(find.text('Total to debit'), findsOneWidget);
      // The confirm control is the one that moves money, and it is gated. The
      // screen title carries the same words, so the control is found as a button.
      expect(
        find.widgetWithText(FilledButton, 'Send money'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Req 16.13: leaving the review returns to the editable details', (
    tester,
  ) async {
    _tallViewport(tester);
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await _fill(tester, recipient: 'Ana Reyes', amount: '40.00');
    await tester.tap(_review.first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit details'));
    await tester.pumpAndSettle();

    expect(find.text('Send to'), findsOneWidget);
    expect(
      _reviewEnabled(tester),
      isTrue,
      reason: 'the entered values survive the trip back',
    );
  });

  testWidgets('Req 16.9: no money moves until App_Lock confirms', (
    tester,
  ) async {
    _tallViewport(tester);
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await _fill(tester, recipient: 'Ana Reyes', amount: '40.00');
    await tester.tap(_review.first);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Send money'));
    await tester.pumpAndSettle();

    // No PIN is set in this world, so App_Lock cannot confirm anyone and the
    // transfer is refused before the repository is reached.
    expect(
      find.text('Set a PIN in your profile before moving money.'),
      findsOneWidget,
    );
  });

  testWidgets('Req 4.3: the form renders at a 1.3 text scale', (tester) async {
    _tallViewport(tester, height: 3000);
    await tester.pumpWidget(_harness(textScale: 1.3));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Send to'), findsOneWidget);
  });
}
