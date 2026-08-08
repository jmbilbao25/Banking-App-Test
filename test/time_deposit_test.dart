// Tests for Requirement 21, Finance Hub Time Deposit.
//
// Every test names the criterion it covers. The clock is pinned everywhere, so
// days remaining and maturity settlement are the same on every run.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_bank_app/core/design/theme.dart';
import 'package:mobile_bank_app/core/design/typography.dart';
import 'package:mobile_bank_app/core/format/dates.dart';
import 'package:mobile_bank_app/core/format/money.dart';
import 'package:mobile_bank_app/data/mock_time_deposit_repository.dart';
import 'package:mobile_bank_app/domain/time_deposit_model.dart';
import 'package:mobile_bank_app/presentation/screens/open_time_deposit_sheet.dart';
import 'package:mobile_bank_app/presentation/screens/time_deposit_screen.dart';
import 'package:mobile_bank_app/presentation/widgets/pressable.dart';
import 'package:mobile_bank_app/presentation/widgets/states.dart';
import 'package:mobile_bank_app/state/providers.dart';

/// The pinned clock for every test in this file.
final DateTime kNow = DateTime(2026, 3, 1);

// ---------------------------------------------------------------------------
// Spies for the injected side effects (Req 21.5, Req 21.9)
// ---------------------------------------------------------------------------

class _RecordedTxn {
  _RecordedTxn({
    required this.id,
    required this.accountId,
    required this.amount,
    required this.merchant,
    required this.category,
    required this.inflow,
    required this.date,
    required this.reference,
    this.note,
  });

  final String id;
  final String accountId;
  final double amount;
  final String merchant;
  final String category;
  final bool inflow;
  final DateTime date;
  final String reference;
  final String? note;
}

class _LedgerSpy {
  final List<MapEntry<String, double>> debits = [];
  final List<MapEntry<String, double>> credits = [];
  final List<_RecordedTxn> txns = [];
  final List<MaturityEvent> maturities = [];

  Future<void> debit(String accountId, double amount) async =>
      debits.add(MapEntry(accountId, amount));

  Future<void> credit(String accountId, double amount) async =>
      credits.add(MapEntry(accountId, amount));

  void record({
    required String id,
    required String accountId,
    required double amount,
    required String merchant,
    required String category,
    required bool inflow,
    required DateTime date,
    required String reference,
    String? note,
  }) => txns.add(
    _RecordedTxn(
      id: id,
      accountId: accountId,
      amount: amount,
      merchant: merchant,
      category: category,
      inflow: inflow,
      date: date,
      reference: reference,
      note: note,
    ),
  );
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

/// 5000 principal, 4.40% for 12 months. Interest at maturity is exactly 220.00.
/// Runs from 1 Jun 2025 to 1 Jun 2026, so 92 days remain at [kNow].
TimeDeposit get _twelveMonthDeposit => TimeDeposit(
  id: 'td_a',
  accountId: 'acc_wallet',
  accountName: 'Main Wallet',
  principal: 5000.00,
  annualRate: 4.40,
  termMonths: 12,
  startDate: DateTime(2025, 6, 1),
  maturityDate: timeDepositMaturityDate(DateTime(2025, 6, 1), 12),
);

/// 2000 principal, 3.25% for 3 months. Interest at maturity is exactly 16.25.
/// Matures 31 Mar 2026, so 30 days remain at [kNow].
TimeDeposit get _threeMonthDeposit => TimeDeposit(
  id: 'td_b',
  accountId: 'acc_wallet',
  accountName: 'Main Wallet',
  principal: 2000.00,
  annualRate: 3.25,
  termMonths: 3,
  startDate: DateTime(2025, 12, 31),
  maturityDate: timeDepositMaturityDate(DateTime(2025, 12, 31), 3),
);

MockTimeDepositRepository _repository({
  required List<TimeDeposit> seed,
  _LedgerSpy? spy,
  DateTime? now,
}) {
  final ledger = spy ?? _LedgerSpy();
  return MockTimeDepositRepository(
    now: now ?? kNow,
    seed: seed,
    debitAccount: ledger.debit,
    creditAccount: ledger.credit,
    recordTransaction: ledger.record,
  );
}

Widget _harness(Widget child, {required TimeDepositRepository repository}) =>
    ProviderScope(
      retry: noAutomaticRetry,
      overrides: [
        timeDepositRepositoryProvider.overrideWithValue(repository),
        timeDepositClockProvider.overrideWithValue(() => kNow),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Material(child: child),
      ),
    );

/// Pumps the screen on a tall surface, so every card in the list is laid out
/// rather than lazily skipped below the fold.
Future<void> _pumpScreen(
  WidgetTester tester, {
  required TimeDepositRepository repository,
}) async {
  tester.view.physicalSize = const Size(600, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _harness(const TimeDepositScreen(), repository: repository),
  );
  await tester.pumpAndSettle();
}

/// Opens the create flow through the section header action.
Future<void> _openCreateFlow(WidgetTester tester) async {
  await tester.tap(find.text('New deposit'));
  await tester.pumpAndSettle();
}

void main() {
  // -------------------------------------------------------------------------
  // Pure maths
  // -------------------------------------------------------------------------

  group('interest and maturity maths', () {
    test(
      'Req 21: simple interest is principal times rate over the term, rounded '
      'to two decimals',
      () {
        // 1000 at 4.40% for 12 months.
        expect(
          timeDepositInterest(
            principal: 1000,
            annualRate: 4.40,
            termMonths: 12,
          ),
          44.00,
        );
        // 5000 at 4.40% for 12 months.
        expect(
          timeDepositInterest(
            principal: 5000,
            annualRate: 4.40,
            termMonths: 12,
          ),
          220.00,
        );
        // 2500 at 3.25% for 3 months is 20.3125, rounded to 20.31.
        expect(
          timeDepositInterest(principal: 2500, annualRate: 3.25, termMonths: 3),
          20.31,
        );
        // 10000 at 4.75% for 24 months is twice the annual figure.
        expect(
          timeDepositInterest(
            principal: 10000,
            annualRate: 4.75,
            termMonths: 24,
          ),
          950.00,
        );
        // Degenerate inputs pay nothing rather than throwing.
        expect(
          timeDepositInterest(principal: 0, annualRate: 4.40, termMonths: 12),
          0,
        );
        expect(
          timeDepositInterest(principal: 5000, annualRate: 4.40, termMonths: 0),
          0,
        );
      },
    );

    test('Req 21: maturity date advances whole calendar months', () {
      expect(
        timeDepositMaturityDate(DateTime(2026, 3, 1), 3),
        DateTime(2026, 6, 1),
      );
      expect(
        timeDepositMaturityDate(DateTime(2026, 3, 1), 6),
        DateTime(2026, 9, 1),
      );
      expect(
        timeDepositMaturityDate(DateTime(2026, 3, 1), 12),
        DateTime(2027, 3, 1),
      );
      expect(
        timeDepositMaturityDate(DateTime(2026, 3, 1), 24),
        DateTime(2028, 3, 1),
      );
      // Crossing a year boundary.
      expect(
        timeDepositMaturityDate(DateTime(2025, 11, 15), 3),
        DateTime(2026, 2, 15),
      );
      // The day of month clamps to the last day of a shorter month.
      expect(
        timeDepositMaturityDate(DateTime(2026, 1, 31), 1),
        DateTime(2026, 2, 28),
      );
      expect(
        timeDepositMaturityDate(DateTime(2025, 12, 31), 3),
        DateTime(2026, 3, 31),
      );
    });

    test(
      'Req 21: days remaining counts whole days and never goes negative',
      () {
        expect(timeDepositDaysRemaining(DateTime(2026, 3, 31), kNow), 30);
        expect(timeDepositDaysRemaining(DateTime(2026, 6, 1), kNow), 92);
        expect(timeDepositDaysRemaining(DateTime(2026, 3, 2), kNow), 1);
        expect(timeDepositDaysRemaining(DateTime(2026, 3, 1), kNow), 0);
        expect(timeDepositDaysRemaining(DateTime(2025, 1, 1), kNow), 0);
      },
    );

    test('Req 21.8: the penalty is the mock share of accrued interest, not a '
        'magic number', () {
      // 7300 at 5% for 12 months pays 365.00, so one day is worth 1.00.
      final deposit = TimeDeposit(
        id: 'td_clean',
        accountId: 'acc_wallet',
        accountName: 'Main Wallet',
        principal: 7300.00,
        annualRate: 5.00,
        termMonths: 12,
        startDate: DateTime(2025, 1, 1),
        maturityDate: DateTime(2026, 1, 1),
      );
      expect(deposit.projectedInterest, 365.00);

      // 90 days in.
      final quote = deposit.earlyWithdrawalQuote(DateTime(2025, 4, 1));
      expect(quote.accruedInterest, 90.00);
      expect(
        quote.penaltyPercent,
        TimeDepositRates.earlyWithdrawalPenaltyPercent,
      );
      expect(quote.penalty, 45.00);
      expect(quote.netAmount, 7345.00);
    });
  });

  // -------------------------------------------------------------------------
  // Rate table
  // -------------------------------------------------------------------------

  test('Req 21.3: the mock table offers 3, 6, 12, and 24 months, each with its '
      'own rate', () {
    expect(TimeDepositRates.terms.map((t) => t.months), [3, 6, 12, 24]);
    final rates = TimeDepositRates.terms.map((t) => t.annualRate).toList();
    expect(rates, [3.25, 3.85, 4.40, 4.75]);
    expect(rates.toSet().length, 4, reason: 'every rate must be distinct');
    expect(TimeDepositRates.minimumPrincipal, 1000.00);
  });

  // -------------------------------------------------------------------------
  // Screen rendering
  // -------------------------------------------------------------------------

  testWidgets(
    'Req 21.1: every deposit renders principal, annual rate, term, start date, '
    'maturity date, and projected interest',
    (tester) async {
      await _pumpScreen(
        tester,
        repository: _repository(
          seed: [_twelveMonthDeposit, _threeMonthDeposit],
        ),
      );

      // The six field labels, once per deposit.
      for (final label in [
        'Annual rate',
        'Term',
        'Start date',
        'Maturity date',
        'Interest at maturity',
      ]) {
        expect(find.text(label), findsNWidgets(2), reason: label);
      }

      // Deposit A: 5000 at 4.40% over 12 months, 1 Jun 2025 to 1 Jun 2026.
      expect(find.text(Money.format(5000.00)), findsOneWidget);
      expect(find.text('4.40% per year'), findsOneWidget);
      expect(find.text('12 months'), findsOneWidget);
      expect(find.text(Dates.shortDay(DateTime(2025, 6, 1))), findsOneWidget);
      expect(find.text(Dates.shortDay(DateTime(2026, 6, 1))), findsOneWidget);
      expect(find.text(Money.format(220.00)), findsOneWidget);

      // Deposit B: 2000 at 3.25% over 3 months, 31 Dec 2025 to 31 Mar 2026.
      expect(find.text(Money.format(2000.00)), findsOneWidget);
      expect(find.text('3.25% per year'), findsOneWidget);
      expect(find.text('3 months'), findsOneWidget);
      expect(find.text(Dates.shortDay(DateTime(2025, 12, 31))), findsOneWidget);
      expect(find.text(Dates.shortDay(DateTime(2026, 3, 31))), findsOneWidget);
      expect(find.text(Money.format(16.25)), findsOneWidget);
    },
  );

  testWidgets(
    'Req 21.2: total principal across all deposits renders as one large '
    'GeistMono figure',
    (tester) async {
      await _pumpScreen(
        tester,
        repository: _repository(
          seed: [_twelveMonthDeposit, _threeMonthDeposit],
        ),
      );

      expect(find.text('Total principal placed'), findsOneWidget);

      final figure = find.text(Money.format(7000.00));
      expect(figure, findsOneWidget);

      final style = tester.widget<Text>(figure).style!;
      expect(style.fontFamily, AppType.mono);
      expect(style.fontSize, AppType.numericHero.fontSize);
    },
  );

  testWidgets('Req 21.2: the total tracks only placed principal', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      repository: _repository(seed: [_threeMonthDeposit]),
    );
    expect(find.text(Money.format(2000.00)), findsNWidgets(2));
  });

  testWidgets(
    'Req 21.3: the open flow renders all four terms, each with its own rate',
    (tester) async {
      await _pumpScreen(tester, repository: _repository(seed: []));
      await _openCreateFlow(tester);

      expect(find.byType(OpenTimeDepositSheet), findsOneWidget);
      for (final term in TimeDepositRates.terms) {
        expect(find.text(term.label), findsOneWidget, reason: term.label);
        expect(
          find.text(term.rateLabel),
          findsOneWidget,
          reason: term.rateLabel,
        );
      }
    },
  );

  testWidgets(
    'Req 21.4: entering a principal and selecting a term renders the projected '
    'interest and the maturity date before confirming',
    (tester) async {
      final spy = _LedgerSpy();
      await _pumpScreen(
        tester,
        repository: _repository(seed: [], spy: spy),
      );
      await _openCreateFlow(tester);

      await tester.enterText(find.byType(TextField), '2000');
      await tester.tap(find.text('6 months'));
      await tester.pumpAndSettle();

      // 2000 at 3.85% for 6 months is 38.50.
      expect(find.text('Projected interest'), findsOneWidget);
      expect(find.text(Money.format(38.50)), findsOneWidget);

      // Opened at the pinned clock, so maturity is 1 Sep 2026.
      expect(find.text('Maturity date'), findsOneWidget);
      expect(find.text(Dates.shortDay(DateTime(2026, 9, 1))), findsOneWidget);

      // Total at maturity is shown too.
      expect(find.text(Money.format(2038.50)), findsOneWidget);

      // Nothing has been written yet.
      expect(spy.debits, isEmpty);
      expect(spy.txns, isEmpty);
    },
  );

  testWidgets(
    'Req 21.5: confirming debits the source account, creates the deposit, and '
    'records a transaction',
    (tester) async {
      final spy = _LedgerSpy();
      final repository = _repository(seed: [], spy: spy);
      await _pumpScreen(tester, repository: repository);
      await _openCreateFlow(tester);

      await tester.enterText(find.byType(TextField), '2000');
      await tester.tap(find.text('6 months'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm deposit'));
      await tester.pumpAndSettle();

      // The source account balance was reduced by the principal.
      expect(spy.debits, hasLength(1));
      expect(spy.debits.single.key, 'acc_wallet');
      expect(spy.debits.single.value, 2000.00);

      // A deposit record exists.
      final rows = await repository.fetchTimeDeposits();
      expect(rows, hasLength(1));
      expect(rows.single.principal, 2000.00);
      expect(rows.single.termMonths, 6);
      expect(rows.single.annualRate, 3.85);
      expect(rows.single.startDate, kNow);
      expect(rows.single.maturityDate, DateTime(2026, 9, 1));

      // A transaction record exists, as an outflow of the principal.
      expect(spy.txns, hasLength(1));
      final txn = spy.txns.single;
      expect(txn.accountId, 'acc_wallet');
      expect(txn.amount, 2000.00);
      expect(txn.merchant, 'Time Deposit');
      expect(txn.inflow, isFalse);
      expect(txn.reference, rows.single.id);
    },
  );

  testWidgets(
    'Req 21.6: a principal below the minimum renders that minimum inline and '
    'keeps confirm disabled',
    (tester) async {
      final spy = _LedgerSpy();
      await _pumpScreen(
        tester,
        repository: _repository(seed: [], spy: spy),
      );
      await _openCreateFlow(tester);

      await tester.enterText(find.byType(TextField), '500');
      await tester.pumpAndSettle();

      // The message states the minimum itself.
      expect(
        find.text('The minimum principal is ${Money.format(1000.00)}.'),
        findsOneWidget,
      );

      // Confirm is disabled, and tapping it writes nothing.
      final confirm = find.widgetWithText(FilledButton, 'Confirm deposit');
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(spy.debits, isEmpty);
      expect(spy.txns, isEmpty);

      // Raising it above the minimum clears the message and enables confirm.
      await tester.enterText(find.byType(TextField), '1500');
      await tester.pumpAndSettle();
      expect(
        find.text('The minimum principal is ${Money.format(1000.00)}.'),
        findsNothing,
      );
      expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
    },
  );

  testWidgets(
    'Req 21.7: a deposit that has not reached maturity renders its days '
    'remaining',
    (tester) async {
      await _pumpScreen(
        tester,
        repository: _repository(
          seed: [_twelveMonthDeposit, _threeMonthDeposit],
        ),
      );

      // 1 Mar 2026 to 1 Jun 2026 is 92 days.
      expect(find.text('92 days remaining'), findsOneWidget);
      // 1 Mar 2026 to 31 Mar 2026 is 30 days.
      expect(find.text('30 days remaining'), findsOneWidget);
      expect(find.text('Active'), findsNWidgets(2));
    },
  );

  testWidgets(
    'Req 21.8: withdrawing before maturity renders the penalty and the net '
    'amount for confirmation before the repository acts',
    (tester) async {
      final spy = _LedgerSpy();
      final repository = _repository(seed: [_twelveMonthDeposit], spy: spy);
      await _pumpScreen(tester, repository: repository);

      final quote = _twelveMonthDeposit.earlyWithdrawalQuote(kNow);
      expect(quote.penalty, greaterThan(0));

      await tester.tap(
        find
            .ancestor(
              of: find.text('4.40% per year'),
              matching: find.byType(Pressable),
            )
            .first,
      );
      await tester.pumpAndSettle();

      // The quote is on screen.
      expect(find.byType(EarlyWithdrawalSheet), findsOneWidget);
      expect(
        find.text(
          'Early withdrawal penalty '
          '(${TimeDepositRates.earlyWithdrawalPenaltyPercent.toStringAsFixed(0)}'
          '% of interest)',
        ),
        findsOneWidget,
      );
      expect(find.text(Money.format(quote.penalty)), findsOneWidget);
      expect(find.text('Net amount'), findsOneWidget);
      expect(find.text(Money.format(quote.netAmount)), findsOneWidget);

      // Nothing has happened yet.
      expect(spy.credits, isEmpty);
      expect((await repository.fetchTimeDeposits()).single.isActive, isTrue);

      // Confirming performs the withdrawal.
      await tester.tap(find.text('Withdraw now'));
      await tester.pumpAndSettle();

      expect(spy.credits, hasLength(1));
      expect(spy.credits.single.key, 'acc_wallet');
      expect(spy.credits.single.value, quote.netAmount);

      final closed = (await repository.fetchTimeDeposits()).single;
      expect(closed.status, TimeDepositStatus.withdrawnEarly);
      expect(closed.settledAmount, quote.netAmount);

      expect(spy.txns, hasLength(1));
      expect(spy.txns.single.inflow, isTrue);
      expect(spy.txns.single.amount, quote.netAmount);
    },
  );

  testWidgets(
    'Req 21.8: keeping the deposit closes the sheet and performs no withdrawal',
    (tester) async {
      final spy = _LedgerSpy();
      final repository = _repository(seed: [_twelveMonthDeposit], spy: spy);
      await _pumpScreen(tester, repository: repository);

      await tester.tap(
        find
            .ancestor(
              of: find.text('4.40% per year'),
              matching: find.byType(Pressable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep deposit'));
      await tester.pumpAndSettle();

      expect(find.byType(EarlyWithdrawalSheet), findsNothing);
      expect(spy.credits, isEmpty);
      expect((await repository.fetchTimeDeposits()).single.isActive, isTrue);
    },
  );

  test(
    'Req 21.9: reaching maturity credits principal plus interest and emits a '
    'maturity event',
    () async {
      final spy = _LedgerSpy();
      // 3000 at 4.40% for 12 months pays 132.00, and matured a year ago.
      final matured = TimeDeposit(
        id: 'td_matured',
        accountId: 'acc_wallet',
        accountName: 'Main Wallet',
        principal: 3000.00,
        annualRate: 4.40,
        termMonths: 12,
        startDate: DateTime(2024, 3, 1),
        maturityDate: DateTime(2025, 3, 1),
      );
      final repository = _repository(seed: [matured], spy: spy);
      repository.onMatured = spy.maturities.add;

      final rows = await repository.fetchTimeDeposits();

      // The linked account gained principal plus interest.
      expect(spy.credits, hasLength(1));
      expect(spy.credits.single.key, 'acc_wallet');
      expect(spy.credits.single.value, 3132.00);

      expect(rows.single.status, TimeDepositStatus.matured);
      expect(rows.single.settledAmount, 3132.00);

      // The notification hook fired, and the event is drainable.
      expect(spy.maturities, hasLength(1));
      final drained = repository.drainMaturityEvents();
      expect(drained, hasLength(1));
      expect(drained.single.principal, 3000.00);
      expect(drained.single.interest, 132.00);
      expect(drained.single.creditedAmount, 3132.00);
      expect(drained.single.accountId, 'acc_wallet');
      expect(drained.single.maturedAt, DateTime(2025, 3, 1));

      // Draining twice does not replay the event.
      expect(repository.drainMaturityEvents(), isEmpty);

      // Settling is idempotent, so a second read does not credit again.
      await repository.fetchTimeDeposits();
      expect(spy.credits, hasLength(1));
    },
  );

  testWidgets(
    'Req 21.9: a matured deposit renders as matured with no countdown',
    (tester) async {
      final matured = TimeDeposit(
        id: 'td_matured',
        accountId: 'acc_wallet',
        accountName: 'Main Wallet',
        principal: 3000.00,
        annualRate: 4.40,
        termMonths: 12,
        startDate: DateTime(2024, 3, 1),
        maturityDate: DateTime(2025, 3, 1),
      );
      await _pumpScreen(tester, repository: _repository(seed: [matured]));

      expect(find.text('Matured'), findsOneWidget);
      expect(find.textContaining('days remaining'), findsNothing);
    },
  );

  testWidgets('Req 21.10: the screen states that every rate is mock data', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      repository: _repository(seed: [_twelveMonthDeposit]),
    );

    expect(
      TimeDepositRates.mockRateStatement,
      'Every rate here is mock data for this demo build.',
    );
    expect(find.text(TimeDepositRates.mockRateStatement), findsWidgets);
    expect(
      find.textContaining('Minimum principal ${Money.format(1000.00)}'),
      findsOneWidget,
    );

    // The open flow repeats the statement.
    await _openCreateFlow(tester);
    expect(find.text(TimeDepositRates.mockRateStatement), findsWidgets);
  });

  // -------------------------------------------------------------------------
  // Async surface (Req 3.1, 3.3, 3.4)
  // -------------------------------------------------------------------------

  testWidgets(
    'Req 3.3: the list shows a shape matched skeleton while loading',
    (tester) async {
      tester.view.physicalSize = const Size(600, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _harness(
          const TimeDepositScreen(),
          repository: MockTimeDepositRepository(
            now: kNow,
            seed: [_twelveMonthDeposit],
            latency: const Duration(milliseconds: 200),
          ),
        ),
      );

      expect(find.byType(SkeletonBlock), findsWidgets);

      await tester.pumpAndSettle();

      expect(find.byType(SkeletonBlock), findsNothing);
      expect(find.text('4.40% per year'), findsOneWidget);
    },
  );

  testWidgets(
    'Req 3.4: an empty list offers a heading, a sentence, and one action that '
    'opens the create flow',
    (tester) async {
      await _pumpScreen(tester, repository: _repository(seed: []));

      expect(find.byType(EmptyStateView), findsOneWidget);
      expect(find.text('No time deposits yet'), findsOneWidget);
      expect(find.text('New deposit'), findsWidgets);

      await tester.tap(find.text('New deposit').last);
      await tester.pumpAndSettle();
      expect(find.byType(OpenTimeDepositSheet), findsOneWidget);
    },
  );

  // -------------------------------------------------------------------------
  // Accessibility (Req 4.1, 4.2, 4.3)
  // -------------------------------------------------------------------------

  testWidgets('Req 4.3: nothing clips or overflows at text scale 1.3', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        retry: noAutomaticRetry,
        overrides: [
          timeDepositRepositoryProvider.overrideWithValue(
            _repository(seed: [_twelveMonthDeposit, _threeMonthDeposit]),
          ),
          timeDepositClockProvider.overrideWithValue(() => kNow),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery.withClampedTextScaling(
            minScaleFactor: 1.3,
            maxScaleFactor: 1.3,
            child: child!,
          ),
          home: const Material(child: TimeDepositScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('4.40% per year'), findsOneWidget);
    expect(find.text('92 days remaining'), findsOneWidget);
  });

  testWidgets('Req 4.1, 4.2: a deposit row is a labelled 48 pixel target', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      repository: _repository(seed: [_twelveMonthDeposit]),
    );

    final row = find
        .ancestor(
          of: find.text('4.40% per year'),
          matching: find.byType(Pressable),
        )
        .first;
    final pressable = tester.widget<Pressable>(row);
    expect(pressable.semanticLabel, isNotNull);
    expect(pressable.semanticLabel, contains('12 month time deposit'));
    expect(pressable.semanticLabel, contains('92 days remaining'));
    expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
  });

  // -------------------------------------------------------------------------
  // Seed (Req 6.3)
  // -------------------------------------------------------------------------

  test('Req 6.3: the seed places two deposits, one of them near maturity', () {
    final seeded = TimeDepositSeed.deposits(kNow);
    expect(seeded, hasLength(2));
    expect(seeded.every((d) => d.isActive), isTrue);
    expect(seeded.every((d) => d.principal >= 1000), isTrue);

    final running = seeded.first.daysRemaining(kNow);
    final nearMaturity = seeded.last.daysRemaining(kNow);
    expect(running, greaterThan(200));
    expect(nearMaturity, lessThan(10));
    expect(nearMaturity, greaterThan(0));
  });
}
