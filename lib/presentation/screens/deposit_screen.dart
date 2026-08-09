import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/format/money.dart';
import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../../state/providers.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/money_form.dart';
import '../widgets/money_text.dart';
import '../widgets/pressable.dart';
import '../widgets/states.dart';
import '../widgets/surfaces.dart';
import 'transaction_history_screen.dart' show txnPagingProvider;

/// Add money.
///
/// Requirement 17.1 asks for three things: a destination account, a funding
/// source and an amount. The previous version collected two of them, so the
/// screen never said where the money was coming from, and it built its own
/// dropdown, its own field styling, its own navy button and its own receipt
/// dialog rather than reading any of them from the design system. It is now the
/// sibling of Send money: the same brand region, the same content sheet, the
/// same field vocabulary and the same outcome sheet.
///
/// There is no separate review step. A deposit is a credit, so nothing can leave
/// the account by mistake, and App_Lock is not asked for the same reason.
class DepositScreen extends ConsumerStatefulWidget {
  const DepositScreen({super.key});

  @override
  ConsumerState<DepositScreen> createState() => _DepositScreenState();
}

/// One place money can arrive from.
///
/// Mock data (Req 6.9): this build has no card network, no open banking link and
/// no agent network behind it. Every entry below is invented, the masked
/// identifiers included, and choosing one changes nothing except the copy on the
/// receipt.
class _FundingSource {
  const _FundingSource({
    required this.id,
    required this.name,
    required this.masked,
    required this.icon,
  });

  final String id;
  final String name;

  /// Masked identifier, shown so the choice reads as a real instrument.
  final String masked;
  final IconData icon;
}

/// Mock data (Req 6.9): invented funding sources, not linked instruments.
const _fundingSources = <_FundingSource>[
  _FundingSource(
    id: 'src_linked_bank',
    name: 'Linked bank account',
    masked: '\u2022\u2022\u2022\u2022 8842',
    icon: Icons.account_balance_rounded,
  ),
  _FundingSource(
    id: 'src_debit_card',
    name: 'Debit card',
    masked: '\u2022\u2022\u2022\u2022 4417',
    icon: Icons.credit_card_rounded,
  ),
  _FundingSource(
    id: 'src_cash_agent',
    name: 'Cash agent',
    masked: 'Agent 20713',
    icon: Icons.storefront_rounded,
  ),
];

class _DepositScreenState extends ConsumerState<DepositScreen> {
  final _amount = TextEditingController();

  String? _selectedAccountId;
  String _fundingSourceId = _fundingSources.first.id;
  bool _submitting = false;
  String? _formError;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double get _enteredAmount => double.tryParse(_amount.text.trim()) ?? 0;

  /// Requirement 17.3: the confirm control is disabled, not merely complaining,
  /// until the amount is a figure above zero.
  bool get _amountIsValid => _enteredAmount > 0;

  _FundingSource get _fundingSource => _fundingSources.firstWhere(
    (source) => source.id == _fundingSourceId,
    orElse: () => _fundingSources.first,
  );

  Account _resolveDestination(List<Account> rows) {
    _selectedAccountId ??= rows.first.id;
    return rows.firstWhere(
      (account) => account.id == _selectedAccountId,
      orElse: () => rows.first,
    );
  }

  /// Requirement 17.2: the credit lands on the destination account, a Deposit
  /// transaction is recorded, and both are persisted by the repository. The read
  /// providers are invalidated afterwards so the dashboard, the account and the
  /// ledger all show the new figure.
  Future<void> _confirm(Account destination) async {
    if (_submitting || !_amountIsValid) return;

    final preferences = ref.read(preferencesProvider);
    final amount = _enteredAmount;
    final funding = _fundingSource;

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
      await ref
          .read(accountRepositoryProvider)
          .deposit(accountId: destination.id, amount: baseAmount);

      ref.invalidate(accountsProvider);
      ref.invalidate(accountProvider(destination.id));
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
        heading: 'Money added',
        detail:
            '${Money.format(amount, currencyCode: preferences.currencyCode)} '
            'is in ${destination.name}, funded from ${funding.name}.',
      );
      if (!mounted) return;
      Navigator.of(context).maybePop();
    } on RepositoryFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        // The repository's own copy, which is written for the customer, plus the
        // reassurance. Never the exception itself.
        _formError = '${failure.message} No money moved.';
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _formError = 'That deposit did not go through. No money moved.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    final destination = accounts.hasValue && accounts.requireValue.isNotEmpty
        ? _resolveDestination(accounts.requireValue)
        : null;

    return BrandScreenScaffold(
      title: 'Add money',
      subtitle: 'Choose where the money lands and how you are funding it.',
      header: destination == null
          ? null
          : AccountContextCard(account: destination),
      children: [
        // Requirement 3.1, 3.3 and 3.4: one Async_Surface over the accounts, so
        // the form has a shape matched skeleton, an empty state with a single
        // action, and an inline failure with retry.
        AsyncSection<List<Account>>(
          value: accounts,
          onRetry: () => ref.invalidate(accountsProvider),
          skeleton: const _FormSkeleton(),
          isEmpty: (rows) => rows.isEmpty,
          empty: EmptyStateView(
            icon: Icons.account_balance_rounded,
            heading: 'No account to deposit into',
            message: 'Open an account before you add money.',
            actionLabel: 'Go back',
            onAction: () => Navigator.of(context).maybePop(),
          ),
          builder: (rows) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _form(rows, _resolveDestination(rows)),
          ),
        ),
      ],
    );
  }

  List<Widget> _form(List<Account> accounts, Account destination) {
    final code = ref.watch(preferencesProvider).currencyCode;
    final amount = _enteredAmount;
    final availableHere = Money.convert(
      destination.availableBalance,
      fromCurrency: destination.currencyCode,
      toCurrency: code,
    );

    return [
      // "To account", not "Deposit into". The same dropdown, holding the same
      // account, was labelled three different ways across the three money
      // screens. Source and destination now differ by one word so the pairing
      // is obvious: Send money reads "From account", this reads "To account".
      const SheetFieldLabel('To account'),
      AccountSelectField(
        accounts: accounts,
        selectedId: destination.id,
        onChanged: (id) => setState(() => _selectedAccountId = id),
      ),
      const SizedBox(height: Space.x5),
      const SheetFieldLabel('Funding source'),
      // Requirement 17.1, the part that was missing: where the money is coming
      // from. Rows rather than a second dropdown, so the choice is one tap and
      // the masked identifier is readable without opening anything.
      for (final source in _fundingSources) ...[
        _FundingSourceRow(
          key: ValueKey(source.id),
          source: source,
          selected: source.id == _fundingSourceId,
          onTap: _submitting
              ? null
              : () => setState(() => _fundingSourceId = source.id),
        ),
        const SizedBox(height: Space.x2),
      ],
      // The "these are mock data" note that used to sit here is gone. The spec
      // asks for that statement in exactly three places: the Crypto rates
      // (20.8), the Time Deposit rates (21.10), and the About section, which
      // covers the whole application (25.9). A fourth copy against the funding
      // rows read as a note to the team left in shipping chrome.
      const SizedBox(height: Space.x4),
      const SheetFieldLabel('Amount'),
      AmountField(
        controller: _amount,
        // No error copy here. Requirement 17.3 asks for a disabled control, and
        // a field that scolds the customer for not having typed yet would be
        // both louder and less useful than a button that is plainly not ready.
        onChanged: (_) => setState(() => _formError = null),
      ),
      const SizedBox(height: Space.x4),
      const SoftDivider(inset: 0),
      // No separate review step, so the one figure a review would have added is
      // stated here instead: what the account holds once this lands. The amount
      // itself is not repeated, because it is in the field directly above.
      MoneyReviewRow(
        label: 'Balance after deposit',
        emphasised: true,
        value: MoneyText(
          availableHere + amount,
          currencyCode: code,
          style: AppType.numericMedium,
          maskable: false,
          label: 'Balance after deposit',
        ),
      ),
      if (_formError != null) ...[
        const SizedBox(height: Space.x4),
        InlineFormError(_formError!),
      ],
      const SizedBox(height: Space.x6),
      PrimaryAction(
        label: 'Confirm deposit',
        icon: Icons.arrow_downward_rounded,
        busy: _submitting,
        // Requirement 17.3: null while the amount is zero, negative or empty,
        // which renders the control disabled rather than tappable and rejecting.
        onPressed: _amountIsValid ? () => _confirm(destination) : null,
        hint: 'Enter an amount to continue.',
      ),
    ];
  }
}

/// One selectable funding source.
///
/// Selection is carried by the accent border, the tinted leading badge and the
/// filled check, so it survives both themes and does not rely on colour alone.
class _FundingSourceRow extends StatelessWidget {
  const _FundingSourceRow({
    required this.source,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final _FundingSource source;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Semantics(
      selected: selected,
      child: Pressable(
        onTap: onTap,
        borderRadius: AppRadius.md,
        child: Container(
          width: double.infinity,
          // Padding rather than a fixed height, so the row grows with the text
          // scale instead of clipping it (Req 4.3).
          padding: const EdgeInsets.symmetric(
            horizontal: Space.x4,
            vertical: Space.x3,
          ),
          decoration: BoxDecoration(
            color: selected ? tokens.interactiveSecondary : tokens.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? tokens.accent : tokens.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: Space.x10,
                height: Space.x10,
                decoration: BoxDecoration(
                  color: selected
                      ? tokens.accent.withValues(alpha: 0.16)
                      : tokens.surfaceRaised,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  source.icon,
                  size: 20,
                  color: selected ? tokens.accent : tokens.textSecondary,
                ),
              ),
              const SizedBox(width: Space.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.name,
                      style: AppType.titleSmall.copyWith(
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: Space.x1),
                    Text(
                      source.masked,
                      style: AppType.numericSmall.copyWith(
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.x3),
              // Radio, not a tick. Exactly one funding source can be chosen,
              // and a filled checkmark against hollow circles told the user
              // this was a multi-select list they could add a second row to.
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 22,
                color: selected ? tokens.accent : tokens.border,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shape matched to the form: account picker, three funding rows, amount, then
/// the action, per requirement 3.1.
class _FormSkeleton extends StatelessWidget {
  const _FormSkeleton();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SkeletonBlock(width: 96, height: 12),
      const SizedBox(height: Space.x2),
      const SkeletonBlock(height: 56, radius: AppRadius.md),
      const SizedBox(height: Space.x5),
      const SkeletonBlock(width: 112, height: 12),
      const SizedBox(height: Space.x2),
      for (var row = 0; row < _fundingSources.length; row++) ...[
        const SkeletonBlock(height: 64, radius: AppRadius.md),
        const SizedBox(height: Space.x2),
      ],
      const SizedBox(height: Space.x4),
      const SkeletonBlock(width: 96, height: 12),
      const SizedBox(height: Space.x2),
      const SkeletonBlock(height: 56, radius: AppRadius.md),
      const SizedBox(height: Space.x6),
      const SkeletonBlock(height: 52, radius: AppRadius.pill),
    ],
  );
}
