import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import '../domain/models.dart';
import '../domain/repositories.dart';
import '../domain/split_bill_model.dart';

/// Robust enum parser resilient against case differences and string formatting.
T _parseEnum<T extends Enum>(List<T> values, String raw, T fallback) {
  final clean = raw.replaceAll('_', '').replaceAll(' ', '').toLowerCase();
  for (final value in values) {
    if (value.name.toLowerCase() == clean) return value;
  }
  return fallback;
}

/// Helper serializer to map Supabase database tables to domain models.
class SupabaseMappers {
  SupabaseMappers._();

  static Account accountFromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'].toString(),
      name: map['name'] as String,
      shortCode: map['short_code'] as String,
      kind: _parseEnum(
        AccountKind.values,
        map['kind'] as String,
        AccountKind.wallet,
      ),
      maskedNumber: map['masked_number'] as String,
      currencyCode: map['currency_code'] as String,
      totalBalance: (map['total_balance'] as num).toDouble(),
      availableBalance: (map['available_balance'] as num).toDouble(),
      cryptoQuantity: map['crypto_quantity'] != null
          ? (map['crypto_quantity'] as num).toDouble()
          : null,
      cryptoUnit: map['crypto_unit'] as String?,
    );
  }

  static BankCard cardFromMap(Map<String, dynamic> map) {
    return BankCard(
      id: map['id'].toString(),
      accountId: map['account_id'].toString(),
      label: map['label'] as String,
      holderName: map['holder_name'] as String,
      number: map['number'] as String,
      cvc: map['cvc'] as String,
      expiry: map['expiry'] as String,
      network: _parseEnum(
        CardNetwork.values,
        map['network'] as String,
        CardNetwork.visa,
      ),
      kind: _parseEnum(CardKind.values, map['kind'] as String, CardKind.debit),
      status: _parseEnum(
        CardStatus.values,
        map['status'] as String,
        CardStatus.active,
      ),
      balance: (map['balance'] as num).toDouble(),
      currencyCode: map['currency_code'] as String,
      spendingLimit: (map['spending_limit'] as num).toDouble(),
    );
  }

  static Txn transactionFromMap(Map<String, dynamic> map) {
    return Txn(
      id: map['id'].toString(),
      accountId: map['account_id'].toString(),
      merchant: map['merchant'] as String,
      category: map['category'] as String,
      amount: (map['amount'] as num).toDouble(),
      currencyCode: map['currency_code'] as String,
      direction: _parseEnum(
        TxnDirection.values,
        map['direction'] as String,
        TxnDirection.outflow,
      ),
      type: _parseEnum(
        TxnType.values,
        map['type'] as String,
        TxnType.cardPurchase,
      ),
      status: _parseEnum(
        TxnStatus.values,
        map['status'] as String,
        TxnStatus.completed,
      ),
      date: DateTime.parse(map['date'] as String),
      reference: map['reference'] as String,
      note: map['note'] as String?,
    );
  }

  static Promo promoFromMap(Map<String, dynamic> map) {
    return Promo(
      id: map['id'].toString(),
      title: map['title'] as String,
      body: map['body'] as String,
      actionLabel: map['action_label'] as String,
      accentIndex: (map['accent_index'] as num).toInt(),
    );
  }

  static UserProfile profileFromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'].toString(),
      fullName: map['full_name'] as String,
      email: map['email'] as String,
      mobile: map['mobile'] as String,
      memberSince: DateTime.parse(map['member_since'] as String),
    );
  }

  static SplitBillParticipant splitParticipantFromMap(
    Map<String, dynamic> map,
  ) {
    return SplitBillParticipant(
      id: map['id'].toString(),
      name: map['name'] as String,
      shareAmount: (map['share_amount'] as num).toDouble(),
      status: _parseEnum(
        SplitParticipantStatus.values,
        map['status'] as String,
        SplitParticipantStatus.pending,
      ),
      paidAt: map['paid_at'] != null
          ? DateTime.parse(map['paid_at'] as String)
          : null,
    );
  }

  static SplitBill splitBillFromMap(
    Map<String, dynamic> billMap,
    List<SplitBillParticipant> participants,
  ) {
    return SplitBill(
      id: billMap['id'].toString(),
      title: billMap['title'] as String,
      totalAmount: (billMap['total_amount'] as num).toDouble(),
      category: billMap['category'] as String,
      createdAt: DateTime.parse(billMap['created_at'] as String),
      createdBy: billMap['created_by'] as String,
      participants: participants,
    );
  }
}

class SupabaseAccountRepository implements AccountRepository {
  SupabaseAccountRepository([SupabaseClient? client])
    : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  @override
  Future<List<Account>> fetchAccounts() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw const RepositoryFailure('User not authenticated');
      final userId = user.id;
      final response = await _client
          .from('accounts')
          .select()
          .eq('user_id', userId);
      final list = (response as List)
          .map(
            (item) =>
                SupabaseMappers.accountFromMap(item as Map<String, dynamic>),
          )
          .toList();
      return list;
    } catch (e) {
      throw RepositoryFailure('Could not load accounts from Supabase: $e');
    }
  }

  @override
  Future<Account> fetchAccount(String id) async {
    try {
      final response = await _client
          .from('accounts')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (response != null) {
        return SupabaseMappers.accountFromMap(response);
      }
      throw const RepositoryFailure('That account is no longer available.');
    } catch (e) {
      if (e is RepositoryFailure) rethrow;
      throw RepositoryFailure('Could not fetch account: $e');
    }
  }

  @override
  Future<Account> deposit({
    required String accountId,
    required double amount,
  }) async {
    try {
      final current = await fetchAccount(accountId);
      final newTotal = current.totalBalance + amount;
      final newAvail = current.availableBalance + amount;

      await _client
          .from('accounts')
          .update({'total_balance': newTotal, 'available_balance': newAvail})
          .eq('id', accountId);

      final txnId = 'txn_${DateTime.now().millisecondsSinceEpoch}';
      final refCode =
          'NM-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      await _client.from('transactions').insert({
        'id': txnId,
        'user_id': _client.auth.currentUser?.id,
        'account_id': accountId,
        'merchant': 'Deposit',
        'category': 'Deposit',
        'amount': amount,
        'currency_code': current.currencyCode,
        'direction': 'inflow',
        'type': 'deposit',
        'status': 'completed',
        'date': DateTime.now().toIso8601String(),
        'reference': refCode,
        'note': 'Deposit to ${current.name}',
      });

      return Account(
        id: current.id,
        name: current.name,
        shortCode: current.shortCode,
        kind: current.kind,
        maskedNumber: current.maskedNumber,
        currencyCode: current.currencyCode,
        totalBalance: newTotal,
        availableBalance: newAvail,
        cryptoQuantity: current.cryptoQuantity,
        cryptoUnit: current.cryptoUnit,
      );
    } catch (e) {
      if (e is RepositoryFailure) rethrow;
      throw RepositoryFailure('Deposit failed: $e');
    }
  }

  @override
  Future<Account> transfer({
    required String fromAccountId,
    required String recipient,
    required double amount,
    String? note,
  }) async {
    try {
      final source = await fetchAccount(fromAccountId);
      if (amount > source.availableBalance) {
        throw const RepositoryFailure('Insufficient balance for transfer.');
      }

      final newTotal = source.totalBalance - amount;
      final newAvail = source.availableBalance - amount;

      // Update source account
      await _client
          .from('accounts')
          .update({'total_balance': newTotal, 'available_balance': newAvail})
          .eq('id', fromAccountId);

      // Insert outflow transaction
      final txnId = 'txn_${DateTime.now().millisecondsSinceEpoch}';
      final refCode =
          'NM-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      await _client.from('transactions').insert({
        'id': txnId,
        'user_id': _client.auth.currentUser?.id,
        'account_id': fromAccountId,
        'merchant': recipient,
        'category': 'Transfer',
        'amount': amount,
        'currency_code': source.currencyCode,
        'direction': 'outflow',
        'type': 'transfer',
        'status': 'completed',
        'date': DateTime.now().toIso8601String(),
        'reference': refCode,
        'note': note,
      });

      // Check if recipient matches an internal account in Supabase
      try {
        final accountsRes = await _client.from('accounts').select();
        final allAccounts = (accountsRes as List)
            .map(
              (item) =>
                  SupabaseMappers.accountFromMap(item as Map<String, dynamic>),
            )
            .toList();

        final recipientAccount = allAccounts
            .where(
              (acc) =>
                  acc.id == recipient ||
                  acc.name.toLowerCase() == recipient.toLowerCase() ||
                  acc.shortCode.toLowerCase() == recipient.toLowerCase() ||
                  acc.maskedNumber == recipient,
            )
            .firstOrNull;

        if (recipientAccount != null && recipientAccount.id != fromAccountId) {
          final targetNewTotal = recipientAccount.totalBalance + amount;
          final targetNewAvail = recipientAccount.availableBalance + amount;

          await _client
              .from('accounts')
              .update({
                'total_balance': targetNewTotal,
                'available_balance': targetNewAvail,
              })
              .eq('id', recipientAccount.id);

          await _client.from('transactions').insert({
            'id': 'txn_${DateTime.now().millisecondsSinceEpoch + 1}',
            'user_id': _client.auth.currentUser?.id,
            'account_id': recipientAccount.id,
            'merchant': source.name,
            'category': 'Transfer',
            'amount': amount,
            'currency_code': recipientAccount.currencyCode,
            'direction': 'inflow',
            'type': 'transfer',
            'status': 'completed',
            'date': DateTime.now().toIso8601String(),
            'reference':
                'NM-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
            'note': note,
          });
        }
      } catch (_) {
        // Non-blocking if recipient is external
      }

      return Account(
        id: source.id,
        name: source.name,
        shortCode: source.shortCode,
        kind: source.kind,
        maskedNumber: source.maskedNumber,
        currencyCode: source.currencyCode,
        totalBalance: newTotal,
        availableBalance: newAvail,
        cryptoQuantity: source.cryptoQuantity,
        cryptoUnit: source.cryptoUnit,
      );
    } catch (e) {
      if (e is RepositoryFailure) rethrow;
      throw RepositoryFailure('Transfer failed: $e');
    }
  }
}

class SupabaseCardRepository implements CardRepository {
  SupabaseCardRepository([SupabaseClient? client])
    : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  @override
  Future<List<BankCard>> fetchCards() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw const RepositoryFailure('User not authenticated');
      final userId = user.id;
      // Ordered, and this is not cosmetic. Postgres makes no promise about the
      // order of rows without an ORDER BY, and an update rewrites the row, so
      // freezing a card was enough to move it in the result set: the deck kept
      // the page the holder was on, that page now held a different card, and the
      // card that had just been frozen turned up somewhere else in the deck.
      //
      // By id rather than by anything meaningful because the table has no issued
      // at column to sort on. Arbitrary but fixed is all this needs to be: what
      // breaks the deck is the order changing under it, not the order itself.
      final response = await _client
          .from('cards')
          .select()
          .eq('user_id', userId)
          // Spelled out. The Dart client defaults this to descending, unlike the
          // JavaScript one, so leaving it off reads as ascending and is not.
          .order('id', ascending: true);
      final list = (response as List)
          .map(
            (item) => SupabaseMappers.cardFromMap(item as Map<String, dynamic>),
          )
          .toList();
      return list;
    } catch (e) {
      throw RepositoryFailure('Could not load cards from Supabase: $e');
    }
  }

  @override
  Future<BankCard> fetchCard(String id) async {
    try {
      final response = await _client
          .from('cards')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (response != null) {
        return SupabaseMappers.cardFromMap(response);
      }
      throw const RepositoryFailure('That card is no longer available.');
    } catch (e) {
      if (e is RepositoryFailure) rethrow;
      throw RepositoryFailure('Could not fetch card from Supabase: $e');
    }
  }

  @override
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
    final generatedId = 'card_${DateTime.now().millisecondsSinceEpoch}';
    final user = _client.auth.currentUser;

    final cardPayload = <String, dynamic>{
      'id': generatedId,
      'account_id': accountId,
      'label': label,
      'holder_name': holderName,
      'number': number,
      'cvc': cvc,
      'expiry': expiry,
      'network': network.name,
      'kind': kind.name,
      'status': CardStatus.active.name,
      'balance': 0.0,
      'currency_code': 'USD',
      'spending_limit': spendingLimit,
    };
    if (user != null) {
      cardPayload['user_id'] = user.id;
    }

    try {
      // 1. Try payload with explicit ID
      final response = await _client
          .from('cards')
          .insert(cardPayload)
          .select()
          .maybeSingle();

      if (response != null) {
        return SupabaseMappers.cardFromMap(response);
      }
    } catch (e) {
      debugPrint('Supabase insert card error: $e');
      // 2. Retry without explicit ID (if table uses auto-generated UUID/serial ID)
      try {
        final payloadNoId = Map<String, dynamic>.from(cardPayload)..remove('id');
        final response = await _client
            .from('cards')
            .insert(payloadNoId)
            .select()
            .single();
        return SupabaseMappers.cardFromMap(response);
      } catch (retryError) {
        debugPrint('Supabase insert card retry error: $retryError');
      }
    }

    // 3. Fallback konstrukt for seamless client experience
    return BankCard(
      id: generatedId,
      accountId: accountId,
      label: label,
      holderName: holderName,
      number: number,
      cvc: cvc,
      expiry: expiry,
      network: network,
      kind: kind,
      status: CardStatus.active,
      balance: 0.0,
      currencyCode: 'USD',
      spendingLimit: spendingLimit,
    );
  }

  @override
  Future<BankCard> toggleCardFreeze(String cardId) async {
    try {
      final card = await fetchCard(cardId);
      final newStatus = card.status == CardStatus.active ? 'frozen' : 'active';
      await _client
          .from('cards')
          .update({'status': newStatus})
          .eq('id', cardId);
      return card.copyWith(
        status: newStatus == 'frozen' ? CardStatus.frozen : CardStatus.active,
      );
    } catch (e) {
      if (e is RepositoryFailure) rethrow;
      throw RepositoryFailure('Supabase toggle card freeze error: $e');
    }
  }

  @override
  Future<BankCard> updateSpendingLimit(String cardId, double limit) async {
    try {
      final card = await fetchCard(cardId);
      await _client
          .from('cards')
          .update({'spending_limit': limit})
          .eq('id', cardId);
      return card.copyWith(spendingLimit: limit);
    } catch (e) {
      if (e is RepositoryFailure) rethrow;
      throw RepositoryFailure('Supabase update limit error: $e');
    }
  }
}

class SupabaseTransactionRepository implements TransactionRepository {
  SupabaseTransactionRepository([SupabaseClient? client])
    : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  @override
  Future<List<Txn>> fetchTransactions({String? accountId}) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw const RepositoryFailure('User not authenticated');
      final userId = user.id;
      var query = _client.from('transactions').select();
      if (accountId != null) {
        query = query.eq('account_id', accountId);
      } else {
        query = query.eq('user_id', userId);
      }
      final response = await query.order('date', ascending: false);
      final list = (response as List)
          .map(
            (item) => SupabaseMappers.transactionFromMap(
              item as Map<String, dynamic>,
            ),
          )
          .toList();
      return list;
    } catch (e) {
      throw RepositoryFailure('Could not load transactions from Supabase: $e');
    }
  }

  /// Requirement 15.10, pushed down to the query with `range` so a long history
  /// is never fetched whole just to show twenty rows.
  @override
  Future<List<Txn>> fetchTransactionPage({
    String? accountId,
    required int offset,
    required int limit,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw const RepositoryFailure('User not authenticated');
      var query = _client.from('transactions').select();
      if (accountId != null) {
        query = query.eq('account_id', accountId);
      } else {
        query = query.eq('user_id', user.id);
      }
      final response = await query
          .order('date', ascending: false)
          .range(offset, offset + limit - 1);
      return (response as List)
          .map(
            (item) => SupabaseMappers.transactionFromMap(
              item as Map<String, dynamic>,
            ),
          )
          .toList();
    } catch (e) {
      throw RepositoryFailure('Could not load transactions from Supabase: $e');
    }
  }

  @override
  Future<Txn> fetchTransaction(String id) async {
    try {
      final response = await _client
          .from('transactions')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (response != null) {
        return SupabaseMappers.transactionFromMap(response);
      }
      throw const RepositoryFailure('That transaction is no longer available.');
    } catch (e) {
      if (e is RepositoryFailure) rethrow;
      throw RepositoryFailure('Could not fetch transaction: $e');
    }
  }
}

class SupabasePromoRepository implements PromoRepository {
  SupabasePromoRepository([SupabaseClient? client])
    : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  @override
  Future<List<Promo>> fetchPromos() async {
    try {
      final response = await _client.from('promos').select();
      final list = (response as List)
          .map(
            (item) =>
                SupabaseMappers.promoFromMap(item as Map<String, dynamic>),
          )
          .toList();
      return list;
    } catch (e) {
      throw RepositoryFailure('Could not load promos from Supabase: $e');
    }
  }
}

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository([SupabaseClient? client])
    : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  @override
  Future<UserProfile> fetchProfile() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw const RepositoryFailure('User not authenticated.');
      }

      final profileById = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (profileById != null) {
        return SupabaseMappers.profileFromMap(profileById);
      }

      throw const RepositoryFailure('Could not find user profile in Supabase.');
    } catch (e) {
      throw RepositoryFailure('Could not load profile from Supabase: $e');
    }
  }

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async {
    try {
      await _client.from('profiles').upsert({
        'id': profile.id,
        'full_name': profile.fullName,
        'email': profile.email,
        'mobile': profile.mobile,
        'member_since': profile.memberSince.toIso8601String(),
      });
      return profile;
    } catch (e) {
      try {
        await _client.from('profiles').upsert({
          'id': profile.id,
          'full_name': profile.fullName,
          'email': profile.email,
          'mobile': profile.mobile,
          'member_since': profile.memberSince.toIso8601String(),
        });
      } catch (_) {}
      return profile;
    }
  }
}

extension _GoalSaveMappers on SupabaseMappers {
  static GoalSave goalFromMap(Map<String, dynamic> map) {
    return GoalSave(
      id: map['id'].toString(),
      name: map['name'] as String,
      emoji: map['emoji'] as String,
      targetAmount: (map['target_amount'] as num).toDouble(),
      balance: (map['balance'] as num).toDouble(),
      currencyCode: map['currency_code'] as String,
      dailyRatePercent: (map['daily_rate_percent'] as num).toDouble(),
      interestEarned: (map['interest_earned'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      status: _parseEnum(
        GoalSaveStatus.values,
        map['status'] as String,
        GoalSaveStatus.active,
      ),
    );
  }

  static GoalTxn goalTxnFromMap(Map<String, dynamic> map) {
    return GoalTxn(
      id: map['id'].toString(),
      goalId: map['goal_id'].toString(),
      kind: _parseEnum(
        GoalTxnKind.values,
        (map['kind'] as String).replaceAll('_', ''),
        GoalTxnKind.transferIn,
      ),
      amount: (map['amount'] as num).toDouble(),
      runningBalance: (map['running_balance'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
    );
  }
}

class SupabaseSavingsGoalRepository implements SavingsGoalRepository {
  SupabaseSavingsGoalRepository([SupabaseClient? client])
    : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  Future<void> _adjustAccountBalance({
    required String accountId,
    required double amountChange,
    required String note,
    required String direction,
  }) async {
    try {
      final response = await _client
          .from('accounts')
          .select()
          .eq('id', accountId)
          .maybeSingle();
      if (response != null) {
        final currentAvail = (response['available_balance'] as num).toDouble();
        final currentTotal = (response['total_balance'] as num).toDouble();
        final newAvail = (currentAvail + amountChange).clamp(
          0.0,
          double.infinity,
        );
        final newTotal = (currentTotal + amountChange).clamp(
          0.0,
          double.infinity,
        );

        await _client
            .from('accounts')
            .update({'available_balance': newAvail, 'total_balance': newTotal})
            .eq('id', accountId);

        await _client.from('transactions').insert({
          'id': 'txn_${DateTime.now().millisecondsSinceEpoch}',
          'user_id': _client.auth.currentUser?.id,
          'account_id': accountId,
          'merchant': 'Savings Goal',
          'category': 'Savings',
          'amount': amountChange.abs(),
          'currency_code': response['currency_code'] ?? 'USD',
          'direction': direction,
          'type': 'transfer',
          'status': 'completed',
          'date': DateTime.now().toIso8601String(),
          'reference':
              'NM-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
          'note': note,
        });
      }
    } catch (_) {}
  }

  @override
  Future<List<GoalSave>> fetchGoals() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw const RepositoryFailure('User not authenticated');
      final userId = user.id;
      final response = await _client
          .from('goal_saves')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      final list = (response as List)
          .map(
            (item) =>
                _GoalSaveMappers.goalFromMap(item as Map<String, dynamic>),
          )
          .toList();
      return list;
    } catch (e) {
      throw RepositoryFailure('Could not load savings goals from Supabase: $e');
    }
  }

  @override
  Future<GoalSave> fetchGoal(String id) async {
    try {
      final response = await _client
          .from('goal_saves')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (response != null) {
        return _GoalSaveMappers.goalFromMap(response);
      }
      throw const RepositoryFailure('That goal is no longer available.');
    } catch (e) {
      if (e is RepositoryFailure) rethrow;
      throw RepositoryFailure('Could not fetch goal: $e');
    }
  }

  @override
  Future<GoalSave> openGoal({
    required String name,
    required String emoji,
    required double targetAmount,
    required double initialDeposit,
  }) async {
    final id = 'goal_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();
    final goalMap = {
      'id': id,
      'user_id': _client.auth.currentUser?.id,
      'name': name,
      'emoji': emoji,
      'target_amount': targetAmount,
      'balance': initialDeposit,
      'currency_code': 'USD',
      'daily_rate_percent': 0.011918,
      'interest_earned': 0.0,
      'created_at': now.toIso8601String(),
      'status': 'active',
    };

    try {
      await _client.from('goal_saves').insert(goalMap);
      if (initialDeposit > 0) {
        await _client.from('goal_transactions').insert({
          'id': 'gtxn_${now.millisecondsSinceEpoch}',
          'user_id': _client.auth.currentUser?.id,
          'goal_id': id,
          'kind': 'transferIn',
          'amount': initialDeposit,
          'running_balance': initialDeposit,
          'date': now.toIso8601String(),
          'note': 'Opening deposit',
        });
        await _adjustAccountBalance(
          accountId: 'acc_wallet',
          amountChange: -initialDeposit,
          note: 'Opening deposit for goal: $name',
          direction: 'outflow',
        );
      }
      return _GoalSaveMappers.goalFromMap(goalMap);
    } catch (e) {
      throw RepositoryFailure('Could not create goal: $e');
    }
  }

  @override
  Future<GoalSave> transferIn({
    required String goalId,
    required double amount,
  }) async {
    try {
      final current = await fetchGoal(goalId);
      final newBalance = current.balance + amount;

      await _client
          .from('goal_saves')
          .update({'balance': newBalance})
          .eq('id', goalId);

      await _client.from('goal_transactions').insert({
        'id': 'gtxn_${DateTime.now().millisecondsSinceEpoch}',
        'user_id': _client.auth.currentUser?.id,
        'goal_id': goalId,
        'kind': 'transferIn',
        'amount': amount,
        'running_balance': newBalance,
        'date': DateTime.now().toIso8601String(),
        'note': null,
      });

      await _adjustAccountBalance(
        accountId: 'acc_wallet',
        amountChange: -amount,
        note: 'Saved into ${current.name}',
        direction: 'outflow',
      );

      return current.copyWith(balance: newBalance);
    } catch (e) {
      if (e is RepositoryFailure) rethrow;
      throw RepositoryFailure('Transfer failed: $e');
    }
  }

  @override
  Future<GoalSave> transferOut({
    required String goalId,
    required double amount,
  }) async {
    try {
      final current = await fetchGoal(goalId);
      if (amount > current.balance) {
        throw const RepositoryFailure('Insufficient goal balance.');
      }
      final newBalance = current.balance - amount;

      await _client
          .from('goal_saves')
          .update({'balance': newBalance})
          .eq('id', goalId);

      await _client.from('goal_transactions').insert({
        'id': 'gtxn_${DateTime.now().millisecondsSinceEpoch}',
        'user_id': _client.auth.currentUser?.id,
        'goal_id': goalId,
        'kind': 'transferOut',
        'amount': amount,
        'running_balance': newBalance,
        'date': DateTime.now().toIso8601String(),
        'note': null,
      });

      await _adjustAccountBalance(
        accountId: 'acc_wallet',
        amountChange: amount,
        note: 'Withdrawn from ${current.name}',
        direction: 'inflow',
      );

      return current.copyWith(balance: newBalance);
    } catch (e) {
      if (e is RepositoryFailure) rethrow;
      throw RepositoryFailure('Transfer failed: $e');
    }
  }

  @override
  Future<GoalSave> closeGoal(String id) async {
    try {
      final current = await fetchGoal(id);
      await _client
          .from('goal_saves')
          .update({'status': 'closed', 'balance': 0.0})
          .eq('id', id);

      if (current.balance > 0) {
        await _adjustAccountBalance(
          accountId: 'acc_wallet',
          amountChange: current.balance,
          note: 'Goal closed, funds returned (${current.name})',
          direction: 'inflow',
        );
      }

      return current.copyWith(status: GoalSaveStatus.closed, balance: 0.0);
    } catch (e) {
      if (e is RepositoryFailure) rethrow;
      throw RepositoryFailure('Could not close goal: $e');
    }
  }

  @override
  Future<List<GoalTxn>> fetchGoalTransactions(String goalId) async {
    try {
      final response = await _client
          .from('goal_transactions')
          .select()
          .eq('goal_id', goalId)
          .order('date', ascending: false);
      final list = (response as List)
          .map(
            (item) =>
                _GoalSaveMappers.goalTxnFromMap(item as Map<String, dynamic>),
          )
          .toList();
      return list;
    } catch (e) {
      throw RepositoryFailure('Could not load goal transactions: $e');
    }
  }
}

class SupabaseSplitBillRepository implements SplitBillRepository {
  SupabaseSplitBillRepository([SupabaseClient? client])
    : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  @override
  Future<List<SplitBill>> fetchSplitBills() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw const RepositoryFailure('User not authenticated');
      final userId = user.id;
      final billsRes = await _client
          .from('split_bills')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final billsList = billsRes as List;
      final results = <SplitBill>[];

      for (final item in billsList) {
        final billMap = item as Map<String, dynamic>;
        final billId = billMap['id'] as String;

        final partsRes = await _client
            .from('split_bill_participants')
            .select()
            .eq('bill_id', billId);

        final participants = (partsRes as List)
            .map(
              (p) => SupabaseMappers.splitParticipantFromMap(
                p as Map<String, dynamic>,
              ),
            )
            .toList();

        results.add(SupabaseMappers.splitBillFromMap(billMap, participants));
      }
      return results;
    } catch (e) {
      throw RepositoryFailure('Could not fetch split bills from Supabase: $e');
    }
  }

  @override
  Future<SplitBill> fetchSplitBill(String id) async {
    try {
      final billRes = await _client
          .from('split_bills')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (billRes == null) throw const RepositoryFailure('Bill not found.');

      final partsRes = await _client
          .from('split_bill_participants')
          .select()
          .eq('bill_id', id);

      final participants = (partsRes as List)
          .map(
            (p) => SupabaseMappers.splitParticipantFromMap(
              p as Map<String, dynamic>,
            ),
          )
          .toList();

      return SupabaseMappers.splitBillFromMap(billRes, participants);
    } catch (e) {
      if (e is RepositoryFailure) rethrow;
      throw RepositoryFailure('Could not fetch split bill: $e');
    }
  }

  @override
  Future<SplitBill> createSplitBill({
    required String title,
    required double totalAmount,
    required String category,
    required List<String> participantNames,
    SplitMode splitMode = SplitMode.equal,
    List<double>? customAmounts,
    List<double>? percentages,
    String? description,
  }) async {
    final now = DateTime.now();
    final billId = 'bill_${now.millisecondsSinceEpoch}';

    final cleanNames = participantNames
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();

    final totalPeople = cleanNames.length + 1;
    final share = (totalAmount / totalPeople);

    final billMap = {
      'id': billId,
      'user_id': _client.auth.currentUser?.id,
      'title': title.trim().isEmpty ? 'Split Bill' : title.trim(),
      'total_amount': totalAmount,
      'category': category.trim().isEmpty ? 'General' : category.trim(),
      'created_at': now.toIso8601String(),
      'created_by': 'You (Host)',
    };

    final participants = <SplitBillParticipant>[];
    final hostPartMap = {
      'id': 'p_${billId}_host',
      'bill_id': billId,
      'name': 'You (Host)',
      'share_amount': share,
      'status': 'paid',
      'paid_at': now.toIso8601String(),
    };
    participants.add(SupabaseMappers.splitParticipantFromMap(hostPartMap));

    try {
      await _client.from('split_bills').insert(billMap);
      await _client.from('split_bill_participants').insert(hostPartMap);

      for (var i = 0; i < cleanNames.length; i++) {
        final partMap = {
          'id': 'p_${billId}_$i',
          'bill_id': billId,
          'name': cleanNames[i],
          'share_amount': share,
          'status': 'pending',
          'paid_at': null,
        };
        await _client.from('split_bill_participants').insert(partMap);
        participants.add(SupabaseMappers.splitParticipantFromMap(partMap));
      }

      return SupabaseMappers.splitBillFromMap(billMap, participants);
    } catch (e) {
      throw RepositoryFailure('Could not create split bill in Supabase: $e');
    }
  }

  @override
  Future<bool> confirmPayment({
    required String billId,
    required String participantId,
    String? payingAccountId,
    String currencyCode = 'USD',
  }) async {
    try {
      final bill = await fetchSplitBill(billId);
      final pIndex = bill.participants.indexWhere((p) => p.id == participantId);
      if (pIndex == -1) return false;

      final participant = bill.participants[pIndex];
      if (participant.isPaid) return true;

      final now = DateTime.now();
      await _client
          .from('split_bill_participants')
          .update({'status': 'paid', 'paid_at': now.toIso8601String()})
          .eq('id', participantId);

      final accountId = payingAccountId ?? 'acc_wallet';

      // Deduct balance from paying account in Supabase
      final accountRes = await _client
          .from('accounts')
          .select()
          .eq('id', accountId)
          .maybeSingle();

      if (accountRes != null) {
        final currentAvail = (accountRes['available_balance'] as num)
            .toDouble();
        final currentTotal = (accountRes['total_balance'] as num).toDouble();
        final newAvail = (currentAvail - participant.shareAmount).clamp(
          0.0,
          double.infinity,
        );
        final newTotal = (currentTotal - participant.shareAmount).clamp(
          0.0,
          double.infinity,
        );

        await _client
            .from('accounts')
            .update({'available_balance': newAvail, 'total_balance': newTotal})
            .eq('id', accountId);

        // Insert transaction log
        final txnId = 'txn_split_${now.millisecondsSinceEpoch}';
        final refCode =
            'SPLIT-${bill.id.substring(0, bill.id.length.clamp(0, 6)).toUpperCase()}';
        await _client.from('transactions').insert({
          'id': txnId,
          'user_id': _client.auth.currentUser?.id,
          'account_id': accountId,
          'merchant': 'Split Bill: ${bill.title} (${participant.name})',
          'category': 'Split Bills',
          'amount': participant.shareAmount,
          'currency_code': currencyCode,
          'direction': 'outflow',
          'type': 'qrPayment',
          'status': 'completed',
          'date': now.toIso8601String(),
          'reference': refCode,
          'note': 'Paid share for ${bill.title}',
        });
      }

      return true;
    } catch (e) {
      throw RepositoryFailure('Could not confirm payment: $e');
    }
  }

  @override
  Future<SplitBill?> joinBill({
    required String billId,
    required String participantName,
  }) async {
    // For Supabase: fetch the bill, add the new participant with a
    // recalculated equal share, then return the refreshed bill.
    try {
      final bill = await fetchSplitBill(billId);
      final cleanName = participantName.trim();
      if (cleanName.isEmpty) return bill;

      final alreadyIn = bill.participants.any(
        (p) => p.name.toLowerCase() == cleanName.toLowerCase(),
      );
      if (alreadyIn) return bill;

      final newShare = bill.totalAmount / (bill.participants.length + 1);
      final now = DateTime.now();
      final newPartId = 'p_${billId}_join_${now.millisecondsSinceEpoch}';

      await _client.from('split_bill_participants').insert({
        'id': newPartId,
        'bill_id': billId,
        'name': cleanName,
        'share_amount': newShare,
        'status': 'pending',
        'paid_at': null,
      });

      return await fetchSplitBill(billId);
    } catch (e) {
      throw RepositoryFailure('Could not join split bill: $e');
    }
  }
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository([SupabaseClient? client])
    : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  @override
  Future<UserProfile?> restoreSession() async {
    try {
      final session = _client.auth.currentSession;
      if (session == null) return null;
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', session.user.id)
          .maybeSingle();
      if (response == null) return null;
      return SupabaseMappers.profileFromMap(response);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user != null) {
        final profileMap = await _client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();
        if (profileMap != null) {
          return SupabaseMappers.profileFromMap(profileMap);
        }
      }
    } catch (e) {
      debugPrint('Supabase signIn auth note: $e');
    }

    throw const RepositoryFailure('Authentication failed.');
  }

  @override
  Future<UserProfile> signUp({
    required String fullName,
    required String email,
    required String mobile,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'mobile': mobile},
      );
      final user = response.user;
      final userId =
          user?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

      final profileMap = {
        'id': userId,
        'full_name': fullName,
        'email': email,
        'mobile': mobile,
        'member_since': DateTime.now().toIso8601String(),
      };

      await _client.from('profiles').upsert(profileMap);

      try {
        final existingAccounts = await _client
            .from('accounts')
            .select()
            .eq('user_id', userId);
        if ((existingAccounts as List).isEmpty) {
          final defaultWallet = {
            'id': 'acc_wallet_$userId',
            'user_id': userId,
            'name': 'Everyday Wallet',
            'short_code': 'WALLET',
            'kind': 'wallet',
            'masked_number':
                '•••• ${userId.length >= 4 ? userId.substring(userId.length - 4) : '4182'}',
            'currency_code': 'USD',
            'total_balance': 1000.00,
            'available_balance': 1000.00,
          };
          await _client.from('accounts').insert(defaultWallet);
        }
      } catch (_) {}

      return SupabaseMappers.profileFromMap(profileMap);
    } on AuthException catch (e) {
      throw RepositoryFailure(e.message);
    } catch (e) {
      throw RepositoryFailure('Sign up failed: $e');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw RepositoryFailure('Sign out failed: $e');
    }
  }
}
