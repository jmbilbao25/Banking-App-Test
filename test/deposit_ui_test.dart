// Tests for Requirement 17, the Deposit flow, rebuilt on the shared money form
// vocabulary. Each test is named after the criterion it covers.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_bank_app/core/design/theme.dart';
import 'package:mobile_bank_app/core/persistence/persistence_store.dart';
import 'package:mobile_bank_app/data/mock_data_source.dart';
import 'package:mobile_bank_app/data/mock_repositories.dart';
import 'package:mobile_bank_app/domain/models.dart';
import 'package:mobile_bank_app/domain/repositories.dart';
import 'package:mobile_bank_app/presentation/screens/deposit_screen.dart';
import 'package:mobile_bank_app/presentation/widgets/money_form.dart';
import 'package:mobile_bank_app/presentation/widgets/states.dart';
import 'package:mobile_bank_app/state/providers.dart';

MockDataSource _instantSource() =>
    MockDataSource(now: DateTime(2026, 8, 5))
      ..latencyOverride = (() => Duration.zero);

/// Wraps the real repository so a test can observe the deposit call, or fail it,
/// without touching production code.
class _SpyAccountRepository implements AccountRepository {
  _SpyAccountRepository(this.inner, {this.failWith});

  final AccountRepository inner;

  /// Thrown instead of delegating, so the failure path can be exercised.
  final Object? failWith;

  final List<({String accountId, double amount})> deposits = [];

  @override
  Future<List<Account>> fetchAccounts() => inner.fetchAccounts();

  @override
  Future<Account> fetchAccount(String id) => inner.fetchAccount(id);

  @override
  Future<Account> deposit({
    required String accountId,
    required double amount,
  }) async {
    deposits.add((accountId: accountId, amount: amount));
    if (failWith != null) throw failWith!;
    return inner.deposit(accountId: accountId, amount: amount);
  }

  @override
  Future<Account> transfer({
    required String fromAccountId,
    required String recipient,
    required double amount,
    String? note,
  }) => inner.transfer(
    fromAccountId: fromAccountId,
    recipient: recipient,
    amount: amount,
    note: note,
  );
}

Widget _harness({
  MockDataSource? source,
  AccountRepository? repository,
  double textScale = 1,
}) => ProviderScope(
  retry: noAutomaticRetry,
  overrides: [
    persistenceStoreProvider.overrideWithValue(InMemoryPersistenceStore()),
    mockDataSourceProvider.overrideWithValue(source ?? _instantSource()),
    if (repository != null)
      accountRepositoryProvider.overrideWithValue(repository),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    builder: (context, child) => MediaQuery.withClampedTextScaling(
      minScaleFactor: textScale,
      maxScaleFactor: textScale,
      child: child!,
    ),
    home: const DepositScreen(),
  ),
);

/// A viewport tall enough that the whole form is laid out and tappable.
void _tallViewport(WidgetTester tester, {double height = 2200}) {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = Size(430, height);
  addTearDown(tester.view.reset);
}

Finder get _confirmButton => find.descendant(
  of: find.byType(PrimaryAction),
  matching: find.byType(FilledButton),
);

bool _confirmIsEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_confirmButton.first).onPressed != null;

Finder _tickIn(String sourceId) => find.descendant(
  of: find.byKey(ValueKey(sourceId)),
  matching: find.byIcon(Icons.check_circle_rounded),
);

Finder _rowLabel(String sourceId, String text) => find.descendant(
  of: find.byKey(ValueKey(sourceId)),
  matching: find.text(text),
);

/// Reads the seeded world outside the fake clock.
///
/// [MockDataSource] awaits a latency timer even when that latency is zero, and a
/// timer inside `testWidgets` only fires when the test pumps, so a plain await
/// here would hang rather than fail.
Future<List<Account>> _accounts(WidgetTester tester, MockDataSource source) async =>
    await tester.runAsync(source.accounts) ?? const <Account>[];

/// Advances past a submission without `pumpAndSettle`.
///
/// A completed deposit leaves the confirm control busy until the route is popped,
/// and a busy [PrimaryAction] spins a [CircularProgressIndicator], which never
/// settles. Fixed pumps step over the repository latency and the bottom sheet
/// transition instead.
Future<void> _pumpSubmission(WidgetTester tester) async {
  await tester.pump();
  for (var step = 0; step < 4; step++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  testWidgets(
    'Req 17.1: the form collects a destination account, a funding source and '
    'an amount',
    (tester) async {
      _tallViewport(tester);
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      // Destination account.
      expect(find.byType(AccountSelectField), findsOneWidget);
      expect(find.text('Deposit into'), findsOneWidget);
      expect(find.text('Everyday Wallet'), findsWidgets);

      // Funding source: three named mock instruments, each with a masked
      // identifier, all on screen at once rather than behind a dropdown.
      expect(find.text('Funding source'), findsOneWidget);
      expect(_rowLabel('src_linked_bank', 'Linked bank account'), findsOneWidget);
      expect(_rowLabel('src_debit_card', 'Debit card'), findsOneWidget);
      expect(_rowLabel('src_cash_agent', 'Cash agent'), findsOneWidget);
      expect(
        _rowLabel('src_linked_bank', '\u2022\u2022\u2022\u2022 8842'),
        findsOneWidget,
      );
      expect(
        _rowLabel('src_cash_agent', 'Agent 20713'),
        findsOneWidget,
      );

      // Amount.
      expect(find.byType(AmountField), findsOneWidget);
      expect(find.text('Amount'), findsOneWidget);
    },
  );

  testWidgets(
    'Req 6.9: the funding sources are labelled as mock data',
    (tester) async {
      _tallViewport(tester);
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(
        find.text('Funding sources in this build are mock data.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Req 17.3: the confirm control is disabled at an empty, zero or negative '
    'amount and enabled once the amount is positive',
    (tester) async {
      _tallViewport(tester);
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      // Empty.
      expect(_confirmIsEnabled(tester), isFalse);

      // Zero, in both the bare and the decimal spelling.
      await tester.enterText(find.byType(AmountField), '0');
      await tester.pump();
      expect(_confirmIsEnabled(tester), isFalse);

      await tester.enterText(find.byType(AmountField), '0.00');
      await tester.pump();
      expect(_confirmIsEnabled(tester), isFalse);

      // Negative. The shared AmountField refuses the sign, so the field cannot
      // hold a negative figure and the control stays disabled either way.
      await tester.enterText(find.byType(AmountField), '-25');
      await tester.pump();
      expect(_confirmIsEnabled(tester), isFalse);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isNot('-25'),
      );

      // Positive.
      await tester.enterText(find.byType(AmountField), '250.00');
      await tester.pump();
      expect(_confirmIsEnabled(tester), isTrue);

      // Cleared again.
      await tester.enterText(find.byType(AmountField), '');
      await tester.pump();
      expect(_confirmIsEnabled(tester), isFalse);
    },
  );

  testWidgets(
    'Req 17.1: choosing a funding source moves the selection visibly',
    (tester) async {
      _tallViewport(tester);
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      // The first source is selected on entry, so the choice is never empty.
      expect(_tickIn('src_linked_bank'), findsOneWidget);
      expect(_tickIn('src_cash_agent'), findsNothing);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      await tester.tap(_rowLabel('src_cash_agent', 'Cash agent'));
      await tester.pumpAndSettle();

      expect(_tickIn('src_cash_agent'), findsOneWidget);
      expect(_tickIn('src_linked_bank'), findsNothing);
      // Exactly one source is ever selected.
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    },
  );

  testWidgets(
    'Req 17.2: confirming calls the repository and increases the destination '
    'balance',
    (tester) async {
      _tallViewport(tester);
      final source = _instantSource();
      final repository = _SpyAccountRepository(MockAccountRepository(source));

      final before = (await _accounts(tester, source)).first;
      expect(before.id, 'acc_wallet');

      await tester.pumpWidget(
        _harness(source: source, repository: repository),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(AmountField), '250.00');
      await tester.pump();
      await tester.tap(_confirmButton.first);
      await _pumpSubmission(tester);

      // Requirement 17.2, first half: the repository performed the credit.
      expect(repository.deposits, hasLength(1));
      expect(repository.deposits.single.accountId, 'acc_wallet');
      expect(repository.deposits.single.amount, closeTo(250, 0.001));

      // Second half: the balance rose and a Deposit transaction was recorded.
      final after = (await _accounts(tester, source)).firstWhere(
        (account) => account.id == 'acc_wallet',
      );
      expect(after.availableBalance, closeTo(before.availableBalance + 250, 0.001));
      expect(after.totalBalance, closeTo(before.totalBalance + 250, 0.001));

      final ledger = await tester.runAsync(source.transactions) ?? <Txn>[];
      final credits = ledger.where(
        (txn) => txn.accountId == 'acc_wallet' && txn.type == TxnType.deposit,
      );
      expect(credits, isNotEmpty);
      expect(credits.first.direction, TxnDirection.inflow);

      // The shared outcome sheet reports it rather than a hand rolled dialog.
      expect(find.byType(MoneyOutcomeSheet), findsOneWidget);
      expect(find.text('Money added'), findsOneWidget);
    },
  );

  testWidgets(
    'Req 17.2: a repository failure shows an inline message that states no '
    'money moved and never names an exception',
    (tester) async {
      _tallViewport(tester);
      final source = _instantSource();
      final repository = _SpyAccountRepository(
        MockAccountRepository(source),
        failWith: Exception('mock transport failure'),
      );

      final before = (await _accounts(tester, source)).first;

      await tester.pumpWidget(
        _harness(source: source, repository: repository),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(AmountField), '250.00');
      await tester.pump();
      await tester.tap(_confirmButton.first);
      await _pumpSubmission(tester);

      expect(find.byType(InlineFormError), findsOneWidget);
      expect(find.byType(MoneyOutcomeSheet), findsNothing);

      final message = tester
          .widget<InlineFormError>(find.byType(InlineFormError))
          .message;
      expect(message, contains('did not go through'));
      expect(message, contains('No money moved'));
      expect(message.toLowerCase(), isNot(contains('exception')));

      // And the failure really did leave the balance alone.
      final after = (await _accounts(tester, source)).first;
      expect(after.availableBalance, before.availableBalance);
    },
  );

  testWidgets(
    'Req 3.1: the shape matched skeleton appears before the fields',
    (tester) async {
      _tallViewport(tester);
      await tester.pumpWidget(_harness());

      expect(find.byType(SkeletonBlock), findsWidgets);
      expect(find.byType(AccountSelectField), findsNothing);
      expect(find.byType(AmountField), findsNothing);

      await tester.pumpAndSettle();

      expect(find.byType(SkeletonBlock), findsNothing);
      expect(find.byType(AccountSelectField), findsOneWidget);
      expect(find.byType(AmountField), findsOneWidget);
    },
  );

  testWidgets(
    'Req 3.4: a failed accounts read shows an inline retry rather than an '
    'empty screen',
    (tester) async {
      _tallViewport(tester);
      await tester.pumpWidget(
        ProviderScope(
          retry: noAutomaticRetry,
          overrides: [
            persistenceStoreProvider.overrideWithValue(
              InMemoryPersistenceStore(),
            ),
            accountsProvider.overrideWith(
              (ref) => Future<List<Account>>.error(
                const RepositoryFailure('We could not load your accounts.'),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const DepositScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ErrorStateView), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.byType(AmountField), findsNothing);
    },
  );

  testWidgets(
    'Req 4.3: the screen renders at a 1.3 text scale with no overflow',
    (tester) async {
      _tallViewport(tester, height: 2800);
      await tester.pumpWidget(_harness(textScale: 1.3));
      await tester.pumpAndSettle();

      expect(find.byType(AmountField), findsOneWidget);
      expect(find.text('Linked bank account'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Req 4.2: every funding source row meets the minimum tap target',
    (tester) async {
      _tallViewport(tester);
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      for (final id in const [
        'src_linked_bank',
        'src_debit_card',
        'src_cash_agent',
      ]) {
        final size = tester.getSize(find.byKey(ValueKey(id)));
        expect(size.height, greaterThanOrEqualTo(48));
      }
    },
  );

  testWidgets(
    'Req 3.7: the confirm control shows a busy indicator and rejects a second '
    'activation while a deposit is in flight',
    (tester) async {
      _tallViewport(tester);
      final source = MockDataSource(now: DateTime(2026, 8, 5))
        ..latencyOverride = (() => const Duration(milliseconds: 400));
      final repository = _SpyAccountRepository(MockAccountRepository(source));

      await tester.pumpWidget(
        _harness(source: source, repository: repository),
      );
      await tester.pumpAndSettle();

      final restingWidth = tester.getSize(_confirmButton.first).width;

      await tester.enterText(find.byType(AmountField), '100.00');
      await tester.pump();
      await tester.tap(_confirmButton.first);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.getSize(_confirmButton.first).width, restingWidth);
      expect(_confirmIsEnabled(tester), isFalse);

      // A second tap while busy must not queue a second deposit.
      await tester.tap(_confirmButton.first, warnIfMissed: false);
      await _pumpSubmission(tester);

      expect(repository.deposits, hasLength(1));
    },
  );

  testWidgets(
    'Req 3.3: no accounts shows an empty state with a single action',
    (tester) async {
      _tallViewport(tester);
      await tester.pumpWidget(
        ProviderScope(
          retry: noAutomaticRetry,
          overrides: [
            persistenceStoreProvider.overrideWithValue(
              InMemoryPersistenceStore(),
            ),
            accountsProvider.overrideWith((ref) async => const <Account>[]),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const DepositScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EmptyStateView), findsOneWidget);
      expect(find.text('No account to deposit into'), findsOneWidget);
      expect(find.text('Go back'), findsOneWidget);
      expect(find.byType(AmountField), findsNothing);
    },
  );
}
