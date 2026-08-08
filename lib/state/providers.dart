import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/config/api_config.dart';
import '../core/persistence/credential_vault.dart';
import '../core/persistence/persistence_store.dart';
import '../core/persistence/pin_vault.dart';
import '../core/security/biometric_service.dart';
import '../core/supabase_config.dart';
import 'app_lock_controller.dart';
import '../data/mock_data_source.dart';
import '../data/mock_snapshot.dart';
import '../data/mock_market_repository.dart';
import '../data/mock_repositories.dart';
import '../domain/models.dart';
import '../data/mock_seed.dart';
import '../data/twelve_data_market_repository.dart';
import '../data/supabase_repositories.dart';
import '../domain/repositories.dart';
import 'preferences_controller.dart';
import 'session_controller.dart';
import 'txn_filter.dart';

/// Riverpod retries failed providers on its own by default, which would hold a
/// failed section in its loading skeleton instead of showing the failure. Retry
/// belongs to the user here, through the retry control in the error state.
Duration? noAutomaticRetry(int retryCount, Object error) => null;

/// Persistence_Store. `main` overrides this with the real device backed store
/// before `runApp`; the in memory default keeps tests and any build without a
/// platform channel working with identical behaviour, minus durability.
final persistenceStoreProvider = Provider<PersistenceStore>(
  (ref) => InMemoryPersistenceStore(),
);

/// Holds the App_Lock PIN as a salted digest, never as the PIN itself.
final pinVaultProvider = Provider<PinVault>(
  (ref) => PinVault(ref.watch(persistenceStoreProvider)),
);

/// Platform biometric prompt. Overridden in tests, which have no channel.
final biometricServiceProvider = Provider<BiometricService>(
  (ref) => LocalAuthBiometricService(),
);

/// True when the device reports an enrolled biometric. Requirement 23.7 renders
/// the profile toggle disabled with an explanation when this is false.
final biometricEnrolledProvider = FutureProvider<bool>(
  (ref) => ref.watch(biometricServiceProvider).isEnrolled(),
  retry: noAutomaticRetry,
);

/// Whether the authenticated surface is behind App_Lock.
final appLockProvider = NotifierProvider<AppLockController, bool>(
  AppLockController.new,
);

/// Holds demo account passwords as salted digests, so requirement 5.9 is met and
/// requirements 9.8 and 11.6 have a real secret to work against.
final credentialVaultProvider = Provider<CredentialVault>(
  (ref) => CredentialVault(ref.watch(persistenceStoreProvider)),
);

/// Controls whether the app uses Supabase or offline Mock repositories.
final useSupabaseProvider = NotifierProvider<UseSupabaseNotifier, bool>(
  UseSupabaseNotifier.new,
);

class UseSupabaseNotifier extends Notifier<bool> {
  @override
  bool build() => SupabaseConfig.isInitialized;

  void toggle() => state = !state;
  void setUseSupabase(bool value) => state = value;
}

/// Data source and repositories. Override [mockDataSourceProvider] in tests to
/// seed a different world or to remove latency.
///
/// On construction the persisted snapshot is loaded if one exists, satisfying
/// requirement 6.7, and every subsequent write is written back through
/// [onMutate], satisfying requirement 6.6.
final mockDataSourceProvider = Provider<MockDataSource>((ref) {
  final store = ref.watch(persistenceStoreProvider);
  final now = DateTime.now();
  final source = MockDataSource(
    snapshot: MockDataSnapshot.tryDecode(
      store.readJson(StoreKeys.dataSnapshot),
      now: now,
    ),
    credentials: ref.watch(credentialVaultProvider),
  );

  // Writes arrive in bursts, for example a transfer that debits one account and
  // credits another. Coalescing into a microtask keeps one encode per burst
  // instead of one per field change.
  var scheduled = false;
  source.onMutate = () {
    if (scheduled) return;
    scheduled = true;
    scheduleMicrotask(() {
      scheduled = false;
      store.writeJson(StoreKeys.dataSnapshot, source.toSnapshot().toJson());
    });
  };
  return source;
});

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  final useSupabase = ref.watch(useSupabaseProvider);
  if (useSupabase && SupabaseConfig.isInitialized) {
    return SupabaseAccountRepository();
  }
  return MockAccountRepository(ref.watch(mockDataSourceProvider));
});

final cardRepositoryProvider = Provider<CardRepository>((ref) {
  final useSupabase = ref.watch(useSupabaseProvider);
  if (useSupabase && SupabaseConfig.isInitialized) {
    return SupabaseCardRepository();
  }
  return MockCardRepository(ref.watch(mockDataSourceProvider));
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final useSupabase = ref.watch(useSupabaseProvider);
  if (useSupabase && SupabaseConfig.isInitialized) {
    return SupabaseTransactionRepository();
  }
  return MockTransactionRepository(ref.watch(mockDataSourceProvider));
});

final promoRepositoryProvider = Provider<PromoRepository>((ref) {
  final useSupabase = ref.watch(useSupabaseProvider);
  if (useSupabase && SupabaseConfig.isInitialized) {
    return SupabasePromoRepository();
  }
  return MockPromoRepository(ref.watch(mockDataSourceProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final useSupabase = ref.watch(useSupabaseProvider);
  if (useSupabase && SupabaseConfig.isInitialized) {
    return SupabaseProfileRepository();
  }
  return MockProfileRepository(ref.watch(mockDataSourceProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final useSupabase = ref.watch(useSupabaseProvider);
  if (useSupabase && SupabaseConfig.isInitialized) {
    return SupabaseAuthRepository();
  }
  return MockAuthRepository(ref.watch(mockDataSourceProvider));
});

final splitBillRepositoryProvider = Provider<SplitBillRepository>((ref) {
  final useSupabase = ref.watch(useSupabaseProvider);
  if (useSupabase && SupabaseConfig.isInitialized) {
    return SupabaseSplitBillRepository();
  }
  return MockSplitBillRepository(ref.watch(mockDataSourceProvider));
});

/// The one outbound HTTP client. Override in tests with a mock client so no test
/// ever touches the network.
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// True when no market data key was supplied at build time, so every rate on
/// screen is generated locally. The crypto surface reads this to state that its
/// rates are mock data, per requirement 19.8. A made up price on a screen
/// labelled live would be a lie, so the label follows the source.
final marketDataIsMockProvider = Provider<bool>(
  (ref) => !ApiConfig.hasTwelveDataKey,
);

/// Market data. Requirement 5.9 forbids shipping an API key, so a build without
/// the define falls back to locally generated bars rather than failing every
/// crypto read.
final marketRepositoryProvider = Provider<MarketRepository>((ref) {
  if (ref.watch(marketDataIsMockProvider)) {
    return MockMarketRepository();
  }
  return TwelveDataMarketRepository(client: ref.watch(httpClientProvider));
});

/// Application state.
final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

final preferencesProvider =
    NotifierProvider<PreferencesController, Preferences>(
      PreferencesController.new,
    );

final txnFilterProvider = NotifierProvider<TxnFilterController, TxnFilter>(
  TxnFilterController.new,
);

/// Tracks whether the user has dismissed the launch advertisement.
final openingAdDismissedProvider =
    NotifierProvider<OpeningAdDismissedController, bool>(
      OpeningAdDismissedController.new,
    );

class OpeningAdDismissedController extends Notifier<bool> {
  @override
  bool build() => false;

  void dismiss() => state = true;
  void reset() => state = false;
}

/// Reads. Every one of these renders through an async value, so loading,
/// empty, and error states come from one place in the presentation layer.
final accountsProvider = FutureProvider<List<Account>>(
  (ref) => ref.watch(accountRepositoryProvider).fetchAccounts(),
);

final accountProvider = FutureProvider.family<Account, String>(
  (ref, id) => ref.watch(accountRepositoryProvider).fetchAccount(id),
);

final cardsProvider = FutureProvider<List<BankCard>>(
  (ref) => ref.watch(cardRepositoryProvider).fetchCards(),
);

final cardProvider = FutureProvider.family<BankCard, String>(
  (ref, id) => ref.watch(cardRepositoryProvider).fetchCard(id),
);

/// Async state for card writes.
sealed class CardActionState {
  const CardActionState();
}

class CardIdle extends CardActionState {
  const CardIdle();
}

class CardWorking extends CardActionState {
  const CardWorking();
}

class CardSuccess extends CardActionState {
  const CardSuccess(this.card);

  final BankCard card;
}

class CardError extends CardActionState {
  const CardError(this.message);

  final String message;
}

/// Handles writes on cards and invalidates the read providers afterwards, so the
/// deck reflects the new state without the caller having to know which providers
/// derive from which.
///
/// [accountCardsProvider] is not invalidated here: it watches [cardsProvider],
/// so it recomputes on its own.
class CardsController extends Notifier<CardActionState> {
  @override
  CardActionState build() => const CardIdle();

  CardRepository get _repo => ref.read(cardRepositoryProvider);

  /// Issues a card. Returns false and parks the reason in state on failure, the
  /// same contract the savings writes use.
  Future<bool> createCard({
    required String accountId,
    required String label,
    required String holderName,
    required String number,
    required String cvc,
    required String expiry,
    required CardNetwork network,
    required CardKind kind,
    required double spendingLimit,
  }) async {
    state = const CardWorking();
    try {
      final card = await _repo.createCard(
        accountId: accountId,
        label: label,
        holderName: holderName,
        number: number,
        cvc: cvc,
        expiry: expiry,
        network: network,
        kind: kind,
        spendingLimit: spendingLimit,
      );
      ref.invalidate(cardsProvider);
      state = CardSuccess(card);
      return true;
    } on RepositoryFailure catch (e) {
      state = CardError(e.message);
      return false;
    } catch (_) {
      state = const CardError('Something went wrong. Please try again.');
      return false;
    }
  }

  Future<bool> toggleFreeze(String cardId) async {
    state = const CardWorking();
    try {
      final card = await _repo.toggleCardFreeze(cardId);
      ref.invalidate(cardsProvider);
      ref.invalidate(cardProvider(cardId));
      state = CardSuccess(card);
      return true;
    } on RepositoryFailure catch (e) {
      state = CardError(e.message);
      return false;
    } catch (_) {
      state = const CardError('Something went wrong. Please try again.');
      return false;
    }
  }
}

final cardsControllerProvider =
    NotifierProvider<CardsController, CardActionState>(CardsController.new);

/// Pass null for every account.
final transactionsProvider = FutureProvider.family<List<Txn>, String?>(
  (ref, accountId) => ref
      .watch(transactionRepositoryProvider)
      .fetchTransactions(accountId: accountId),
);

final transactionProvider = FutureProvider.family<Txn, String>(
  (ref, id) => ref.watch(transactionRepositoryProvider).fetchTransaction(id),
);

final promosProvider = FutureProvider<List<Promo>>(
  (ref) => ref.watch(promoRepositoryProvider).fetchPromos(),
);

final profileProvider = FutureProvider<UserProfile>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session is SessionSignedIn) {
    return session.profile;
  }
  return ref.watch(profileRepositoryProvider).fetchProfile();
});

/// Dashboard selection. Null resolves to the first seeded account.
final selectedAccountIdProvider =
    NotifierProvider<SelectedAccountId, String?>(SelectedAccountId.new);

class SelectedAccountId extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String id) => state = id;
}

/// The account the dashboard is currently showing.
final selectedAccountProvider = Provider<AsyncValue<Account?>>((ref) {
  final accounts = ref.watch(accountsProvider);
  final selectedId = ref.watch(selectedAccountIdProvider);
  return accounts.whenData((rows) {
    if (rows.isEmpty) return null;
    return rows.firstWhere(
      (account) => account.id == selectedId,
      orElse: () => rows.first,
    );
  });
});

/// The full ledger with the active filter applied.
final filteredTransactionsProvider = FutureProvider<List<Txn>>((ref) async {
  final rows = await ref.watch(transactionsProvider(null).future);
  final filter = ref.watch(txnFilterProvider);
  return filter.apply(rows);
});

/// Cards belonging to one account.
final accountCardsProvider = FutureProvider.family<List<BankCard>, String>(
  (ref, accountId) async {
    final cards = await ref.watch(cardsProvider.future);
    return cards.where((card) => card.accountId == accountId).toList();
  },
);

/// The pairs the Crypto screen tracks.
final cryptoAssetsProvider = Provider<List<CryptoAsset>>(
  (ref) => MockSeed.cryptoAssets,
);

final cryptoAssetProvider = Provider.family<CryptoAsset?, String>(
  (ref, code) => ref
      .watch(cryptoAssetsProvider)
      .where((asset) => asset.code.toUpperCase() == code.toUpperCase())
      .firstOrNull,
);

/// Live quotes for every tracked pair.
///
/// Auto disposed and kept on a timer, so prices stay current while the Crypto
/// screen is open and stop costing credits the moment it is closed. One refresh
/// spends one credit per symbol, so the period is set well inside the free
/// plan's budget.
final cryptoQuotesProvider = FutureProvider.autoDispose<List<CryptoQuote>>((
  ref,
) async {
  final repository = ref.watch(marketRepositoryProvider);
  final assets = ref.watch(cryptoAssetsProvider);

  final timer = Timer.periodic(
    const Duration(seconds: 45),
    (_) => ref.invalidateSelf(),
  );
  ref.onDispose(timer.cancel);

  return repository.fetchCryptoQuotes(assets);
});

/// Live quote for one pair, read off the same batch call the list uses so
/// opening a pair costs no extra credits.
final cryptoQuoteProvider = Provider.autoDispose
    .family<AsyncValue<CryptoQuote?>, String>(
      (ref, code) => ref.watch(cryptoQuotesProvider).whenData(
        (quotes) => quotes
            .where((quote) => quote.code.toUpperCase() == code.toUpperCase())
            .firstOrNull,
      ),
    );

/// Units held in one pair. Ledger data, so mock in this build.
final cryptoHoldingProvider = Provider.family<double, String>(
  (ref, code) => MockSeed.cryptoHoldings[code.toUpperCase()] ?? 0,
);

/// Every tracked pair paired with the position held in it, held pairs first and
/// then by value.
final cryptoPositionsProvider =
    Provider.autoDispose<AsyncValue<List<CryptoPosition>>>((ref) {
      return ref.watch(cryptoQuotesProvider).whenData((quotes) {
        final positions = [
          for (final quote in quotes)
            CryptoPosition(
              quote: quote,
              quantity: ref.watch(cryptoHoldingProvider(quote.code)),
            ),
        ]..sort((a, b) {
          if (a.isHeld != b.isHeld) return a.isHeld ? -1 : 1;
          return b.value.compareTo(a.value);
        });
        return positions;
      });
    });

/// Live valuation of the mock crypto ledger.
final cryptoPortfolioProvider = Provider.autoDispose<AsyncValue<CryptoPortfolio>>(
  (ref) => ref.watch(cryptoPositionsProvider).whenData(CryptoPortfolio.of),
);

/// One pair over one span. A record, so the family key compares structurally and
/// each span is cached separately.
typedef CryptoSeriesQuery = ({String code, ChartRange range});

/// Bars for one pair over one span. Auto disposed, so leaving the screen stops
/// the span being held in memory, and each span is fetched at most once inside
/// the repository's cache window.
final cryptoSeriesProvider = FutureProvider.autoDispose
    .family<CryptoSeries, CryptoSeriesQuery>((ref, query) async {
      final asset = ref.watch(cryptoAssetProvider(query.code));
      if (asset == null) {
        throw RepositoryFailure('${query.code} is not a tracked pair.');
      }
      return ref
          .watch(marketRepositoryProvider)
          .fetchCryptoSeries(asset, query.range);
    });

/// Inflow and outflow totals for the current calendar month.
class MonthFlow {
  const MonthFlow({required this.inflow, required this.outflow});

  final double inflow;
  final double outflow;
}

final monthFlowProvider = FutureProvider.family<MonthFlow, String>(
  (ref, accountId) async {
    final rows = await ref.watch(transactionsProvider(accountId).future);
    final now = DateTime.now();
    var inflow = 0.0;
    var outflow = 0.0;
    for (final txn in rows) {
      if (txn.date.year != now.year || txn.date.month != now.month) continue;
      if (txn.status == TxnStatus.failed) continue;
      if (txn.isInflow) {
        inflow += txn.amount;
      } else {
        outflow += txn.amount;
      }
    }
    return MonthFlow(inflow: inflow, outflow: outflow);
  },
);

// ---------------------------------------------------------------------------
// Savings Goals
// ---------------------------------------------------------------------------

final savingsGoalRepositoryProvider = Provider<SavingsGoalRepository>((ref) {
  final useSupabase = ref.watch(useSupabaseProvider);
  if (useSupabase && SupabaseConfig.isInitialized) {
    return SupabaseSavingsGoalRepository();
  }
  return MockSavingsGoalRepository(ref.watch(mockDataSourceProvider));
});

final goalsProvider = FutureProvider<List<GoalSave>>(
  (ref) => ref.read(savingsGoalRepositoryProvider).fetchGoals(),
  retry: noAutomaticRetry,
);

final goalProvider = FutureProvider.family<GoalSave, String>(
  (ref, id) => ref.read(savingsGoalRepositoryProvider).fetchGoal(id),
  retry: noAutomaticRetry,
);

final goalTransactionsProvider = FutureProvider.family<List<GoalTxn>, String>(
  (ref, goalId) =>
      ref.read(savingsGoalRepositoryProvider).fetchGoalTransactions(goalId),
  retry: noAutomaticRetry,
);

/// Total balance across all active goal saves.
final totalSavingsProvider = FutureProvider<double>((ref) async {
  final goals = await ref.watch(goalsProvider.future);
  var total = 0.0;
  for (final g in goals) {
    if (g.status == GoalSaveStatus.active) total += g.balance;
  }
  return total;
}, retry: noAutomaticRetry);

/// Async state for mutations (open, transfer, close).
sealed class SavingsActionState {
  const SavingsActionState();
}

class SavingsIdle extends SavingsActionState {
  const SavingsIdle();
}

class SavingsWorking extends SavingsActionState {
  const SavingsWorking();
}

class SavingsSuccess extends SavingsActionState {
  const SavingsSuccess(this.goal);
  final GoalSave goal;
}

class SavingsError extends SavingsActionState {
  const SavingsError(this.message);
  final String message;
}

/// Handles all write operations on goal saves and invalidates read providers
/// after each successful mutation so the UI reflects the new state.
class SavingsController extends Notifier<SavingsActionState> {
  @override
  SavingsActionState build() => const SavingsIdle();

  SavingsGoalRepository get _repo =>
      ref.read(savingsGoalRepositoryProvider);

  Future<bool> openGoal({
    required String name,
    required String emoji,
    required double targetAmount,
    required double initialDeposit,
  }) async {
    state = const SavingsWorking();
    try {
      final goal = await _repo.openGoal(
        name: name,
        emoji: emoji,
        targetAmount: targetAmount,
        initialDeposit: initialDeposit,
      );
      ref.invalidate(goalsProvider);
      ref.invalidate(totalSavingsProvider);
      state = SavingsSuccess(goal);
      return true;
    } on RepositoryFailure catch (e) {
      state = SavingsError(e.message);
      return false;
    } catch (_) {
      state = const SavingsError('Something went wrong. Please try again.');
      return false;
    }
  }

  Future<bool> transferIn({
    required String goalId,
    required double amount,
  }) async {
    state = const SavingsWorking();
    try {
      final goal =
          await _repo.transferIn(goalId: goalId, amount: amount);
      ref.invalidate(goalsProvider);
      ref.invalidate(goalProvider(goalId));
      ref.invalidate(goalTransactionsProvider(goalId));
      ref.invalidate(totalSavingsProvider);
      state = SavingsSuccess(goal);
      return true;
    } on RepositoryFailure catch (e) {
      state = SavingsError(e.message);
      return false;
    } catch (_) {
      state = const SavingsError('Something went wrong. Please try again.');
      return false;
    }
  }

  Future<bool> transferOut({
    required String goalId,
    required double amount,
  }) async {
    state = const SavingsWorking();
    try {
      final goal =
          await _repo.transferOut(goalId: goalId, amount: amount);
      ref.invalidate(goalsProvider);
      ref.invalidate(goalProvider(goalId));
      ref.invalidate(goalTransactionsProvider(goalId));
      ref.invalidate(totalSavingsProvider);
      state = SavingsSuccess(goal);
      return true;
    } on RepositoryFailure catch (e) {
      state = SavingsError(e.message);
      return false;
    } catch (_) {
      state = const SavingsError('Something went wrong. Please try again.');
      return false;
    }
  }

  Future<bool> closeGoal(String goalId) async {
    state = const SavingsWorking();
    try {
      final goal = await _repo.closeGoal(goalId);
      ref.invalidate(goalsProvider);
      ref.invalidate(goalProvider(goalId));
      ref.invalidate(goalTransactionsProvider(goalId));
      ref.invalidate(totalSavingsProvider);
      state = SavingsSuccess(goal);
      return true;
    } on RepositoryFailure catch (e) {
      state = SavingsError(e.message);
      return false;
    } catch (_) {
      state = const SavingsError('Something went wrong. Please try again.');
      return false;
    }
  }

  void reset() => state = const SavingsIdle();
}

final savingsControllerProvider =
    NotifierProvider<SavingsController, SavingsActionState>(
  SavingsController.new,
);
