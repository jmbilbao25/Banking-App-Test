import '../domain/models.dart';

/// Seeded content for the offline build.
///
/// Every monetary figure, rate, balance, and identifier in this file is mock
/// data. Account and card digits are format valid but belong to no real
/// institution or scheme holder.
abstract final class MockSeed {
  static const String customerId = '00000000-0000-0000-0000-000000000001';

  /// Mock data: the signed in customer.
  static final UserProfile profile = UserProfile(
    id: customerId,
    fullName: 'Ava Mercado',
    email: 'ava.mercado@frostbank.app',
    mobile: '+63 917 847 1928',
    memberSince: DateTime(2019, 4, 17),
  );

  /// Sample values the sign in and sign up forms open with.
  ///
  /// [demoPassword] is not a stored credential. On a fresh install no address has
  /// a password yet, so the first one entered is adopted, and this constant only
  /// prefills the field. Requirement 5.9 forbids shipping a real credential, so
  /// nothing here is checked against a secret held in source.
  static const String demoEmail = 'ava.mercado@frostbank.app';
  static const String demoPassword = 'frostbank';
  static const String demoName = 'Ava Mercado';
  static const String demoMobile = '+63 917 847 1928';

  /// Additional seeded profiles, reachable by signing in with their address.
  /// Names only. Requirement 24.1 asks for locale appropriate full names.
  static final List<UserProfile> demoDirectory = [
    UserProfile(
      id: '00000000-0000-0000-0000-000000000002',
      fullName: 'An Yujin',
      email: 'yujin.an@frostbank.app',
      mobile: '+82 10-1001-0901',
      memberSince: DateTime(2021, 12, 1),
    ),
    UserProfile(
      id: '00000000-0000-0000-0000-000000000003',
      fullName: 'Jang Wonyoung',
      email: 'wonyoung.jang@frostbank.app',
      mobile: '+82 10-2002-0831',
      memberSince: DateTime(2021, 12, 1),
    ),
    UserProfile(
      id: '00000000-0000-0000-0000-000000000004',
      fullName: 'Kim Gaeul',
      email: 'gaeul.kim@frostbank.app',
      mobile: '+82 10-3003-0924',
      memberSince: DateTime(2021, 12, 1),
    ),
    UserProfile(
      id: '00000000-0000-0000-0000-000000000005',
      fullName: 'Naoi Rei',
      email: 'rei.naoi@frostbank.app',
      mobile: '+82 10-4004-0203',
      memberSince: DateTime(2021, 12, 1),
    ),
    UserProfile(
      id: '00000000-0000-0000-0000-000000000006',
      fullName: 'Kim Jiwon',
      email: 'liz.kim@frostbank.app',
      mobile: '+82 10-5005-1121',
      memberSince: DateTime(2021, 12, 1),
    ),
    UserProfile(
      id: '00000000-0000-0000-0000-000000000007',
      fullName: 'Lee Hyunseo',
      email: 'hyunseo.lee@frostbank.app',
      mobile: '+82 10-6006-0221',
      memberSince: DateTime(2021, 12, 1),
    ),
  ];

  /// Mock data: three accounts with format valid masked identifiers.
  static final List<Account> accounts = [
    const Account(
      id: 'acc_wallet',
      name: 'Everyday Wallet',
      shortCode: 'WALLET',
      kind: AccountKind.wallet,
      maskedNumber: '\u2022\u2022\u2022\u2022 4182',
      currencyCode: 'USD',
      totalBalance: 12480.55, // mock data
      availableBalance: 12106.20, // mock data
    ),
    const Account(
      id: 'acc_savings',
      name: 'Horizon Savings',
      shortCode: 'SAVINGS',
      kind: AccountKind.savings,
      maskedNumber: '\u2022\u2022\u2022\u2022 7735',
      currencyCode: 'USD',
      totalBalance: 38214.83, // mock data
      availableBalance: 38214.83, // mock data
    ),
    const Account(
      id: 'acc_crypto',
      name: 'Crypto Wallet',
      shortCode: 'BTC',
      kind: AccountKind.crypto,
      maskedNumber: 'bc1q \u2022\u2022\u2022\u2022 9d3f',
      currencyCode: 'USD',
      totalBalance: 9142.67, // mock data
      availableBalance: 9142.67, // mock data
      cryptoQuantity: 0.14382, // mock data
      cryptoUnit: 'BTC',
    ),
  ];

  /// Mock data: two cards. Digits pass the Luhn check for their scheme.
  static final List<BankCard> cards = [
    const BankCard(
      id: 'card_visa',
      accountId: 'acc_wallet',
      label: 'FrostBank Signature',
      holderName: 'Ava Mercado',
      number: '4137 8947 1175 1879',
      cvc: '678',
      expiry: '09/29',
      network: CardNetwork.visa,
      kind: CardKind.credit,
      status: CardStatus.active,
      balance: 12106.20, // mock data
      currencyCode: 'USD',
      spendingLimit: 4000, // mock data
    ),
    const BankCard(
      id: 'card_mc',
      accountId: 'acc_savings',
      label: 'Horizon Everyday',
      holderName: 'Ava Mercado',
      number: '5204 7401 4290 1028',
      cvc: '412',
      expiry: '02/28',
      network: CardNetwork.mastercard,
      kind: CardKind.debit,
      status: CardStatus.frozen,
      balance: 1875.40, // mock data
      currencyCode: 'USD',
      spendingLimit: 1500, // mock data
    ),
  ];

  /// Daily interest rate used for every seeded goal save.
  /// 0.011918% per day ≈ 4.35% APY.
  static const double goalDailyRate = 0.011918;

  /// Mock data: three goal saves with varying balances and targets.
  static List<GoalSave> goalSaves({DateTime? now}) {
    final ref = now ?? DateTime.now();
    return [
      GoalSave(
        id: 'goal_emergency',
        name: 'Emergency Fund',
        emoji: 'shield',
        targetAmount: 10000.00,
        balance: 6420.50, // mock data
        currencyCode: 'USD',
        dailyRatePercent: goalDailyRate,
        interestEarned: 28.14, // mock data
        createdAt: ref.subtract(const Duration(days: 198)),
        status: GoalSaveStatus.active,
      ),
      GoalSave(
        id: 'goal_europe',
        name: 'Europe Trip',
        emoji: 'flight',
        targetAmount: 5000.00,
        balance: 1875.30, // mock data
        currencyCode: 'USD',
        dailyRatePercent: goalDailyRate,
        interestEarned: 4.82, // mock data
        createdAt: ref.subtract(const Duration(days: 47)),
        status: GoalSaveStatus.active,
      ),
      GoalSave(
        id: 'goal_gadget',
        name: 'New Laptop',
        emoji: 'laptop',
        targetAmount: 2200.00,
        balance: 2200.00, // mock data — goal met
        currencyCode: 'USD',
        dailyRatePercent: goalDailyRate,
        interestEarned: 9.36, // mock data
        createdAt: ref.subtract(const Duration(days: 120)),
        status: GoalSaveStatus.active,
      ),
    ];
  }

  /// Mock data: goal save transaction ledger for every seeded goal.
  static List<GoalTxn> goalTransactions({DateTime? now}) {
    final ref = now ?? DateTime.now();

    DateTime ago(int days, {int hour = 10, int minute = 0}) => DateTime(
          ref.year,
          ref.month,
          ref.day,
          hour,
          minute,
        ).subtract(Duration(days: days));

    return [
      // Emergency Fund
      GoalTxn(
        id: 'gtxn_001',
        goalId: 'goal_emergency',
        kind: GoalTxnKind.transferIn,
        amount: 5000.00,
        runningBalance: 5000.00,
        date: ago(198),
        note: 'Initial deposit',
      ),
      GoalTxn(
        id: 'gtxn_002',
        goalId: 'goal_emergency',
        kind: GoalTxnKind.interest,
        amount: 0.60,
        runningBalance: 5000.60,
        date: ago(197),
      ),
      GoalTxn(
        id: 'gtxn_003',
        goalId: 'goal_emergency',
        kind: GoalTxnKind.transferIn,
        amount: 1400.00,
        runningBalance: 6400.60,
        date: ago(90),
        note: 'Top up',
      ),
      GoalTxn(
        id: 'gtxn_004',
        goalId: 'goal_emergency',
        kind: GoalTxnKind.interest,
        amount: 19.90,
        runningBalance: 6420.50,
        date: ago(1, hour: 0, minute: 5),
        note: 'Daily interest',
      ),
      // Europe Trip
      GoalTxn(
        id: 'gtxn_005',
        goalId: 'goal_europe',
        kind: GoalTxnKind.transferIn,
        amount: 1000.00,
        runningBalance: 1000.00,
        date: ago(47),
        note: 'Initial deposit',
      ),
      GoalTxn(
        id: 'gtxn_006',
        goalId: 'goal_europe',
        kind: GoalTxnKind.interest,
        amount: 0.12,
        runningBalance: 1000.12,
        date: ago(46),
      ),
      GoalTxn(
        id: 'gtxn_007',
        goalId: 'goal_europe',
        kind: GoalTxnKind.transferIn,
        amount: 875.00,
        runningBalance: 1875.12,
        date: ago(20),
        note: 'Monthly save',
      ),
      GoalTxn(
        id: 'gtxn_008',
        goalId: 'goal_europe',
        kind: GoalTxnKind.interest,
        amount: 0.18,
        runningBalance: 1875.30,
        date: ago(1, hour: 0, minute: 5),
        note: 'Daily interest',
      ),
      // New Laptop
      GoalTxn(
        id: 'gtxn_009',
        goalId: 'goal_gadget',
        kind: GoalTxnKind.transferIn,
        amount: 1000.00,
        runningBalance: 1000.00,
        date: ago(120),
        note: 'Initial deposit',
      ),
      GoalTxn(
        id: 'gtxn_010',
        goalId: 'goal_gadget',
        kind: GoalTxnKind.transferIn,
        amount: 1200.00,
        runningBalance: 2200.00,
        date: ago(60),
        note: 'Goal top up',
      ),
      GoalTxn(
        id: 'gtxn_011',
        goalId: 'goal_gadget',
        kind: GoalTxnKind.interest,
        amount: 9.36,
        runningBalance: 2200.00,
        date: ago(1, hour: 0, minute: 5),
        note: 'Daily interest',
      ),
    ];
  }
  /// The pairs the Crypto screen tracks.
  ///
  /// Not mock data: these are real Twelve Data symbols and their prices come
  /// from the live service. The list is deliberately short because the free plan
  /// charges one credit per symbol per refresh.
  static const List<CryptoAsset> cryptoAssets = [
    CryptoAsset(code: 'BTC', name: 'Bitcoin', quote: 'USD'),
    CryptoAsset(code: 'ETH', name: 'Ethereum', quote: 'USD'),
    CryptoAsset(code: 'SOL', name: 'Solana', quote: 'USD'),
    CryptoAsset(code: 'XRP', name: 'XRP', quote: 'USD'),
    CryptoAsset(code: 'LTC', name: 'Litecoin', quote: 'USD'),
  ];

  /// Mock data: units held, keyed by asset code. The ledger is mock, the price
  /// applied to it is live, so the portfolio figure is a real valuation of a
  /// made up position. A zero means the pair is tracked but not held.
  static const Map<String, double> cryptoHoldings = {
    'BTC': 0.14382, // mock data
    'ETH': 1.28740, // mock data
    'SOL': 24.5, // mock data
    'XRP': 0,
    'LTC': 0,
  };

  /// Mock data: promotions reference a named offer with a concrete benefit.
  static const List<Promo> promos = [
    Promo(
      id: 'promo_horizon',
      title: 'Horizon Savings at 4.35 percent',
      body: 'Move idle cash into Horizon and earn 4.35 percent on every dollar.',
      actionLabel: 'See rates',
      accentIndex: 0,
    ),
    Promo(
      id: 'promo_travel',
      title: 'No fees abroad this quarter',
      body: 'Signature cardholders pay zero conversion fees until 30 September.',
      actionLabel: 'View terms',
      accentIndex: 1,
    ),
    Promo(
      id: 'promo_split',
      title: 'Split Bills with four people',
      body: 'Share a bill and track who has paid without leaving the app.',
      actionLabel: 'Learn more',
      accentIndex: 2,
    ),
  ];

  /// Merchant table used to build the transaction ledger.
  static const List<_Merchant> _merchants = [
    _Merchant('Ludlow Coffee House', 'Dining', TxnType.cardPurchase),
    _Merchant('Verdant Grocers', 'Groceries', TxnType.cardPurchase),
    _Merchant('Halden Transit Authority', 'Transport', TxnType.qrPayment),
    _Merchant('Northgate Pharmacy', 'Health', TxnType.cardPurchase),
    _Merchant('Brightwire Energy', 'Utilities', TxnType.transfer),
    _Merchant('Solene Bakery', 'Dining', TxnType.qrPayment),
    _Merchant('Marlowe Books', 'Shopping', TxnType.cardPurchase),
    _Merchant('Ardent Fitness Club', 'Wellness', TxnType.transfer),
    _Merchant('Kestrel Airlines', 'Travel', TxnType.cardPurchase),
    _Merchant('Tobias Fuentes', 'Transfer', TxnType.transfer),
    _Merchant('Priya Raman', 'Transfer', TxnType.transfer),
    _Merchant('Cedarline Studios', 'Salary', TxnType.deposit),
    _Merchant('Harborview Rentals', 'Housing', TxnType.transfer),
    _Merchant('Lumen Mobile', 'Utilities', TxnType.qrPayment),
    _Merchant('Fable and Vine', 'Dining', TxnType.cardPurchase),
    _Merchant('Aster Home Supply', 'Home', TxnType.cardPurchase),
  ];

  /// Mock data: 44 transactions across 64 days, non rounded amounts, varied
  /// intervals, one pending and one failed so non success states are visible.
  static List<Txn> transactions({DateTime? now}) {
    final reference = now ?? DateTime.now();
    final rows = <Txn>[];

    // Day offset, hour, minute, merchant index, amount, direction, account.
    const plan = <List<Object>>[
      [0, 8, 12, 0, 6.85, 'out', 'acc_wallet'],
      [0, 12, 41, 1, 84.37, 'out', 'acc_wallet'],
      [0, 18, 3, 2, 3.25, 'out', 'acc_wallet'],
      [1, 9, 27, 5, 12.40, 'out', 'acc_wallet'],
      [1, 14, 55, 10, 240.00, 'in', 'acc_wallet'],
      [2, 7, 48, 0, 5.95, 'out', 'acc_wallet'],
      [2, 20, 16, 14, 63.18, 'out', 'acc_wallet'],
      [3, 11, 5, 3, 27.49, 'out', 'acc_wallet'],
      [3, 16, 38, 6, 41.72, 'out', 'acc_savings'],
      [4, 10, 22, 4, 138.66, 'out', 'acc_wallet'],
      [5, 8, 59, 13, 55.00, 'out', 'acc_wallet'],
      [5, 19, 14, 1, 96.03, 'out', 'acc_wallet'],
      [6, 12, 30, 9, 320.75, 'out', 'acc_wallet'],
      [7, 9, 9, 11, 4812.44, 'in', 'acc_wallet'],
      [7, 17, 47, 7, 79.99, 'out', 'acc_savings'],
      [8, 13, 21, 15, 212.34, 'out', 'acc_wallet'],
      [9, 8, 44, 0, 7.15, 'out', 'acc_wallet'],
      [10, 15, 2, 12, 1850.00, 'out', 'acc_wallet'],
      [11, 10, 36, 2, 3.25, 'out', 'acc_wallet'],
      [12, 19, 52, 14, 118.90, 'out', 'acc_wallet'],
      [13, 11, 13, 1, 72.61, 'out', 'acc_wallet'],
      [14, 9, 5, 5, 9.80, 'out', 'acc_wallet'],
      [15, 16, 29, 8, 486.12, 'out', 'acc_wallet'],
      [17, 12, 48, 10, 150.00, 'in', 'acc_wallet'],
      [18, 8, 33, 0, 6.40, 'out', 'acc_wallet'],
      [19, 14, 7, 3, 34.25, 'out', 'acc_savings'],
      [21, 9, 51, 11, 4812.44, 'in', 'acc_wallet'],
      [22, 18, 26, 6, 15.65, 'out', 'acc_wallet'],
      [24, 11, 42, 15, 89.47, 'out', 'acc_wallet'],
      [26, 13, 18, 1, 103.28, 'out', 'acc_wallet'],
      [28, 10, 4, 13, 55.00, 'out', 'acc_wallet'],
      [30, 15, 37, 4, 141.09, 'out', 'acc_wallet'],
      [32, 8, 24, 2, 3.25, 'out', 'acc_wallet'],
      [34, 17, 11, 9, 612.83, 'out', 'acc_wallet'],
      [36, 12, 56, 12, 1850.00, 'out', 'acc_wallet'],
      [38, 9, 31, 0, 5.60, 'out', 'acc_wallet'],
      [41, 14, 19, 7, 79.99, 'out', 'acc_savings'],
      [44, 10, 47, 1, 68.74, 'out', 'acc_wallet'],
      [47, 16, 8, 14, 92.15, 'out', 'acc_wallet'],
      [50, 11, 39, 10, 400.00, 'in', 'acc_savings'],
      [53, 9, 2, 11, 4812.44, 'in', 'acc_wallet'],
      [56, 13, 44, 15, 176.52, 'out', 'acc_wallet'],
      [59, 18, 21, 8, 486.12, 'out', 'acc_wallet'],
      [64, 12, 15, 5, 11.35, 'out', 'acc_wallet'],
    ];

    for (var index = 0; index < plan.length; index++) {
      final row = plan[index];
      final dayOffset = row[0] as int;
      final merchant = _merchants[row[3] as int];
      final inflow = row[5] == 'in';
      final day = DateTime(
        reference.year,
        reference.month,
        reference.day,
      ).subtract(Duration(days: dayOffset));

      // Mock data: one pending row near the top, one failed row mid ledger.
      final status = switch (index) {
        2 => TxnStatus.pending,
        12 => TxnStatus.failed,
        _ => TxnStatus.completed,
      };

      rows.add(
        Txn(
          id: 'txn_${(index + 1).toString().padLeft(3, '0')}',
          accountId: row[6] as String,
          merchant: merchant.name,
          category: merchant.category,
          amount: row[4] as double, // mock data
          currencyCode: 'USD',
          direction: inflow ? TxnDirection.inflow : TxnDirection.outflow,
          type: inflow && merchant.type != TxnType.deposit
              ? TxnType.transfer
              : merchant.type,
          status: status,
          date: DateTime(
            day.year,
            day.month,
            day.day,
            row[1] as int,
            row[2] as int,
          ),
          reference: 'NM-${(748219 + index * 137)}',
          note: merchant.category == 'Transfer' ? 'Shared costs' : null,
        ),
      );
    }

    rows.sort((a, b) => b.date.compareTo(a.date));
    return rows;
  }
}

class _Merchant {
  const _Merchant(this.name, this.category, this.type);

  final String name;
  final String category;
  final TxnType type;
}
