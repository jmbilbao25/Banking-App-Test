import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/format/money.dart';
import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../../state/providers.dart';
import '../widgets/app_lock_confirm.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/money_form.dart';
import '../widgets/money_text.dart';
import '../widgets/states.dart';
import '../widgets/surfaces.dart';
import 'transaction_history_screen.dart' show txnPagingProvider;

/// Send money.
///
/// Requirement 16.1 puts a review between the details and the debit, so the
/// customer sees the recipient, the source, the amount, the fee and the total
/// before anything moves. The previous version sent straight from the form, so
/// the only thing between a typo and a completed transfer was the customer
/// re-reading their own input.
enum _Step { details, review }

class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  final _recipient = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();

  String? _selectedSourceId;
  _Step _step = _Step.details;
  bool _submitting = false;
  String? _formError;
  String? _amountError;
  String? _recipientError;

  /// Mock data: this build charges nothing to send money.
  static const _fee = 0.0;

  /// Requirement 16.5 caps the note at 60 characters.
  static const _noteLimit = 60;

  @override
  void dispose() {
    _recipient.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  double get _enteredAmount => double.tryParse(_amount.text.trim()) ?? 0;

  double _availableHere(Account source) => Money.convert(
    source.availableBalance,
    fromCurrency: source.currencyCode,
    toCurrency: ref.read(preferencesProvider).currencyCode,
  );

  /// Whether the review step may open.
  ///
  /// Requirements 16.4, 16.6 and 16.7 all say the next step is *kept disabled*,
  /// not that it complains when pressed. So this is evaluated on every keystroke
  /// and drives the control's enabled state, which also makes it consistent with
  /// the deposit screen rather than the two flows disagreeing about whether an
  /// empty form has a live primary action.
  bool _canReview(Account source) {
    final amount = _enteredAmount;
    return _recipient.text.trim().isNotEmpty &&
        amount > 0 &&
        amount <= _availableHere(source);
  }

  /// Requirement 16.6 asks for an inline message as well as a disabled control,
  /// so the customer is told why rather than left guessing at a dead button.
  /// Only the over balance case earns a message: an empty field has not made a
  /// mistake yet.
  String? _amountHint(Account source) {
    final amount = _enteredAmount;
    if (amount <= 0) return null;
    final available = _availableHere(source);
    if (amount <= available) return null;
    final code = ref.read(preferencesProvider).currencyCode;
    return 'That is more than your available balance of '
        '${Money.format(available, currencyCode: code)}.';
  }

  Future<void> _confirm(Account source) async {
    if (_submitting) return;

    final preferences = ref.read(preferencesProvider);
    final symbol = preferences.activeCurrency.symbol;
    final amount = _enteredAmount;
    final recipient = _recipient.text.trim();

    // Requirement 16.9: App_Lock confirms before Repository_Layer performs the
    // transfer. Nothing has moved yet, so a refusal returns to the review.
    final confirmed = await confirmWithAppLock(
      context,
      ref,
      reason: 'Confirm sending $symbol${amount.toStringAsFixed(2)} to $recipient.',
    );
    if (!mounted || !confirmed) return;

    setState(() {
      _submitting = true;
      _formError = null;
    });

    final baseAmount = Money.convert(
      amount,
      fromCurrency: preferences.currencyCode,
      toCurrency: 'USD',
    );

    try {
      final note = _note.text.trim();
      await ref.read(accountRepositoryProvider).transfer(
        fromAccountId: source.id,
        recipient: recipient,
        amount: baseAmount,
        note: note.isEmpty ? null : note,
      );

      ref.invalidate(accountsProvider);
      ref.invalidate(accountProvider(source.id));
      ref.invalidate(transactionsProvider);
      ref.invalidate(txnPagingProvider);
      if (!mounted) return;

      // Cleared before the receipt opens. A busy PrimaryAction spins an
      // indicator, which never settles, so leaving it busy behind a modal sheet
      // means the screen holds a permanent animation and pumpAndSettle can never
      // return. The sheet is not dismissible except by its own control, so a
      // second submission is still impossible.
      setState(() => _submitting = false);

      await MoneyOutcomeSheet.show(
        context,
        succeeded: true,
        heading: 'Money sent',
        detail:
            '${Money.format(amount, currencyCode: preferences.currencyCode)} '
            'is on its way to $recipient from ${source.name}.',
      );
      if (!mounted) return;
      Navigator.of(context).maybePop();
    } on RepositoryFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        // Requirement 16.11: the reason, plus the fact that nothing moved.
        _formError = '${failure.message} No money left ${source.name}.';
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _formError =
            'That transfer did not go through. No money left ${source.name}.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    final source = accounts.hasValue && accounts.requireValue.isNotEmpty
        ? _resolveSource(accounts.requireValue)
        : null;

    return BrandScreenScaffold(
      title: 'Send money',
      subtitle: _step == _Step.details
          ? 'Choose an account, then say who you are paying.'
          : 'Check these details before the money moves.',
      header: source == null ? null : AccountContextCard(account: source),
      children: [
        // The whole form is one Async_Surface, so requirement 3 covers it: a
        // shape matched skeleton while the accounts load, an empty state with one
        // action, and an inline failure with retry.
        AsyncSection<List<Account>>(
          value: accounts,
          onRetry: () => ref.invalidate(accountsProvider),
          skeleton: const _FormSkeleton(),
          isEmpty: (rows) => rows.isEmpty,
          empty: EmptyStateView(
            icon: Icons.account_balance_rounded,
            heading: 'No account to send from',
            message: 'Open an account before you send money.',
            actionLabel: 'Go back',
            onAction: () => Navigator.of(context).maybePop(),
          ),
          builder: (rows) {
            final active = _resolveSource(rows);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _step == _Step.details
                  ? _detailsStep(rows, active)
                  : _reviewStep(active),
            );
          },
        ),
      ],
    );
  }

  Account _resolveSource(List<Account> rows) {
    _selectedSourceId ??= rows.first.id;
    return rows.firstWhere(
      (account) => account.id == _selectedSourceId,
      orElse: () => rows.first,
    );
  }

  List<Widget> _detailsStep(List<Account> accounts, Account source) => [
    const SheetFieldLabel('From account'),
    AccountSelectField(
      accounts: accounts,
      selectedId: source.id,
      onChanged: (id) => setState(() {
        _selectedSourceId = id;
        _amountError = null;
      }),
    ),
    const SizedBox(height: Space.x5),
    const SheetFieldLabel('Send to'),
    SheetField(
      controller: _recipient,
      hint: 'Name, account number or mobile',
      errorText: _recipientError,
      textInputAction: TextInputAction.next,
      onChanged: (_) => setState(() {
        _recipientError = null;
        _formError = null;
      }),
    ),
    const SizedBox(height: Space.x5),
    const SheetFieldLabel('Amount'),
    AmountField(
      controller: _amount,
      errorText: _amountError ?? _amountHint(source),
      onChanged: (_) => setState(() {
        _amountError = null;
        _formError = null;
      }),
    ),
    const SizedBox(height: Space.x5),
    const SheetFieldLabel('Note', optional: true),
    SheetField(
      controller: _note,
      hint: 'What is this for?',
      maxLength: _noteLimit,
      textInputAction: TextInputAction.done,
    ),
    if (_formError != null) ...[
      const SizedBox(height: Space.x4),
      InlineFormError(_formError!),
    ],
    const SizedBox(height: Space.x6),
    PrimaryAction(
      label: 'Review',
      icon: Icons.arrow_forward_rounded,
      // Disabled, not validate on press, per requirements 16.4, 16.6 and 16.7.
      onPressed: _canReview(source)
          ? () => setState(() => _step = _Step.review)
          : null,
    ),
  ];

  List<Widget> _reviewStep(Account source) {
    final tokens = context.tokens;
    final code = ref.read(preferencesProvider).currencyCode;
    final amount = _enteredAmount;
    final total = amount + _fee;
    final note = _note.text.trim();

    return [
      Text(
        'Review',
        style: AppType.titleLarge.copyWith(color: tokens.textPrimary),
      ),
      const SizedBox(height: Space.x4),
      MoneyReviewRow(
        label: 'To',
        value: Text(
          _recipient.text.trim(),
          style: AppType.titleSmall.copyWith(color: tokens.textPrimary),
        ),
      ),
      MoneyReviewRow(
        label: 'From',
        value: Text(
          source.name,
          style: AppType.bodyMedium.copyWith(color: tokens.textPrimary),
        ),
      ),
      MoneyReviewRow(
        label: 'Amount',
        value: MoneyText(
          amount,
          currencyCode: code,
          style: AppType.numericMedium,
          maskable: false,
          label: 'Amount',
        ),
      ),
      MoneyReviewRow(
        label: 'Fee',
        value: MoneyText(
          _fee,
          currencyCode: code,
          style: AppType.numericMedium,
          color: tokens.textSecondary,
          maskable: false,
          label: 'Fee',
        ),
      ),
      if (note.isNotEmpty)
        MoneyReviewRow(
          label: 'Note',
          value: Flexible(
            child: Text(
              note,
              textAlign: TextAlign.right,
              style: AppType.bodyMedium.copyWith(color: tokens.textPrimary),
            ),
          ),
        ),
      const SizedBox(height: Space.x2),
      const SoftDivider(inset: 0),
      MoneyReviewRow(
        label: 'Total to debit',
        emphasised: true,
        value: MoneyText(
          total,
          currencyCode: code,
          style: AppType.numericLarge,
          maskable: false,
          label: 'Total to debit',
        ),
      ),
      if (_formError != null) ...[
        const SizedBox(height: Space.x4),
        InlineFormError(_formError!),
      ],
      const SizedBox(height: Space.x6),
      PrimaryAction(
        label: 'Send money',
        busy: _submitting,
        icon: Icons.lock_rounded,
        onPressed: () => _confirm(source),
      ),
      const SizedBox(height: Space.x2),
      SizedBox(
        width: double.infinity,
        height: Layout.minTapTarget,
        child: TextButton(
          onPressed: _submitting
              ? null
              : () => setState(() => _step = _Step.details),
          child: const Text('Edit details'),
        ),
      ),
    ];
  }
}

/// Shape matched to the details step: four label and field pairs, then the
/// action, per requirement 3.1.
class _FormSkeleton extends StatelessWidget {
  const _FormSkeleton();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var field = 0; field < 4; field++) ...[
        const SkeletonBlock(width: 96, height: 12),
        const SizedBox(height: Space.x2),
        const SkeletonBlock(height: 56, radius: AppRadius.md),
        const SizedBox(height: Space.x5),
      ],
      const SkeletonBlock(height: 52, radius: AppRadius.pill),
    ],
  );
}
