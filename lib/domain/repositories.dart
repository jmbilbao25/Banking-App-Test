/// Repository contracts. Presentation code depends on these and on the domain
/// models, never on a data source.
library;

import 'models.dart';
import 'split_bill_model.dart';

/// Domain level failure surfaced to the presentation layer.
class RepositoryFailure implements Exception {
  const RepositoryFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class AccountRepository {
  Future<List<Account>> fetchAccounts();

  Future<Account> fetchAccount(String id);

  /// Deposit funds into an account.
  Future<Account> deposit({required String accountId, required double amount});

  /// Transfer funds to a recipient or account.
  Future<Account> transfer({
    required String fromAccountId,
    required String recipient,
    required double amount,
    String? note,
  });
}

abstract interface class CardRepository {
  /// Every card on the profile, in a stable order.
  ///
  /// Stable is the part that matters, and it is a contract rather than a
  /// convenience. The deck addresses cards by position, so if a write can send
  /// the same set of cards back in a different order, freezing the card in front
  /// moves it somewhere else in the deck and puts a different card under the
  /// holder's thumb.
  Future<List<BankCard>> fetchCards();

  Future<BankCard> fetchCard(String id);

  /// Issue a card on [accountId].
  ///
  /// Every value is taken exactly as given and nothing is checked against a
  /// scheme. This build is a user interface presentation, so any digits, any
  /// expiry, and any security code produce a card that renders and behaves like
  /// the seeded ones. Blank fields are the caller's business, not this layer's.
  Future<BankCard> createCard({
    required String accountId,
    required String label,
    required String holderName,
    required String number,
    required String cvc,
    required String expiry,
    required CardNetwork network,
    required CardKind kind,
    required double spendingLimit,
  });

  /// Toggle card status between active and frozen.
  Future<BankCard> toggleCardFreeze(String cardId);

  /// Update daily spending limit.
  Future<BankCard> updateSpendingLimit(String cardId, double limit);
}

abstract interface class TransactionRepository {
  /// Reverse chronological. [accountId] null means every account.
  Future<List<Txn>> fetchTransactions({String? accountId});

  /// One page of the reverse chronological list, for requirement 15.10.
  ///
  /// Returns at most [limit] rows starting at [offset]. A short page, meaning
  /// fewer rows than [limit], tells the caller it has reached the end, so no
  /// separate total count is needed.
  Future<List<Txn>> fetchTransactionPage({
    String? accountId,
    required int offset,
    required int limit,
  });

  Future<Txn> fetchTransaction(String id);
}

abstract interface class PromoRepository {
  Future<List<Promo>> fetchPromos();
}

/// Live market data. The only repository backed by a network service rather than
/// the seeded mock world.
abstract interface class MarketRepository {
  /// Quotes for [assets], in the order given. Assets the venue does not return
  /// are dropped rather than failing the whole call, so one delisted pair cannot
  /// blank the screen.
  Future<List<CryptoQuote>> fetchCryptoQuotes(List<CryptoAsset> assets);

  Future<CryptoSeries> fetchCryptoSeries(CryptoAsset asset, ChartRange range);
}

abstract interface class ProfileRepository {
  Future<UserProfile> fetchProfile();

  Future<UserProfile> updateProfile(UserProfile profile);
}

abstract interface class SavingsGoalRepository {
  /// All goal saves for the signed-in user, newest first.
  Future<List<GoalSave>> fetchGoals();

  Future<GoalSave> fetchGoal(String id);

  /// Create a new goal save pocket.
  Future<GoalSave> openGoal({
    required String name,
    required String emoji,
    required double targetAmount,
    required double initialDeposit,
  });

  /// Move [amount] from the wallet/savings account into the goal.
  Future<GoalSave> transferIn({required String goalId, required double amount});

  /// Move [amount] out of the goal back to the wallet/savings account.
  Future<GoalSave> transferOut({
    required String goalId,
    required double amount,
  });

  /// Close the goal and return its balance to the source account.
  Future<GoalSave> closeGoal(String id);

  /// Transaction ledger for one goal, newest first.
  Future<List<GoalTxn>> fetchGoalTransactions(String goalId);
}

abstract interface class SplitBillRepository {
  Future<List<SplitBill>> fetchSplitBills();

  Future<SplitBill> fetchSplitBill(String id);

  /// Create a bill with a specific split mode.
  ///
  /// [splitMode] defaults to [SplitMode.equal].
  /// [customAmounts] is required when [splitMode] == [SplitMode.custom];
  /// length must match [participantNames].length + 1 (host first).
  /// [percentages] is required when [splitMode] == [SplitMode.percentage];
  /// same length rule, must sum to 100.
  Future<SplitBill> createSplitBill({
    required String title,
    required double totalAmount,
    required String category,
    required List<String> participantNames,
    SplitMode splitMode = SplitMode.equal,
    List<double>? customAmounts,
    List<double>? percentages,
    String? description,
  });

  Future<bool> confirmPayment({
    required String billId,
    required String participantId,
    String? payingAccountId,
    String currencyCode = 'USD',
  });

  /// Join an existing bill as a new participant.
  /// Returns the updated [SplitBill] or null when the bill isn't found.
  Future<SplitBill?> joinBill({
    required String billId,
    required String participantName,
  });
}

abstract interface class AuthRepository {
  /// Resolves the stored session, or null when there is none.
  Future<UserProfile?> restoreSession();

  Future<UserProfile> signIn({required String email, required String password});

  Future<UserProfile> signUp({
    required String fullName,
    required String email,
    required String mobile,
    required String password,
  });

  Future<void> signOut();
}
