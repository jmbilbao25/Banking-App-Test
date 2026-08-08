import '../domain/models.dart';

/// JSON codecs for the domain models held in the mock data set.
///
/// The domain models stay plain immutable value types with no data source
/// knowledge, so the encode and decode pair lives here instead. Keys are
/// snake_case to match the column names the Supabase mappers already use, which
/// keeps one wire format across both stores.
///
/// Every decoder is tolerant. A snapshot written by an older build, or one that
/// lost a field, must not stop the application from launching, so unknown enum
/// names fall back to a default and absent numbers fall back to zero.
abstract final class ModelCodecs {
  // -- primitives -----------------------------------------------------------

  static double _double(Object? value, [double fallback = 0]) => switch (value) {
    final num n => n.toDouble(),
    final String s => double.tryParse(s) ?? fallback,
    _ => fallback,
  };

  static double? _doubleOrNull(Object? value) => switch (value) {
    final num n => n.toDouble(),
    final String s => double.tryParse(s),
    _ => null,
  };

  static int _int(Object? value, [int fallback = 0]) => switch (value) {
    final num n => n.toInt(),
    final String s => int.tryParse(s) ?? fallback,
    _ => fallback,
  };

  static String _string(Object? value, [String fallback = '']) =>
      value is String ? value : fallback;

  static DateTime _date(Object? value, DateTime fallback) {
    if (value is String) return DateTime.tryParse(value) ?? fallback;
    return fallback;
  }

  /// Resolves an enum by its [Enum.name], falling back rather than throwing.
  static T _enum<T extends Enum>(List<T> values, Object? raw, T fallback) {
    if (raw is! String) return fallback;
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return fallback;
  }

  // -- Account --------------------------------------------------------------

  static Map<String, Object?> accountToMap(Account account) => {
    'id': account.id,
    'name': account.name,
    'short_code': account.shortCode,
    'kind': account.kind.name,
    'masked_number': account.maskedNumber,
    'currency_code': account.currencyCode,
    'total_balance': account.totalBalance,
    'available_balance': account.availableBalance,
    'crypto_quantity': account.cryptoQuantity,
    'crypto_unit': account.cryptoUnit,
  };

  static Account accountFromMap(Map<String, Object?> map) => Account(
    id: _string(map['id']),
    name: _string(map['name']),
    shortCode: _string(map['short_code']),
    kind: _enum(AccountKind.values, map['kind'], AccountKind.wallet),
    maskedNumber: _string(map['masked_number']),
    currencyCode: _string(map['currency_code'], 'USD'),
    totalBalance: _double(map['total_balance']),
    availableBalance: _double(map['available_balance']),
    cryptoQuantity: _doubleOrNull(map['crypto_quantity']),
    cryptoUnit: map['crypto_unit'] as String?,
  );

  // -- BankCard -------------------------------------------------------------

  static Map<String, Object?> cardToMap(BankCard card) => {
    'id': card.id,
    'account_id': card.accountId,
    'label': card.label,
    'holder_name': card.holderName,
    'number': card.number,
    'cvc': card.cvc,
    'expiry': card.expiry,
    'network': card.network.name,
    'kind': card.kind.name,
    'status': card.status.name,
    'balance': card.balance,
    'currency_code': card.currencyCode,
    'spending_limit': card.spendingLimit,
  };

  static BankCard cardFromMap(Map<String, Object?> map) => BankCard(
    id: _string(map['id']),
    accountId: _string(map['account_id']),
    label: _string(map['label']),
    holderName: _string(map['holder_name']),
    number: _string(map['number']),
    cvc: _string(map['cvc']),
    expiry: _string(map['expiry']),
    network: _enum(CardNetwork.values, map['network'], CardNetwork.visa),
    kind: _enum(CardKind.values, map['kind'], CardKind.debit),
    status: _enum(CardStatus.values, map['status'], CardStatus.active),
    balance: _double(map['balance']),
    currencyCode: _string(map['currency_code'], 'USD'),
    spendingLimit: _double(map['spending_limit']),
  );

  // -- Txn ------------------------------------------------------------------

  static Map<String, Object?> txnToMap(Txn txn) => {
    'id': txn.id,
    'account_id': txn.accountId,
    'merchant': txn.merchant,
    'category': txn.category,
    'amount': txn.amount,
    'currency_code': txn.currencyCode,
    'direction': txn.direction.name,
    'type': txn.type.name,
    'status': txn.status.name,
    'date': txn.date.toIso8601String(),
    'reference': txn.reference,
    'note': txn.note,
  };

  static Txn txnFromMap(Map<String, Object?> map, {required DateTime now}) => Txn(
    id: _string(map['id']),
    accountId: _string(map['account_id']),
    merchant: _string(map['merchant']),
    category: _string(map['category']),
    amount: _double(map['amount']),
    currencyCode: _string(map['currency_code'], 'USD'),
    direction: _enum(
      TxnDirection.values,
      map['direction'],
      TxnDirection.outflow,
    ),
    type: _enum(TxnType.values, map['type'], TxnType.cardPurchase),
    status: _enum(TxnStatus.values, map['status'], TxnStatus.completed),
    date: _date(map['date'], now),
    reference: _string(map['reference']),
    note: map['note'] as String?,
  );

  // -- UserProfile ----------------------------------------------------------

  /// The PIN is deliberately absent. It lives in `PinVault` as a salted digest,
  /// because requirement 5.9 forbids a credential value in the source or, by
  /// extension, in a plaintext blob on disk.
  static Map<String, Object?> profileToMap(UserProfile profile) => {
    'id': profile.id,
    'full_name': profile.fullName,
    'email': profile.email,
    'mobile': profile.mobile,
    'member_since': profile.memberSince.toIso8601String(),
  };

  static UserProfile profileFromMap(
    Map<String, Object?> map, {
    required DateTime now,
  }) => UserProfile(
    id: _string(map['id']),
    fullName: _string(map['full_name']),
    email: _string(map['email']),
    mobile: _string(map['mobile']),
    memberSince: _date(map['member_since'], now),
  );

  // -- GoalSave -------------------------------------------------------------

  static Map<String, Object?> goalToMap(GoalSave goal) => {
    'id': goal.id,
    'name': goal.name,
    'emoji': goal.emoji,
    'target_amount': goal.targetAmount,
    'balance': goal.balance,
    'currency_code': goal.currencyCode,
    'daily_rate_percent': goal.dailyRatePercent,
    'interest_earned': goal.interestEarned,
    'created_at': goal.createdAt.toIso8601String(),
    'status': goal.status.name,
  };

  static GoalSave goalFromMap(
    Map<String, Object?> map, {
    required DateTime now,
  }) => GoalSave(
    id: _string(map['id']),
    name: _string(map['name']),
    emoji: _string(map['emoji'], 'savings'),
    targetAmount: _double(map['target_amount']),
    balance: _double(map['balance']),
    currencyCode: _string(map['currency_code'], 'USD'),
    dailyRatePercent: _double(map['daily_rate_percent']),
    interestEarned: _double(map['interest_earned']),
    createdAt: _date(map['created_at'], now),
    status: _enum(GoalSaveStatus.values, map['status'], GoalSaveStatus.active),
  );

  // -- GoalTxn --------------------------------------------------------------

  static Map<String, Object?> goalTxnToMap(GoalTxn txn) => {
    'id': txn.id,
    'goal_id': txn.goalId,
    'kind': txn.kind.name,
    'amount': txn.amount,
    'running_balance': txn.runningBalance,
    'date': txn.date.toIso8601String(),
    'note': txn.note,
  };

  static GoalTxn goalTxnFromMap(
    Map<String, Object?> map, {
    required DateTime now,
  }) => GoalTxn(
    id: _string(map['id']),
    goalId: _string(map['goal_id']),
    kind: _enum(GoalTxnKind.values, map['kind'], GoalTxnKind.transferIn),
    amount: _double(map['amount']),
    runningBalance: _double(map['running_balance']),
    date: _date(map['date'], now),
    note: map['note'] as String?,
  );

  // -- list helpers ---------------------------------------------------------

  static List<Map<String, Object?>> encodeList<T>(
    Iterable<T> items,
    Map<String, Object?> Function(T) encode,
  ) => items.map(encode).toList(growable: false);

  static List<T> decodeList<T>(
    Object? raw,
    T Function(Map<String, Object?>) decode,
  ) {
    if (raw is! List) return const [];
    final out = <T>[];
    for (final entry in raw) {
      if (entry is Map<String, Object?>) {
        out.add(decode(entry));
      }
    }
    return out;
  }

  /// Reads an int that older snapshots may not carry.
  static int intOr(Object? value, int fallback) => _int(value, fallback);
}
