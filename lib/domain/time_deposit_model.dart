/// Time deposit domain: the record, the term and rate table, the interest
/// maths, the repository contract, and the deterministic seed.
///
/// This library owns its own model rather than living in `models.dart`, the
/// same way `split_bill_model.dart` does, so the feature can be read in one
/// place. It deliberately depends on nothing from the data layer: the account
/// debit, the account credit, and the transaction record all arrive as injected
/// callbacks so the concrete data source stays on the other side of the seam.
library;

// ---------------------------------------------------------------------------
// Mock rate table (Req 6.9)
// ---------------------------------------------------------------------------

/// Rate and policy table for time deposits.
///
/// MOCK DATA. Every annual rate, the minimum principal, and the early
/// withdrawal penalty below are invented figures for this demonstration build.
/// They are not quoted by any bank and no real product is described by them.
abstract final class TimeDepositRates {
  /// The four offered terms with their own annual rate (Req 21.3).
  ///
  /// MOCK DATA, see the class comment.
  static const List<TimeDepositTerm> terms = <TimeDepositTerm>[
    TimeDepositTerm(months: 3, annualRate: 3.25),
    TimeDepositTerm(months: 6, annualRate: 3.85),
    TimeDepositTerm(months: 12, annualRate: 4.40),
    TimeDepositTerm(months: 24, annualRate: 4.75),
  ];

  /// Smallest principal a deposit may be opened with (Req 21.6). MOCK DATA.
  static const double minimumPrincipal = 1000.00;

  /// Share of accrued interest forfeited when a deposit is broken before its
  /// maturity date, expressed as a percentage (Req 21.8). MOCK DATA.
  ///
  /// Named here rather than written at the call site so the policy has exactly
  /// one home.
  static const double earlyWithdrawalPenaltyPercent = 50.0;

  /// The sentence every time deposit surface must carry (Req 21.10).
  static const String mockRateStatement =
      'Every rate here is mock data for this demo build.';

  /// Default term used when a form first opens.
  static TimeDepositTerm get defaultTerm => terms[2];

  /// The term matching [months], or null when no such term is offered.
  static TimeDepositTerm? termFor(int months) {
    for (final term in terms) {
      if (term.months == months) return term;
    }
    return null;
  }

  /// Annual rate for [months]. Falls back to the twelve month rate so a bad
  /// call cannot produce a silent zero interest deposit.
  static double rateFor(int months) =>
      termFor(months)?.annualRate ?? defaultTerm.annualRate;
}

/// One offered term: a length in whole months and the annual rate it pays.
class TimeDepositTerm {
  const TimeDepositTerm({required this.months, required this.annualRate});

  final int months;

  /// Annual rate as a percentage, so 4.40 means four point four percent.
  final double annualRate;

  /// Human label, for example `12 months`.
  String get label => '$months months';

  /// Rate label, for example `4.40% per year`.
  String get rateLabel => '${annualRate.toStringAsFixed(2)}% per year';

  @override
  bool operator ==(Object other) =>
      other is TimeDepositTerm &&
      other.months == months &&
      other.annualRate == annualRate;

  @override
  int get hashCode => Object.hash(months, annualRate);
}

// ---------------------------------------------------------------------------
// Money and date maths
// ---------------------------------------------------------------------------

/// Rounds a monetary figure to two decimals.
double roundMoney(double value) => (value * 100).roundToDouble() / 100;

/// Projected interest at maturity, using plain simple interest.
///
/// The formula, stated once and used everywhere:
///
///     interest = principal * (annualRate / 100) * (termMonths / 12)
///
/// [annualRate] is a percentage, so pass 4.40 for four point four percent.
/// Nothing compounds, and the result is rounded to two decimals because it is
/// money rather than an abstract quantity.
double timeDepositInterest({
  required double principal,
  required double annualRate,
  required int termMonths,
}) {
  if (principal <= 0 || termMonths <= 0) return 0;
  return roundMoney(principal * (annualRate / 100) * (termMonths / 12));
}

/// Interest accrued so far, pro rated across the elapsed share of the term.
///
/// Used only for an early withdrawal quote. A deposit held to maturity always
/// pays [timeDepositInterest] exactly.
double timeDepositAccruedInterest({
  required double principal,
  required double annualRate,
  required int termMonths,
  required DateTime startDate,
  required DateTime maturityDate,
  required DateTime now,
}) {
  final full = timeDepositInterest(
    principal: principal,
    annualRate: annualRate,
    termMonths: termMonths,
  );
  final totalDays = maturityDate.difference(startDate).inDays;
  if (totalDays <= 0) return full;
  final elapsedDays = now.difference(startDate).inDays;
  if (elapsedDays <= 0) return 0;
  if (elapsedDays >= totalDays) return full;
  return roundMoney(full * (elapsedDays / totalDays));
}

/// Maturity date for a deposit opened on [start] over [termMonths] whole
/// months.
///
/// Calendar months rather than a fixed number of days, and the day of month is
/// clamped so a deposit opened on the 31st matures on the last day of a shorter
/// month instead of rolling into the next one.
DateTime timeDepositMaturityDate(DateTime start, int termMonths) {
  final monthIndex = start.month - 1 + termMonths;
  final year = start.year + monthIndex ~/ 12;
  final month = monthIndex % 12 + 1;
  // Day zero of the following month is the last day of this one.
  final lastDayOfMonth = DateTime(year, month + 1, 0).day;
  final day = start.day <= lastDayOfMonth ? start.day : lastDayOfMonth;
  return DateTime(year, month, day, start.hour, start.minute);
}

/// Whole days from [now] until [maturityDate], never below zero.
int timeDepositDaysRemaining(DateTime maturityDate, DateTime now) {
  final days = maturityDate.difference(now).inDays;
  return days < 0 ? 0 : days;
}

// ---------------------------------------------------------------------------
// Records
// ---------------------------------------------------------------------------

enum TimeDepositStatus {
  /// Running, not yet at its maturity date.
  active,

  /// Reached maturity and the principal plus interest has been credited back.
  matured,

  /// Broken before maturity, penalty applied.
  withdrawnEarly,
}

extension TimeDepositStatusLabel on TimeDepositStatus {
  String get label => switch (this) {
    TimeDepositStatus.active => 'Active',
    TimeDepositStatus.matured => 'Matured',
    TimeDepositStatus.withdrawnEarly => 'Withdrawn early',
  };
}

/// One placed time deposit.
class TimeDeposit {
  const TimeDeposit({
    required this.id,
    required this.accountId,
    required this.accountName,
    required this.principal,
    required this.annualRate,
    required this.termMonths,
    required this.startDate,
    required this.maturityDate,
    this.status = TimeDepositStatus.active,
    this.closedAt,
    this.settledAmount,
  });

  final String id;

  /// The account debited on opening and credited at maturity.
  final String accountId;

  /// Display name of that account, so a row can name it without a second read.
  final String accountName;

  final double principal;

  /// Annual rate as a percentage, so 4.40 means four point four percent.
  final double annualRate;

  final int termMonths;
  final DateTime startDate;
  final DateTime maturityDate;
  final TimeDepositStatus status;

  /// When the deposit left the active state, matured or broken.
  final DateTime? closedAt;

  /// What was actually credited back on close, so a matured or broken row can
  /// show the figure that moved rather than recomputing it.
  final double? settledAmount;

  // ---- Computed ----------------------------------------------------------

  /// Interest this deposit pays if it is held to maturity (Req 21.1).
  double get projectedInterest => timeDepositInterest(
    principal: principal,
    annualRate: annualRate,
    termMonths: termMonths,
  );

  /// Principal plus interest at maturity.
  double get valueAtMaturity => roundMoney(principal + projectedInterest);

  bool get isActive => status == TimeDepositStatus.active;

  /// True once [now] has reached or passed the maturity date.
  bool hasReachedMaturity(DateTime now) => !now.isBefore(maturityDate);

  /// Days left to run (Req 21.7). Zero once maturity is reached.
  int daysRemaining(DateTime now) =>
      timeDepositDaysRemaining(maturityDate, now);

  /// Interest earned so far, pro rated across the term.
  double accruedInterest(DateTime now) => timeDepositAccruedInterest(
    principal: principal,
    annualRate: annualRate,
    termMonths: termMonths,
    startDate: startDate,
    maturityDate: maturityDate,
    now: now,
  );

  /// What breaking this deposit today would cost and pay (Req 21.8).
  EarlyWithdrawalQuote earlyWithdrawalQuote(DateTime now) {
    final accrued = accruedInterest(now);
    final penalty = roundMoney(
      accrued * (TimeDepositRates.earlyWithdrawalPenaltyPercent / 100),
    );
    return EarlyWithdrawalQuote(
      depositId: id,
      principal: principal,
      accruedInterest: accrued,
      penalty: penalty,
      penaltyPercent: TimeDepositRates.earlyWithdrawalPenaltyPercent,
      netAmount: roundMoney(principal + accrued - penalty),
      daysRemaining: daysRemaining(now),
    );
  }

  TimeDeposit copyWith({
    String? id,
    String? accountId,
    String? accountName,
    double? principal,
    double? annualRate,
    int? termMonths,
    DateTime? startDate,
    DateTime? maturityDate,
    TimeDepositStatus? status,
    DateTime? closedAt,
    double? settledAmount,
  }) => TimeDeposit(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    accountName: accountName ?? this.accountName,
    principal: principal ?? this.principal,
    annualRate: annualRate ?? this.annualRate,
    termMonths: termMonths ?? this.termMonths,
    startDate: startDate ?? this.startDate,
    maturityDate: maturityDate ?? this.maturityDate,
    status: status ?? this.status,
    closedAt: closedAt ?? this.closedAt,
    settledAmount: settledAmount ?? this.settledAmount,
  );
}

/// The figures a user is shown before confirming an early withdrawal.
///
/// Built by [TimeDeposit.earlyWithdrawalQuote] and rendered before the
/// repository is asked to do anything, which is what Req 21.8 requires.
class EarlyWithdrawalQuote {
  const EarlyWithdrawalQuote({
    required this.depositId,
    required this.principal,
    required this.accruedInterest,
    required this.penalty,
    required this.penaltyPercent,
    required this.netAmount,
    required this.daysRemaining,
  });

  final String depositId;
  final double principal;
  final double accruedInterest;

  /// Interest forfeited, in money.
  final double penalty;

  /// The policy percentage the penalty came from.
  final double penaltyPercent;

  /// What the account actually receives.
  final double netAmount;

  final int daysRemaining;
}

/// A deposit that has reached maturity and been credited back.
///
/// INTEGRATION HOOK (Req 21.9). The repository credits the linked account and
/// records one of these. The notification record is not created here, because
/// the notifications feature lives outside this library. Drain the list with
/// [TimeDepositRepository.drainMaturityEvents] or subscribe with
/// [TimeDepositRepository.onMatured] and write the notification there.
class MaturityEvent {
  const MaturityEvent({
    required this.deposit,
    required this.accountId,
    required this.principal,
    required this.interest,
    required this.creditedAmount,
    required this.maturedAt,
  });

  final TimeDeposit deposit;
  final String accountId;
  final double principal;
  final double interest;

  /// Principal plus interest, the figure added to the account.
  final double creditedAmount;

  final DateTime maturedAt;

  /// Ready made notification copy, so the integration is a one liner.
  String get title => 'Time deposit matured';

  String get body =>
      'Your ${deposit.termMonths} month deposit matured. '
      '${creditedAmount.toStringAsFixed(2)} was added to '
      '${deposit.accountName}.';
}

// ---------------------------------------------------------------------------
// Injected side effects
// ---------------------------------------------------------------------------

/// Reduces [accountId] by [amount] (Req 21.5).
///
/// Bind to `MockDataSource.deductAccountBalance`.
typedef AccountDebit = Future<void> Function(String accountId, double amount);

/// Increases [accountId] by [amount] (Req 21.9).
///
/// `MockDataSource` has no credit method, so bind this to
/// `deductAccountBalance` with a negated amount.
typedef AccountCredit = Future<void> Function(String accountId, double amount);

/// Records one transaction in the shared ledger (Req 21.5).
///
/// Primitive parameters only, so this library never imports the data layer.
/// Bind to `MockDataSource.addTransaction` by constructing a `Txn` in the
/// adapter.
typedef TxnRecorder =
    void Function({
      required String id,
      required String accountId,
      required double amount,
      required String merchant,
      required String category,
      required bool inflow,
      required DateTime date,
      required String reference,
      String? note,
    });

/// Called once for every deposit that reaches maturity (Req 21.9).
typedef MaturityListener = void Function(MaturityEvent event);

// ---------------------------------------------------------------------------
// Repository contract
// ---------------------------------------------------------------------------

abstract interface class TimeDepositRepository {
  /// Every deposit, newest first. Settles anything that has reached maturity
  /// before returning, so the list is never stale with respect to the clock.
  Future<List<TimeDeposit>> fetchTimeDeposits();

  /// Total principal currently placed across active deposits (Req 21.2).
  Future<double> fetchTotalPrincipal();

  /// Opens a deposit: debits the source account, creates the record, and
  /// records a transaction (Req 21.5).
  ///
  /// Throws [TimeDepositFailure] when [principal] is under
  /// [TimeDepositRates.minimumPrincipal] or the term is not offered.
  Future<TimeDeposit> openTimeDeposit({
    required double principal,
    required int termMonths,
    String? accountId,
  });

  /// Quote for breaking [depositId] now, with no side effect (Req 21.8).
  Future<EarlyWithdrawalQuote> quoteEarlyWithdrawal(String depositId);

  /// Breaks [depositId], crediting the net amount and recording a transaction.
  Future<TimeDeposit> withdrawEarly(String depositId);

  /// Credits principal plus interest for every deposit that has reached its
  /// maturity date and records a [MaturityEvent] for each (Req 21.9).
  Future<List<MaturityEvent>> settleMaturedDeposits();

  /// Maturity events recorded since the last drain, then clears them.
  ///
  /// INTEGRATION HOOK: call this from the notification layer, or set
  /// [onMatured], to create the notification record Req 21.9 asks for.
  List<MaturityEvent> drainMaturityEvents();

  /// Fired for each maturity as it is settled. Left null by this library.
  MaturityListener? onMatured;
}

/// Domain level failure for the time deposit flows.
class TimeDepositFailure implements Exception {
  const TimeDepositFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

// ---------------------------------------------------------------------------
// Seed (Req 6.3)
// ---------------------------------------------------------------------------

/// Deterministic seed deposits.
///
/// MOCK DATA. [now] is a parameter rather than a call to `DateTime.now`, so a
/// test can pin the clock and get the same days remaining every run.
///
/// One deposit has most of its term still to run and one is a few days from
/// maturity, which gives the screen both an early withdrawal case and a
/// nearly matured case without any setup.
abstract final class TimeDepositSeed {
  static const String defaultAccountId = 'acc_wallet';
  static const String defaultAccountName = 'Main Wallet';

  static List<TimeDeposit> deposits(DateTime now) {
    final longStart = now.subtract(const Duration(days: 90));
    final shortStart = now.subtract(const Duration(days: 88));
    return <TimeDeposit>[
      TimeDeposit(
        id: 'td_seed_1',
        accountId: defaultAccountId,
        accountName: defaultAccountName,
        principal: 5000.00,
        annualRate: TimeDepositRates.rateFor(12),
        termMonths: 12,
        startDate: longStart,
        maturityDate: timeDepositMaturityDate(longStart, 12),
      ),
      TimeDeposit(
        id: 'td_seed_2',
        accountId: defaultAccountId,
        accountName: defaultAccountName,
        principal: 2500.00,
        annualRate: TimeDepositRates.rateFor(3),
        termMonths: 3,
        startDate: shortStart,
        maturityDate: timeDepositMaturityDate(shortStart, 3),
      ),
    ];
  }
}
