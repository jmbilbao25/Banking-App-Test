import '../domain/models.dart';
import 'model_codecs.dart';

/// A point in time copy of the mutable half of the mock data set.
///
/// Requirement 6.6 says a successful write persists the mutated state, and
/// requirement 6.7 says a launch that finds a persisted data set loads it
/// instead of reseeding. This type is what moves between `MockDataSource` and
/// Persistence_Store to satisfy both.
///
/// Promotions are absent on purpose: nothing mutates them, so they are reseeded
/// from `MockSeed` and cost nothing to store.
class MockDataSnapshot {
  const MockDataSnapshot({
    required this.accounts,
    required this.cards,
    required this.transactions,
    required this.profile,
    required this.goals,
    required this.goalTxns,
    required this.goalCounter,
    required this.cardCounter,
  });

  final List<Account> accounts;
  final List<BankCard> cards;
  final List<Txn> transactions;
  final UserProfile profile;
  final List<GoalSave> goals;
  final List<GoalTxn> goalTxns;

  /// Identifier sequences. Without these a reload would mint a second
  /// `card_003` or `goal_003` and two records would share an id.
  final int goalCounter;
  final int cardCounter;

  /// Bumped when the stored shape changes in a way older data cannot satisfy.
  static const currentVersion = 1;

  Map<String, Object?> toJson() => {
    'version': currentVersion,
    'accounts': ModelCodecs.encodeList(accounts, ModelCodecs.accountToMap),
    'cards': ModelCodecs.encodeList(cards, ModelCodecs.cardToMap),
    'transactions': ModelCodecs.encodeList(transactions, ModelCodecs.txnToMap),
    'profile': ModelCodecs.profileToMap(profile),
    'goals': ModelCodecs.encodeList(goals, ModelCodecs.goalToMap),
    'goal_txns': ModelCodecs.encodeList(goalTxns, ModelCodecs.goalTxnToMap),
    'goal_counter': goalCounter,
    'card_counter': cardCounter,
  };

  /// Returns null when the blob is absent, from a future version, or missing the
  /// records that make it usable. A refusal here means the caller reseeds, which
  /// is always safer than launching onto a half decoded account list.
  static MockDataSnapshot? tryDecode(
    Map<String, Object?>? json, {
    required DateTime now,
  }) {
    if (json == null) return null;
    if (ModelCodecs.intOr(json['version'], -1) != currentVersion) return null;

    final accounts = ModelCodecs.decodeList(
      json['accounts'],
      ModelCodecs.accountFromMap,
    );
    final profileJson = json['profile'];
    if (accounts.isEmpty || profileJson is! Map<String, Object?>) return null;

    return MockDataSnapshot(
      accounts: accounts,
      cards: ModelCodecs.decodeList(json['cards'], ModelCodecs.cardFromMap),
      transactions: ModelCodecs.decodeList(
        json['transactions'],
        (map) => ModelCodecs.txnFromMap(map, now: now),
      ),
      profile: ModelCodecs.profileFromMap(profileJson, now: now),
      goals: ModelCodecs.decodeList(
        json['goals'],
        (map) => ModelCodecs.goalFromMap(map, now: now),
      ),
      goalTxns: ModelCodecs.decodeList(
        json['goal_txns'],
        (map) => ModelCodecs.goalTxnFromMap(map, now: now),
      ),
      goalCounter: ModelCodecs.intOr(json['goal_counter'], 0),
      cardCounter: ModelCodecs.intOr(json['card_counter'], 0),
    );
  }
}
