/// Domain models. Plain immutable value types with no data source knowledge.
library;

enum AccountKind { wallet, savings, crypto }

extension AccountKindLabel on AccountKind {
  String get label => switch (this) {
    AccountKind.wallet => 'Wallet',
    AccountKind.savings => 'Savings account',
    AccountKind.crypto => 'Crypto wallet',
  };
}

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.shortCode,
    required this.kind,
    required this.maskedNumber,
    required this.currencyCode,
    required this.totalBalance,
    required this.availableBalance,
    this.cryptoQuantity,
    this.cryptoUnit,
  });

  final String id;
  final String name;

  /// Chip label, for example `WALLET` or `BTC`.
  final String shortCode;
  final AccountKind kind;
  final String maskedNumber;
  final String currencyCode;
  final double totalBalance;
  final double availableBalance;
  final double? cryptoQuantity;
  final String? cryptoUnit;

  bool get isCrypto => kind == AccountKind.crypto;
}

enum CardNetwork { visa, mastercard }

extension CardNetworkLabel on CardNetwork {
  String get label => switch (this) {
    CardNetwork.visa => 'Visa',
    CardNetwork.mastercard => 'Mastercard',
  };
}

enum CardStatus { active, frozen }

extension CardStatusLabel on CardStatus {
  String get label => switch (this) {
    CardStatus.active => 'Active',
    CardStatus.frozen => 'Frozen',
  };
}

/// How the card settles. Printed on the card face, the way a real card carries
/// its scheme product name.
enum CardKind { debit, credit }

extension CardKindLabel on CardKind {
  String get label => switch (this) {
    CardKind.debit => 'Debit',
    CardKind.credit => 'Credit',
  };
}

class BankCard {
  const BankCard({
    required this.id,
    required this.accountId,
    required this.label,
    required this.holderName,
    required this.number,
    required this.cvc,
    required this.expiry,
    required this.network,
    required this.kind,
    required this.status,
    required this.balance,
    required this.currencyCode,
    required this.spendingLimit,
  });

  final String id;
  final String accountId;
  final String label;
  final String holderName;

  /// Full digits, grouped in fours. Only the last group is shown until the
  /// holder asks to reveal it.
  final String number;

  /// Three or four digit security code.
  final String cvc;
  final String expiry;
  final CardNetwork network;
  final CardKind kind;
  final CardStatus status;
  final double balance;
  final String currencyCode;
  final double spendingLimit;

  /// Last four digits, or the whole thing padded when there are fewer than
  /// four.
  ///
  /// Tolerant on purpose. This build is a user interface presentation and the
  /// card form takes whatever is typed, so a short or non numeric entry has to
  /// render rather than throw.
  String get last4 {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '0000';
    if (digits.length <= 4) return digits.padLeft(4, '0');
    return digits.substring(digits.length - 4);
  }

  String get maskedNumber => '\u2022\u2022\u2022\u2022 \u2022\u2022\u2022\u2022 \u2022\u2022\u2022\u2022 $last4';

  BankCard copyWith({
    String? id,
    String? accountId,
    String? label,
    String? holderName,
    String? number,
    String? cvc,
    String? expiry,
    CardNetwork? network,
    CardKind? kind,
    CardStatus? status,
    double? balance,
    String? currencyCode,
    double? spendingLimit,
  }) {
    return BankCard(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      label: label ?? this.label,
      holderName: holderName ?? this.holderName,
      number: number ?? this.number,
      cvc: cvc ?? this.cvc,
      expiry: expiry ?? this.expiry,
      network: network ?? this.network,
      kind: kind ?? this.kind,
      status: status ?? this.status,
      balance: balance ?? this.balance,
      currencyCode: currencyCode ?? this.currencyCode,
      spendingLimit: spendingLimit ?? this.spendingLimit,
    );
  }
}

enum TxnType { deposit, transfer, qrPayment, cardPurchase }

extension TxnTypeLabel on TxnType {
  String get label => switch (this) {
    TxnType.deposit => 'Deposit',
    TxnType.transfer => 'Transfer',
    TxnType.qrPayment => 'QR payment',
    TxnType.cardPurchase => 'Card purchase',
  };
}

enum TxnStatus { completed, pending, failed }

extension TxnStatusLabel on TxnStatus {
  String get label => switch (this) {
    TxnStatus.completed => 'Completed',
    TxnStatus.pending => 'Pending',
    TxnStatus.failed => 'Failed',
  };
}

enum TxnDirection { inflow, outflow }

class Txn {
  const Txn({
    required this.id,
    required this.accountId,
    required this.merchant,
    required this.category,
    required this.amount,
    required this.currencyCode,
    required this.direction,
    required this.type,
    required this.status,
    required this.date,
    required this.reference,
    this.note,
  });

  final String id;
  final String accountId;
  final String merchant;
  final String category;

  /// Always positive. [direction] carries the sign.
  final double amount;
  final String currencyCode;
  final TxnDirection direction;
  final TxnType type;
  final TxnStatus status;
  final DateTime date;
  final String reference;
  final String? note;

  bool get isInflow => direction == TxnDirection.inflow;

  double get signedAmount => isInflow ? amount : -amount;

  String get monogram {
    final parts = merchant
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

/// A crypto pair the application tracks.
///
/// [symbol] is the Twelve Data instrument identifier, [code] is what the holder
/// calls it, and [name] is the display name. Held quantities live on the ledger,
/// not here: this is the instrument, not the position.
class CryptoAsset {
  const CryptoAsset({
    required this.code,
    required this.name,
    required this.quote,
  });

  final String code;
  final String name;

  /// Quote currency, for example `USD`.
  final String quote;

  /// Twelve Data symbol, for example `BTC/USD`.
  String get symbol => '$code/$quote';
}

/// Live quote for one pair. Every field here comes from the market, so nothing
/// on this type is mock data.
class CryptoQuote {
  const CryptoQuote({
    required this.symbol,
    required this.code,
    required this.name,
    required this.exchange,
    required this.price,
    required this.open,
    required this.dayHigh,
    required this.dayLow,
    required this.previousClose,
    required this.change,
    required this.percentChange,
    required this.asOf,
    this.rolling1dChangePercent,
    this.yearLow,
    this.yearHigh,
  });

  final String symbol;
  final String code;
  final String name;
  final String exchange;

  /// Latest traded price.
  final double price;

  final double open;
  final double dayHigh;
  final double dayLow;
  final double previousClose;

  /// Absolute move against [previousClose].
  final double change;

  final double percentChange;

  /// When the venue last published this quote.
  final DateTime asOf;

  final double? rolling1dChangePercent;
  final double? yearLow;
  final double? yearHigh;

  bool get isUp => change >= 0;

  /// Where the price sits inside the session range, from 0 to 1. Null when the
  /// range has no width, which happens on a flat or freshly opened session.
  double? get positionInDayRange {
    final span = dayHigh - dayLow;
    if (span <= 0) return null;
    return ((price - dayLow) / span).clamp(0.0, 1.0);
  }
}

/// One open, high, low, close bar.
class CryptoCandle {
  const CryptoCandle({
    required this.at,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });

  final DateTime at;
  final double open;
  final double high;
  final double low;
  final double close;

  bool get isUp => close >= open;
}

/// Spans offered by the chart. Each one maps to a Twelve Data interval and a
/// number of bars, chosen so a span costs exactly one API credit.
enum ChartRange { today, week, month, threeMonths, sixMonths, year }

extension ChartRangeQuery on ChartRange {
  String get label => switch (this) {
    ChartRange.today => 'Today',
    ChartRange.week => '1W',
    ChartRange.month => '1M',
    ChartRange.threeMonths => '3M',
    ChartRange.sixMonths => '6M',
    ChartRange.year => '1Y',
  };

  /// Spoken form, because the short labels do not read aloud well.
  String get spokenLabel => switch (this) {
    ChartRange.today => 'Today',
    ChartRange.week => 'One week',
    ChartRange.month => 'One month',
    ChartRange.threeMonths => 'Three months',
    ChartRange.sixMonths => 'Six months',
    ChartRange.year => 'One year',
  };

  String get interval => switch (this) {
    ChartRange.today => '15min',
    ChartRange.week => '2h',
    ChartRange.month => '8h',
    ChartRange.threeMonths => '1day',
    ChartRange.sixMonths => '1day',
    ChartRange.year => '1week',
  };

  int get bars => switch (this) {
    ChartRange.today => 96,
    ChartRange.week => 84,
    ChartRange.month => 90,
    ChartRange.threeMonths => 90,
    ChartRange.sixMonths => 180,
    ChartRange.year => 52,
  };

  /// True when the axis should read as a clock rather than a calendar.
  bool get isIntraday => switch (this) {
    ChartRange.today => true,
    _ => false,
  };
}

/// Bars for one pair over one span, oldest first.
class CryptoSeries {
  const CryptoSeries({
    required this.symbol,
    required this.range,
    required this.candles,
  });

  final String symbol;
  final ChartRange range;

  /// Oldest first, so the chart can walk it left to right.
  final List<CryptoCandle> candles;

  bool get isEmpty => candles.isEmpty;

  double get low =>
      candles.map((candle) => candle.low).reduce((a, b) => a < b ? a : b);

  double get high =>
      candles.map((candle) => candle.high).reduce((a, b) => a > b ? a : b);

  double get first => candles.first.open;

  double get last => candles.last.close;

  double get change => last - first;

  double get percentChange => first == 0 ? 0 : (change / first) * 100;

  bool get isUp => change >= 0;

  /// Aggregates the bars down to at most [target] buckets, so a wide span still
  /// draws as readable candles on a narrow screen. Open comes from the first bar
  /// in the bucket, close from the last, and the extremes from the whole bucket,
  /// which is how a lower resolution bar is built.
  CryptoSeries downsampled(int target) {
    if (target <= 0 || candles.length <= target) return this;

    final bucketSize = (candles.length / target).ceil();
    final merged = <CryptoCandle>[];

    for (var start = 0; start < candles.length; start += bucketSize) {
      final end = (start + bucketSize).clamp(0, candles.length);
      final bucket = candles.sublist(start, end);
      merged.add(
        CryptoCandle(
          at: bucket.first.at,
          open: bucket.first.open,
          close: bucket.last.close,
          high: bucket
              .map((candle) => candle.high)
              .reduce((a, b) => a > b ? a : b),
          low: bucket
              .map((candle) => candle.low)
              .reduce((a, b) => a < b ? a : b),
        ),
      );
    }

    return CryptoSeries(symbol: symbol, range: range, candles: merged);
  }
}

/// A live quote paired with the ledger position in that pair.
class CryptoPosition {
  const CryptoPosition({required this.quote, required this.quantity});

  final CryptoQuote quote;

  /// Units held. Comes from the ledger, so this is mock data in this build.
  final double quantity;

  bool get isHeld => quantity > 0;

  double get value => quantity * quote.price;

  /// Move in the value of the position over the session.
  double get valueChange => quantity * quote.change;
}

/// Live valuation of the held positions.
///
/// The quantities are ledger data and the prices are live, so the total is a
/// real valuation of a seeded position.
class CryptoPortfolio {
  const CryptoPortfolio({
    required this.value,
    required this.change,
    required this.positions,
  });

  factory CryptoPortfolio.of(List<CryptoPosition> positions) {
    var value = 0.0;
    var change = 0.0;
    for (final position in positions) {
      if (!position.isHeld) continue;
      value += position.value;
      change += position.valueChange;
    }
    return CryptoPortfolio(
      value: value,
      change: change,
      positions: positions,
    );
  }

  final double value;
  final double change;
  final List<CryptoPosition> positions;

  List<CryptoPosition> get held =>
      positions.where((position) => position.isHeld).toList();

  List<CryptoPosition> get watchlist =>
      positions.where((position) => !position.isHeld).toList();

  /// Value before today's move, used to express [change] as a percentage.
  double get openingValue => value - change;

  double get percentChange =>
      openingValue == 0 ? 0 : (change / openingValue) * 100;

  bool get isUp => change >= 0;

  /// Most recent quote timestamp across the tracked pairs.
  DateTime? get asOf {
    DateTime? latest;
    for (final position in positions) {
      final at = position.quote.asOf;
      if (latest == null || at.isAfter(latest)) latest = at;
    }
    return latest;
  }
}

class Promo {
  const Promo({
    required this.id,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.accentIndex,
  });

  final String id;
  final String title;
  final String body;
  final String actionLabel;

  /// Selects which brand gradient the card uses.
  final int accentIndex;
}

// ---------------------------------------------------------------------------
// Goal Saves
// ---------------------------------------------------------------------------

enum GoalSaveStatus { active, closed }

extension GoalSaveStatusLabel on GoalSaveStatus {
  String get label => switch (this) {
    GoalSaveStatus.active => 'Active',
    GoalSaveStatus.closed => 'Closed',
  };
}

/// A named savings pocket the user opens inside their Savings account.
///
/// Interest accrues daily at [dailyRatePercent] on the current [balance].
class GoalSave {
  const GoalSave({
    required this.id,
    required this.name,
    required this.emoji,
    required this.targetAmount,
    required this.balance,
    required this.currencyCode,
    required this.dailyRatePercent,
    required this.interestEarned,
    required this.createdAt,
    required this.status,
  });

  final String id;

  /// User-defined goal name, e.g. "Europe Trip".
  final String name;

  /// Single emoji picked when the goal was opened, e.g. "✈️".
  final String emoji;

  /// Optional savings target. Zero means no explicit target.
  final double targetAmount;

  final double balance;
  final String currencyCode;

  /// Daily interest rate as a percentage, e.g. 0.011918 for ~4.35% APY.
  final double dailyRatePercent;

  /// Cumulative interest credited to this goal since it was opened.
  final double interestEarned;

  final DateTime createdAt;
  final GoalSaveStatus status;

  bool get hasTarget => targetAmount > 0;

  /// Progress toward the target. Clamped to [0, 1]. Returns 0 if no target.
  double get progress =>
      hasTarget ? (balance / targetAmount).clamp(0.0, 1.0) : 0.0;

  /// Amount that would be earned today based on the current balance.
  double get dailyInterestAmount => balance * (dailyRatePercent / 100);

  /// Annual Percentage Yield inferred from the daily rate: (1 + d/100)^365 − 1.
  double get apy =>
      (1 + dailyRatePercent / 100) * 365 - 1; // simple approximation

  GoalSave copyWith({
    double? balance,
    double? interestEarned,
    GoalSaveStatus? status,
    String? name,
    String? emoji,
    double? targetAmount,
  }) => GoalSave(
    id: id,
    name: name ?? this.name,
    emoji: emoji ?? this.emoji,
    targetAmount: targetAmount ?? this.targetAmount,
    balance: balance ?? this.balance,
    currencyCode: currencyCode,
    dailyRatePercent: dailyRatePercent,
    interestEarned: interestEarned ?? this.interestEarned,
    createdAt: createdAt,
    status: status ?? this.status,
  );
}

// ---------------------------------------------------------------------------
// Goal Save Transactions
// ---------------------------------------------------------------------------

enum GoalTxnKind { transferIn, transferOut, interest }

extension GoalTxnKindLabel on GoalTxnKind {
  String get label => switch (this) {
    GoalTxnKind.transferIn => 'Added funds',
    GoalTxnKind.transferOut => 'Withdrawn',
    GoalTxnKind.interest => 'Interest earned',
  };

  bool get isCredit =>
      this == GoalTxnKind.transferIn || this == GoalTxnKind.interest;
}

/// An entry in a goal save's transaction history.
class GoalTxn {
  const GoalTxn({
    required this.id,
    required this.goalId,
    required this.kind,
    required this.amount,
    required this.runningBalance,
    required this.date,
    this.note,
  });

  final String id;
  final String goalId;
  final GoalTxnKind kind;

  /// Always positive.
  final double amount;
  final double runningBalance;
  final DateTime date;
  final String? note;
}

/// The signed in customer.
///
/// This type deliberately carries no PIN. The App_Lock PIN is held by `PinVault`
/// as a salted digest, because requirement 5.9 forbids a credential value in the
/// source and a PIN on this model would be written to disk in the clear by the
/// data set snapshot.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.mobile,
    required this.memberSince,
  });

  final String id;
  final String fullName;
  final String email;
  final String mobile;
  final DateTime memberSince;

  UserProfile copyWith({
    String? fullName,
    String? email,
    String? mobile,
  }) => UserProfile(
    id: id,
    fullName: fullName ?? this.fullName,
    email: email ?? this.email,
    mobile: mobile ?? this.mobile,
    memberSince: memberSince,
  );

  String get initials {
    final parts = fullName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String get maskedEmail {
    final at = email.indexOf('@');
    if (at <= 1) return email;
    final visible = email.substring(0, 2);
    return '$visible${'\u2022' * (at - 2)}${email.substring(at)}';
  }

  String get maskedMobile {
    final digits = mobile.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 4) return mobile;
    final tail = digits.substring(digits.length - 4);
    return '\u2022\u2022\u2022 \u2022\u2022\u2022 $tail';
  }
}
