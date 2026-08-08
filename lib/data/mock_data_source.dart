import 'dart:math';

import '../core/persistence/credential_vault.dart';
import '../domain/models.dart';
import '../domain/repositories.dart';
import 'mock_seed.dart';
import 'mock_snapshot.dart';

/// Seeded in memory store shared by every mock repository.
///
/// Reads resolve after a randomised delay so loading skeletons are observable,
/// and no call touches the network.
class MockDataSource {
  /// Pass [snapshot] to resume a persisted data set instead of reseeding, which
  /// is what requirement 6.7 asks for on launch.
  MockDataSource({
    DateTime? now,
    Random? random,
    MockDataSnapshot? snapshot,
    this.credentials,
  }) : _random = random ?? Random(7),
       _accounts = List.of(snapshot?.accounts ?? MockSeed.accounts),
       _cards = List.of(snapshot?.cards ?? MockSeed.cards),
       _transactions = snapshot == null
           ? MockSeed.transactions(now: now)
           : List.of(snapshot.transactions),
       _promos = List.of(MockSeed.promos),
       _profile = snapshot?.profile ?? MockSeed.profile,
       _goals = snapshot == null
           ? MockSeed.goalSaves(now: now)
           : List.of(snapshot.goals),
       _goalTxns = snapshot == null
           ? MockSeed.goalTransactions(now: now)
           : List.of(snapshot.goalTxns),
       _goalCounter = snapshot?.goalCounter ?? MockSeed.goalSaves().length,
       _cardCounter = snapshot?.cardCounter ?? MockSeed.cards.length;

  /// Verifies demo passwords. Null in tests and in any build without a store, in
  /// which case any password of a valid length is accepted.
  final CredentialVault? credentials;

  /// Invoked after every successful write so the owner can persist the data set,
  /// per requirement 6.6. Set by the provider that also owns the store.
  void Function()? onMutate;

  /// Captures the mutable half of the data set for persistence.
  MockDataSnapshot toSnapshot() => MockDataSnapshot(
    accounts: List.of(_accounts),
    cards: List.of(_cards),
    transactions: List.of(_transactions),
    profile: _profile,
    goals: List.of(_goals),
    goalTxns: List.of(_goalTxns),
    goalCounter: _goalCounter,
    cardCounter: _cardCounter,
  );

  /// Called at the end of every mutating method. Five writes deliberately bypass
  /// [read], and two are synchronous, so the notification lives here rather than
  /// in the read gate.
  void _touch() => onMutate?.call();

  final Random _random;
  final List<Account> _accounts;
  final List<BankCard> _cards;
  final List<Txn> _transactions;
  final List<Promo> _promos;
  UserProfile _profile;
  final List<GoalSave> _goals;
  final List<GoalTxn> _goalTxns;
  int _goalCounter;
  int _cardCounter;

  /// Domains that should fail, so error states can be verified without a real
  /// backend. Add a key such as `accounts` or `transactions`.
  final Set<String> errorSimulation = <String>{};

  /// Set to zero in tests to keep them fast.
  Duration Function()? latencyOverride;

  UserProfile? _session;

  List<Account> get accountsView => List.unmodifiable(_accounts);

  Duration _latency() {
    final override = latencyOverride;
    if (override != null) return override();
    return Duration(milliseconds: 300 + _random.nextInt(600));
  }

  Future<T> read<T>(String domain, T Function() body) async {
    await Future<void>.delayed(_latency());
    if (errorSimulation.contains(domain)) {
      throw RepositoryFailure('We could not load your $domain right now.');
    }
    return body();
  }

  /// Write gate. Same latency and failure behaviour as [read], and it notifies
  /// afterwards so the mutated data set is persisted, per requirement 6.6.
  Future<T> _write<T>(String domain, T Function() body) async {
    final result = await read(domain, body);
    _touch();
    return result;
  }

  Future<List<Account>> accounts() =>
      read('accounts', () => List<Account>.unmodifiable(_accounts));

  Future<Account> account(String id) => read('accounts', () {
    final match = _accounts.where((account) => account.id == id).firstOrNull;
    if (match == null) {
      throw const RepositoryFailure('That account is no longer available.');
    }
    return match;
  });

  Future<Account> deposit(String accountId, double amount) async {
    return _write('accounts', () {
      final index = _accounts.indexWhere((acc) => acc.id == accountId);
      if (index == -1) {
        throw const RepositoryFailure('Account not found.');
      }
      final old = _accounts[index];
      final newTotal = old.totalBalance + amount;
      final newAvail = old.availableBalance + amount;
      final updated = Account(
        id: old.id,
        name: old.name,
        shortCode: old.shortCode,
        kind: old.kind,
        maskedNumber: old.maskedNumber,
        currencyCode: old.currencyCode,
        totalBalance: newTotal,
        availableBalance: newAvail,
        cryptoQuantity: old.cryptoQuantity,
        cryptoUnit: old.cryptoUnit,
      );
      _accounts[index] = updated;

      final txn = Txn(
        id: 'txn_${DateTime.now().millisecondsSinceEpoch}',
        accountId: accountId,
        merchant: 'Deposit',
        category: 'Deposit',
        amount: amount,
        currencyCode: old.currencyCode,
        direction: TxnDirection.inflow,
        type: TxnType.deposit,
        status: TxnStatus.completed,
        date: DateTime.now(),
        reference: 'NM-${_random.nextInt(900000) + 100000}',
        note: 'Deposit to ${old.name}',
      );
      _transactions.insert(0, txn);
      return updated;
    });
  }

  Future<Account> transfer({
    required String fromAccountId,
    required String recipient,
    required double amount,
    String? note,
  }) async {
    return _write('accounts', () {
      final index = _accounts.indexWhere((acc) => acc.id == fromAccountId);
      if (index == -1) {
        throw const RepositoryFailure('Source account not found.');
      }
      final old = _accounts[index];
      if (amount > old.availableBalance) {
        throw const RepositoryFailure('Insufficient balance for transfer.');
      }
      final newTotal = old.totalBalance - amount;
      final newAvail = old.availableBalance - amount;
      final updated = Account(
        id: old.id,
        name: old.name,
        shortCode: old.shortCode,
        kind: old.kind,
        maskedNumber: old.maskedNumber,
        currencyCode: old.currencyCode,
        totalBalance: newTotal,
        availableBalance: newAvail,
        cryptoQuantity: old.cryptoQuantity,
        cryptoUnit: old.cryptoUnit,
      );
      _accounts[index] = updated;

      final txn = Txn(
        id: 'txn_${DateTime.now().millisecondsSinceEpoch}',
        accountId: fromAccountId,
        merchant: recipient,
        category: 'Transfer',
        amount: amount,
        currencyCode: old.currencyCode,
        direction: TxnDirection.outflow,
        type: TxnType.transfer,
        status: TxnStatus.completed,
        date: DateTime.now(),
        reference: 'NM-${_random.nextInt(900000) + 100000}',
        note: note,
      );
      _transactions.insert(0, txn);

      final targetIndex = _accounts.indexWhere(
        (acc) =>
            acc.id == recipient ||
            acc.name.toLowerCase() == recipient.toLowerCase() ||
            acc.maskedNumber == recipient,
      );
      if (targetIndex != -1 && targetIndex != index) {
        final targetOld = _accounts[targetIndex];
        _accounts[targetIndex] = Account(
          id: targetOld.id,
          name: targetOld.name,
          shortCode: targetOld.shortCode,
          kind: targetOld.kind,
          maskedNumber: targetOld.maskedNumber,
          currencyCode: targetOld.currencyCode,
          totalBalance: targetOld.totalBalance + amount,
          availableBalance: targetOld.availableBalance + amount,
          cryptoQuantity: targetOld.cryptoQuantity,
          cryptoUnit: targetOld.cryptoUnit,
        );
        _transactions.insert(
          0,
          Txn(
            id: 'txn_${DateTime.now().millisecondsSinceEpoch + 1}',
            accountId: targetOld.id,
            merchant: old.name,
            category: 'Transfer',
            amount: amount,
            currencyCode: targetOld.currencyCode,
            direction: TxnDirection.inflow,
            type: TxnType.transfer,
            status: TxnStatus.completed,
            date: DateTime.now(),
            reference: 'NM-${_random.nextInt(900000) + 100000}',
            note: note,
          ),
        );
      }

      return updated;
    });
  }

  Future<List<BankCard>> cards() =>
      read('cards', () => List<BankCard>.unmodifiable(_cards));

  Future<BankCard> card(String id) => read('cards', () {
    final match = _cards.where((card) => card.id == id).firstOrNull;
    if (match == null) {
      throw const RepositoryFailure('That card is no longer available.');
    }
    return match;
  });

  /// Issues a card and appends it to the deck.
  ///
  /// Goes through the plain delay rather than [read], the same way [openGoal]
  /// does, so a simulated read failure cannot swallow a write the holder just
  /// confirmed.
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
  }) async {
    await Future<void>.delayed(_latency());
    _cardCounter++;
    final account = _accounts.where((acc) => acc.id == accountId).firstOrNull;
    final card = BankCard(
      id: 'card_${_cardCounter.toString().padLeft(3, '0')}',
      accountId: accountId,
      label: label,
      holderName: holderName,
      number: number,
      cvc: cvc,
      expiry: expiry,
      network: network,
      kind: kind,
      status: CardStatus.active,
      // A card that was just issued has had nothing spent on it.
      balance: 0,
      currencyCode: account?.currencyCode ?? 'USD',
      spendingLimit: spendingLimit,
    );
    _cards.add(card);
    _touch();
    return card;
  }

  Future<BankCard> toggleCardFreeze(String cardId) async {
    return _write('cards', () {
      final index = _cards.indexWhere((c) => c.id == cardId);
      if (index == -1) {
        throw const RepositoryFailure('Card not found.');
      }
      final old = _cards[index];
      final newStatus = old.status == CardStatus.active
          ? CardStatus.frozen
          : CardStatus.active;
      // Replaced where it sits, never removed and re-added. The deck addresses
      // cards by position, so moving one here would move it under the holder's
      // thumb: freeze the card in front and a different card would be in front.
      final updated = BankCard(
        id: old.id,
        accountId: old.accountId,
        label: old.label,
        holderName: old.holderName,
        number: old.number,
        cvc: old.cvc,
        expiry: old.expiry,
        network: old.network,
        kind: old.kind,
        status: newStatus,
        balance: old.balance,
        currencyCode: old.currencyCode,
        spendingLimit: old.spendingLimit,
      );
      _cards[index] = updated;
      return updated;
    });
  }

  Future<BankCard> updateSpendingLimit(String cardId, double limit) async {
    return _write('cards', () {
      final index = _cards.indexWhere((c) => c.id == cardId);
      if (index == -1) {
        throw const RepositoryFailure('Card not found.');
      }
      final old = _cards[index];
      final updated = BankCard(
        id: old.id,
        accountId: old.accountId,
        label: old.label,
        holderName: old.holderName,
        number: old.number,
        cvc: old.cvc,
        expiry: old.expiry,
        network: old.network,
        kind: old.kind,
        status: old.status,
        balance: old.balance,
        currencyCode: old.currencyCode,
        spendingLimit: limit,
      );
      _cards[index] = updated;
      return updated;
    });
  }

  Future<UserProfile> updateProfile(UserProfile newProfile) async {
    return _write('profile', () {
      _profile = newProfile;
      if (_session != null) _session = newProfile;
      return _profile;
    });
  }

  Future<List<Txn>> transactions({String? accountId}) =>
      read('transactions', () {
        final rows = accountId == null
            ? _transactions
            : _transactions.where((txn) => txn.accountId == accountId).toList();
        return List<Txn>.unmodifiable(rows);
      });

  Future<Txn> transaction(String id) => read('transactions', () {
    final match = _transactions.where((txn) => txn.id == id).firstOrNull;
    if (match == null) {
      throw const RepositoryFailure('That transaction is no longer available.');
    }
    return match;
  });

  void addTransaction(Txn txn) {
    _transactions.insert(0, txn);
    _touch();
  }

  void deductAccountBalance(String accountId, double amount) {
    final index = _accounts.indexWhere((acc) => acc.id == accountId);
    if (index != -1) {
      final old = _accounts[index];
      final newTotal = (old.totalBalance - amount).clamp(0.0, double.infinity);
      final newAvail = (old.availableBalance - amount).clamp(
        0.0,
        double.infinity,
      );
      _accounts[index] = Account(
        id: old.id,
        name: old.name,
        shortCode: old.shortCode,
        kind: old.kind,
        maskedNumber: old.maskedNumber,
        currencyCode: old.currencyCode,
        totalBalance: newTotal,
        availableBalance: newAvail,
        cryptoQuantity: old.cryptoQuantity,
        cryptoUnit: old.cryptoUnit,
      );
      _touch();
    }
  }

  Future<List<Promo>> promos() =>
      read('offers', () => List<Promo>.unmodifiable(_promos));

  Future<UserProfile> profile() => read('profile', () => _profile);

  void replaceProfile(UserProfile profile) {
    _profile = profile;
    _touch();
  }

  /// Adopts a session restored from Persistence_Store, so requirement 9.5 can
  /// hand a retained session back on the next launch.
  void adoptSession(UserProfile profile) {
    _profile = profile;
    _session = profile;
  }

  // Session handling. The session itself is persisted by the owning provider, so
  // a restore on the next launch returns the retained profile.
  Future<UserProfile?> restoreSession() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return _session;
  }

  /// Demo sign in with strict password and credential validation.
  Future<UserProfile> signIn(String email, String password) async {
    await Future<void>.delayed(_latency());

    if (password.trim().length < 8) {
      throw const RepositoryFailure(
        'Password must be at least 8 characters long.',
      );
    }

    final cleanEmail = email.trim().toLowerCase();

    // Requirement 9.8: an incorrect password is rejected with one message that
    // names neither field, so the response cannot be used to discover which
    // addresses are registered.
    final vault = credentials;
    if (vault != null &&
        !vault.verify(email: cleanEmail, password: password)) {
      throw const RepositoryFailure(
        'That email or password is incorrect.',
      );
    }

    final profile = _directoryProfile(cleanEmail);

    // The first password used for an address becomes that address's password,
    // so the seeded demo profiles stay reachable without a password in source.
    if (vault != null && !vault.hasCredential(cleanEmail)) {
      await vault.setPassword(email: cleanEmail, password: password);
    }

    _profile = profile;
    _session = profile;
    _touch();
    return profile;
  }

  /// Resolves a seeded demo profile for [cleanEmail], or builds one from the
  /// address. No password appears here, per requirement 5.9.
  UserProfile _directoryProfile(String cleanEmail) {
    if (MockSeed.profile.email.toLowerCase() == cleanEmail) {
      return MockSeed.profile;
    }
    if (_profile.email.toLowerCase() == cleanEmail) {
      return _profile;
    }
    for (final entry in MockSeed.demoDirectory) {
      if (entry.email.toLowerCase() == cleanEmail) return entry;
    }
    return UserProfile(
      id: 'usr_${cleanEmail.hashCode.abs()}',
      fullName: _formatNameFromEmail(cleanEmail),
      email: cleanEmail,
      mobile: MockSeed.demoMobile,
      memberSince: DateTime.now(),
    );
  }

  String _formatNameFromEmail(String email) {
    final prefix = email.split('@').first;
    if (prefix.toLowerCase().contains('gaeul')) return 'Kim Gaeul (Gaeul)';
    if (prefix.toLowerCase().contains('yujin')) return 'An Yujin';
    if (prefix.toLowerCase().contains('wonyoung')) return 'Jang Wonyoung';
    if (prefix.toLowerCase().contains('rei')) return 'Rei (Naoi Rei)';
    if (prefix.toLowerCase().contains('liz')) return 'Liz (Kim Jiwon)';
    if (prefix.toLowerCase().contains('leeseo') || prefix.toLowerCase().contains('hyunseo')) return 'Leeseo (Lee Hyunseo)';
    final parts = prefix.split(RegExp(r'[._-]'));
    final capitalized = parts.map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}').join(' ');
    return capitalized.isEmpty ? 'User' : capitalized;
  }

  /// Demo sign up. Takes the entered name and email into the seeded profile so
  /// the rest of the application reflects what was typed.
  Future<UserProfile> signUp({
    required String fullName,
    required String email,
    required String mobile,
    required String password,
  }) async {
    await Future<void>.delayed(_latency());
    _profile = UserProfile(
      id: _profile.id,
      fullName: fullName.trim().isEmpty ? _profile.fullName : fullName.trim(),
      email: email.trim().isEmpty ? _profile.email : email.trim(),
      mobile: mobile.trim().isEmpty ? _profile.mobile : mobile.trim(),
      memberSince: DateTime.now(),
    );
    _session = _profile;
    // Requirement 10.2: the new account's password becomes its credential.
    await credentials?.setPassword(email: _profile.email, password: password);
    _touch();
    return _profile;
  }

  Future<void> signOut() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _session = null;
  }

  // ---------------------------------------------------------------------------
  // Goal Saves
  // ---------------------------------------------------------------------------

  Future<List<GoalSave>> goals() => read(
    'savings',
    () => List<GoalSave>.unmodifiable(
      List.of(_goals)..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    ),
  );

  Future<GoalSave> goal(String id) => read('savings', () {
    final match = _goals.where((g) => g.id == id).firstOrNull;
    if (match == null) {
      throw const RepositoryFailure('That goal is no longer available.');
    }
    return match;
  });

  Future<GoalSave> openGoal({
    required String name,
    required String emoji,
    required double targetAmount,
    required double initialDeposit,
  }) async {
    await Future<void>.delayed(_latency());
    _goalCounter++;
    final newGoal = GoalSave(
      id: 'goal_${_goalCounter.toString().padLeft(3, '0')}',
      name: name.trim(),
      emoji: emoji,
      targetAmount: targetAmount,
      balance: initialDeposit,
      currencyCode: 'USD',
      dailyRatePercent: MockSeed.goalDailyRate,
      interestEarned: 0,
      createdAt: DateTime.now(),
      status: GoalSaveStatus.active,
    );
    _goals.add(newGoal);

    if (initialDeposit > 0) {
      _goalTxns.add(
        GoalTxn(
          id: 'gtxn_${DateTime.now().millisecondsSinceEpoch}',
          goalId: newGoal.id,
          kind: GoalTxnKind.transferIn,
          amount: initialDeposit,
          runningBalance: initialDeposit,
          date: DateTime.now(),
          note: 'Initial deposit',
        ),
      );
    }
    _touch();
    return newGoal;
  }

  Future<GoalSave> transferIn({
    required String goalId,
    required double amount,
  }) async {
    await Future<void>.delayed(_latency());
    final index = _goals.indexWhere((g) => g.id == goalId);
    if (index == -1) {
      throw const RepositoryFailure('That goal is no longer available.');
    }
    final old = _goals[index];
    if (old.status != GoalSaveStatus.active) {
      throw const RepositoryFailure(
        'You can only add funds to an active goal.',
      );
    }
    final updated = old.copyWith(balance: old.balance + amount);
    _goals[index] = updated;
    _goalTxns.add(
      GoalTxn(
        id: 'gtxn_${DateTime.now().millisecondsSinceEpoch}',
        goalId: goalId,
        kind: GoalTxnKind.transferIn,
        amount: amount,
        runningBalance: updated.balance,
        date: DateTime.now(),
      ),
    );
    _touch();
    return updated;
  }

  Future<GoalSave> transferOut({
    required String goalId,
    required double amount,
  }) async {
    await Future<void>.delayed(_latency());
    final index = _goals.indexWhere((g) => g.id == goalId);
    if (index == -1) {
      throw const RepositoryFailure('That goal is no longer available.');
    }
    final old = _goals[index];
    if (old.status != GoalSaveStatus.active) {
      throw const RepositoryFailure(
        'You can only withdraw from an active goal.',
      );
    }
    if (amount > old.balance) {
      throw const RepositoryFailure(
        'Withdrawal amount exceeds the goal balance.',
      );
    }
    final updated = old.copyWith(balance: old.balance - amount);
    _goals[index] = updated;
    _goalTxns.add(
      GoalTxn(
        id: 'gtxn_${DateTime.now().millisecondsSinceEpoch}',
        goalId: goalId,
        kind: GoalTxnKind.transferOut,
        amount: amount,
        runningBalance: updated.balance,
        date: DateTime.now(),
      ),
    );
    _touch();
    return updated;
  }

  Future<GoalSave> closeGoal(String id) async {
    await Future<void>.delayed(_latency());
    final index = _goals.indexWhere((g) => g.id == id);
    if (index == -1) {
      throw const RepositoryFailure('That goal is no longer available.');
    }
    final old = _goals[index];
    final updated = old.copyWith(status: GoalSaveStatus.closed, balance: 0);
    _goals[index] = updated;
    if (old.balance > 0) {
      _goalTxns.add(
        GoalTxn(
          id: 'gtxn_${DateTime.now().millisecondsSinceEpoch}',
          goalId: id,
          kind: GoalTxnKind.transferOut,
          amount: old.balance,
          runningBalance: 0,
          date: DateTime.now(),
          note: 'Goal closed, funds returned',
        ),
      );
    }
    _touch();
    return updated;
  }

  Future<List<GoalTxn>> goalTransactions(String goalId) => read('savings', () {
    final rows = _goalTxns.where((t) => t.goalId == goalId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return List<GoalTxn>.unmodifiable(rows);
  });
}
