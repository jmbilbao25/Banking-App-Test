/// In memory [TimeDepositRepository] plus the Riverpod providers the Time
/// Deposit screen reads.
///
/// The providers live here only because `state/providers.dart` is shared and
/// owned elsewhere. They are meant to be lifted into that file during
/// integration, unchanged.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/time_deposit_model.dart';
import '../state/providers.dart' show noAutomaticRetry;

/// Holds every deposit in memory and performs the account and ledger writes
/// through the callbacks it was given.
///
/// Nothing here reaches for `MockDataSource`. The three side effects it needs,
/// a debit, a credit, and a transaction record, arrive as constructor
/// arguments, so this class is fully testable with spies and the real wiring is
/// a one line adapter each.
class MockTimeDepositRepository implements TimeDepositRepository {
  MockTimeDepositRepository({
    required DateTime now,
    List<TimeDeposit>? seed,
    this.debitAccount,
    this.creditAccount,
    this.recordTransaction,
    this.onMatured,
    this.latency = Duration.zero,
    this.defaultAccountId = TimeDepositSeed.defaultAccountId,
    this.defaultAccountName = TimeDepositSeed.defaultAccountName,
  }) : _now = now,
       _deposits = List<TimeDeposit>.of(seed ?? TimeDepositSeed.deposits(now));

  /// The clock. A parameter rather than `DateTime.now`, so days remaining and
  /// maturity settlement are deterministic in a test.
  DateTime _now;

  /// Moves the clock forward, which is how a test reaches a maturity date.
  void setNow(DateTime value) => _now = value;

  DateTime get now => _now;

  final List<TimeDeposit> _deposits;
  final List<MaturityEvent> _pendingMaturityEvents = <MaturityEvent>[];

  /// Bind to `MockDataSource.deductAccountBalance` (Req 21.5).
  final AccountDebit? debitAccount;

  /// Bind to `MockDataSource.deductAccountBalance` with a negated amount, since
  /// that method clamps at zero and has no credit twin (Req 21.9).
  final AccountCredit? creditAccount;

  /// Bind to `MockDataSource.addTransaction` (Req 21.5).
  final TxnRecorder? recordTransaction;

  /// INTEGRATION HOOK for the notification record (Req 21.9).
  @override
  MaturityListener? onMatured;

  final Duration latency;
  final String defaultAccountId;
  final String defaultAccountName;

  int _sequence = 0;

  Future<void> _wait() => latency == Duration.zero
      ? Future<void>.value()
      : Future<void>.delayed(latency);

  // ---- Reads --------------------------------------------------------------

  @override
  Future<List<TimeDeposit>> fetchTimeDeposits() async {
    await _wait();
    // Settle first, so a deposit whose maturity date has passed is never shown
    // as still running.
    await settleMaturedDeposits();
    final rows = List<TimeDeposit>.of(_deposits)
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    return List<TimeDeposit>.unmodifiable(rows);
  }

  @override
  Future<double> fetchTotalPrincipal() async {
    await _wait();
    await settleMaturedDeposits();
    return roundMoney(
      _deposits
          .where((deposit) => deposit.isActive)
          .fold<double>(0, (sum, deposit) => sum + deposit.principal),
    );
  }

  @override
  Future<EarlyWithdrawalQuote> quoteEarlyWithdrawal(String depositId) async {
    await _wait();
    return _require(depositId).earlyWithdrawalQuote(_now);
  }

  // ---- Writes -------------------------------------------------------------

  @override
  Future<TimeDeposit> openTimeDeposit({
    required double principal,
    required int termMonths,
    String? accountId,
  }) async {
    if (principal < TimeDepositRates.minimumPrincipal) {
      throw TimeDepositFailure(
        'The smallest time deposit is '
        '${TimeDepositRates.minimumPrincipal.toStringAsFixed(2)}.',
      );
    }
    final term = TimeDepositRates.termFor(termMonths);
    if (term == null) {
      throw const TimeDepositFailure('That term is not offered.');
    }

    await _wait();

    final source = accountId ?? defaultAccountId;
    final rounded = roundMoney(principal);
    final start = _now;
    final deposit = TimeDeposit(
      id: 'td_${++_sequence}_${start.millisecondsSinceEpoch}',
      accountId: source,
      accountName: defaultAccountName,
      principal: rounded,
      annualRate: term.annualRate,
      termMonths: term.months,
      startDate: start,
      maturityDate: timeDepositMaturityDate(start, term.months),
    );

    // Req 21.5, in order: reduce the source balance, create the record, create
    // the transaction.
    await debitAccount?.call(source, rounded);
    _deposits.insert(0, deposit);
    recordTransaction?.call(
      id: 'txn_${deposit.id}_open',
      accountId: source,
      amount: rounded,
      merchant: 'Time Deposit',
      category: 'Savings',
      inflow: false,
      date: start,
      reference: deposit.id,
      note: '${term.months} month term at ${term.rateLabel}',
    );

    return deposit;
  }

  @override
  Future<TimeDeposit> withdrawEarly(String depositId) async {
    final existing = _require(depositId);
    if (!existing.isActive) {
      throw const TimeDepositFailure('That deposit is already closed.');
    }
    await _wait();

    final quote = existing.earlyWithdrawalQuote(_now);
    final closed = existing.copyWith(
      status: TimeDepositStatus.withdrawnEarly,
      closedAt: _now,
      settledAmount: quote.netAmount,
    );
    _replace(closed);

    await creditAccount?.call(existing.accountId, quote.netAmount);
    recordTransaction?.call(
      id: 'txn_${existing.id}_early',
      accountId: existing.accountId,
      amount: quote.netAmount,
      merchant: 'Time Deposit withdrawal',
      category: 'Savings',
      inflow: true,
      date: _now,
      reference: existing.id,
      note:
          'Early withdrawal, penalty '
          '${quote.penalty.toStringAsFixed(2)}',
    );

    return closed;
  }

  @override
  Future<List<MaturityEvent>> settleMaturedDeposits() async {
    final settled = <MaturityEvent>[];
    for (final deposit in List<TimeDeposit>.of(_deposits)) {
      if (!deposit.isActive) continue;
      if (!deposit.hasReachedMaturity(_now)) continue;

      final interest = deposit.projectedInterest;
      final credited = roundMoney(deposit.principal + interest);
      _replace(
        deposit.copyWith(
          status: TimeDepositStatus.matured,
          closedAt: deposit.maturityDate,
          settledAmount: credited,
        ),
      );

      // Req 21.9: the linked account gains principal plus interest.
      await creditAccount?.call(deposit.accountId, credited);
      recordTransaction?.call(
        id: 'txn_${deposit.id}_matured',
        accountId: deposit.accountId,
        amount: credited,
        merchant: 'Time Deposit maturity',
        category: 'Savings',
        inflow: true,
        date: deposit.maturityDate,
        reference: deposit.id,
        note: 'Principal plus interest',
      );

      final event = MaturityEvent(
        deposit: deposit,
        accountId: deposit.accountId,
        principal: deposit.principal,
        interest: interest,
        creditedAmount: credited,
        maturedAt: deposit.maturityDate,
      );
      settled.add(event);
      _pendingMaturityEvents.add(event);
      // Req 21.9, second half: the notification record is created by whoever
      // owns the notification repository, through this hook.
      onMatured?.call(event);
    }
    return settled;
  }

  @override
  List<MaturityEvent> drainMaturityEvents() {
    final drained = List<MaturityEvent>.unmodifiable(_pendingMaturityEvents);
    _pendingMaturityEvents.clear();
    return drained;
  }

  // ---- Internals ----------------------------------------------------------

  TimeDeposit _require(String id) {
    for (final deposit in _deposits) {
      if (deposit.id == id) return deposit;
    }
    throw const TimeDepositFailure('That deposit is no longer available.');
  }

  void _replace(TimeDeposit deposit) {
    final index = _deposits.indexWhere((row) => row.id == deposit.id);
    if (index != -1) _deposits[index] = deposit;
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------
//
// INTEGRATION: move these four declarations into `lib/state/providers.dart`
// verbatim and delete them from here. Bind the three callbacks on
// `timeDepositRepositoryProvider` to `MockDataSource` at that point.

/// The repository the screen reads. Overridden wholesale in tests.
final timeDepositRepositoryProvider = Provider<TimeDepositRepository>(
  (ref) => MockTimeDepositRepository(now: DateTime.now()),
);

/// The clock the screen uses for days remaining, so a test can pin it.
final timeDepositClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Every deposit, newest first (Req 21.1).
final timeDepositsProvider = FutureProvider<List<TimeDeposit>>(
  (ref) => ref.watch(timeDepositRepositoryProvider).fetchTimeDeposits(),
  retry: noAutomaticRetry,
);

/// Total principal placed across active deposits (Req 21.2).
final timeDepositTotalPrincipalProvider = FutureProvider<double>(
  (ref) => ref.watch(timeDepositRepositoryProvider).fetchTotalPrincipal(),
  retry: noAutomaticRetry,
);
