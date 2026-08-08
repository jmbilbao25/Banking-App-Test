import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../data/mock_time_deposit_repository.dart';
import '../../domain/time_deposit_model.dart';
import '../widgets/money_text.dart';
import '../widgets/pressable.dart';

/// The open a time deposit flow.
///
/// Carries Req 21.3 (four terms, each with its own rate), Req 21.4 (projected
/// interest and maturity date shown before confirming), Req 21.6 (a principal
/// under the minimum states that minimum and keeps confirm disabled), and
/// Req 21.10 (the mock rate statement).
class OpenTimeDepositSheet extends ConsumerStatefulWidget {
  const OpenTimeDepositSheet({super.key});

  @override
  ConsumerState<OpenTimeDepositSheet> createState() =>
      _OpenTimeDepositSheetState();
}

class _OpenTimeDepositSheetState extends ConsumerState<OpenTimeDepositSheet> {
  final TextEditingController _principal = TextEditingController();

  TimeDepositTerm _term = TimeDepositRates.defaultTerm;
  bool _submitting = false;
  String? _failure;

  @override
  void dispose() {
    _principal.dispose();
    super.dispose();
  }

  double get _amount => double.tryParse(_principal.text.trim()) ?? 0;

  bool get _hasEntry => _principal.text.trim().isNotEmpty;

  /// Req 21.6: below the minimum is the one condition that blocks confirm.
  bool get _belowMinimum =>
      _hasEntry && _amount < TimeDepositRates.minimumPrincipal;

  bool get _canConfirm =>
      _hasEntry && _amount >= TimeDepositRates.minimumPrincipal;

  DateTime get _startDate => ref.read(timeDepositClockProvider)();

  DateTime get _maturityDate =>
      timeDepositMaturityDate(_startDate, _term.months);

  double get _projectedInterest => timeDepositInterest(
    principal: _amount,
    annualRate: _term.annualRate,
    termMonths: _term.months,
  );

  Future<void> _confirm() async {
    // Req 3.7: a submitting control rejects further activation.
    if (_submitting || !_canConfirm) return;
    setState(() {
      _submitting = true;
      _failure = null;
    });
    try {
      await ref
          .read(timeDepositRepositoryProvider)
          .openTimeDeposit(principal: _amount, termMonths: _term.months);
      ref.invalidate(timeDepositsProvider);
      ref.invalidate(timeDepositTotalPrincipalProvider);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on TimeDepositFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _failure = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final insets = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: Container(
        decoration: BoxDecoration(
          color: tokens.background,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              Space.x5,
              Space.x5,
              Space.x5,
              Space.x6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Open a time deposit',
                    style: AppType.headlineLarge.copyWith(
                      color: tokens.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: Space.x2),
                Text(
                  'Lock a principal for a fixed term and collect the interest '
                  'at maturity.',
                  style: AppType.bodyMedium.copyWith(
                    color: tokens.textSecondary,
                  ),
                ),
                const SizedBox(height: Space.x5),

                // ---- Principal -------------------------------------------
                Text(
                  'Principal',
                  style: AppType.labelMedium.copyWith(
                    color: tokens.textSecondary,
                  ),
                ),
                const SizedBox(height: Space.x2),
                TextField(
                  controller: _principal,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  style: AppType.numericLarge.copyWith(
                    color: tokens.textPrimary,
                  ),
                  decoration: InputDecoration(
                    prefixText: Money.symbolFor('USD'),
                    prefixStyle: AppType.numericLarge.copyWith(
                      color: tokens.textSecondary,
                    ),
                    hintText: '0.00',
                    errorText: _belowMinimum ? _minimumMessage : null,
                  ),
                  onChanged: (_) => setState(() => _failure = null),
                ),

                const SizedBox(height: Space.x5),

                // ---- Terms (Req 21.3) ------------------------------------
                Text(
                  'Term',
                  style: AppType.labelMedium.copyWith(
                    color: tokens.textSecondary,
                  ),
                ),
                const SizedBox(height: Space.x3),
                Wrap(
                  spacing: Space.x3,
                  runSpacing: Space.x3,
                  children: [
                    for (final term in TimeDepositRates.terms)
                      _TermChip(
                        term: term,
                        selected: term.months == _term.months,
                        onTap: () => setState(() => _term = term),
                      ),
                  ],
                ),

                const SizedBox(height: Space.x5),

                // ---- Preview (Req 21.4) ----------------------------------
                _PreviewCard(
                  term: _term,
                  principal: _amount,
                  projectedInterest: _projectedInterest,
                  maturityDate: _maturityDate,
                  hasEntry: _hasEntry,
                ),

                if (_failure != null) ...[
                  const SizedBox(height: Space.x4),
                  Text(
                    _failure!,
                    style: AppType.bodySmall.copyWith(color: tokens.error),
                  ),
                ],

                const SizedBox(height: Space.x5),

                // ---- Confirm (Req 3.7) -----------------------------------
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submitting || !_canConfirm ? null : _confirm,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(Layout.minTapTarget),
                    ),
                    child: _submitting
                        ? SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                tokens.textOnBrand,
                              ),
                            ),
                          )
                        : const Text('Confirm deposit'),
                  ),
                ),

                const SizedBox(height: Space.x4),

                // ---- Req 21.10 -------------------------------------------
                Text(
                  TimeDepositRates.mockRateStatement,
                  style: AppType.bodySmall.copyWith(
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Req 21.6: the inline message states the minimum itself.
  String get _minimumMessage =>
      'The minimum principal is '
      '${Money.format(TimeDepositRates.minimumPrincipal)}.';
}

// ---------------------------------------------------------------------------
// Term chip
// ---------------------------------------------------------------------------

class _TermChip extends StatelessWidget {
  const _TermChip({
    required this.term,
    required this.selected,
    required this.onTap,
  });

  final TimeDepositTerm term;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Pressable(
      onTap: onTap,
      borderRadius: AppRadius.md,
      semanticLabel:
          '${term.label} term at ${term.annualRate.toStringAsFixed(2)} '
          'percent per year${selected ? ', selected' : ''}',
      child: Container(
        constraints: const BoxConstraints(minWidth: 108),
        padding: const EdgeInsets.symmetric(
          horizontal: Space.x4,
          vertical: Space.x3,
        ),
        decoration: BoxDecoration(
          color: selected ? tokens.interactiveSecondary : tokens.surface,
          borderRadius: AppRadius.all(AppRadius.md),
          border: Border.all(
            color: selected ? tokens.accent : tokens.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              term.label,
              style: AppType.titleSmall.copyWith(color: tokens.textPrimary),
            ),
            const SizedBox(height: Space.x1),
            Text(
              term.rateLabel,
              style: AppType.labelSmall.copyWith(
                color: selected ? tokens.accent : tokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Preview card (Req 21.4)
// ---------------------------------------------------------------------------

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.term,
    required this.principal,
    required this.projectedInterest,
    required this.maturityDate,
    required this.hasEntry,
  });

  final TimeDepositTerm term;
  final double principal;
  final double projectedInterest;
  final DateTime maturityDate;
  final bool hasEntry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(Space.x4),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: AppRadius.all(AppRadius.lg),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Before you confirm',
            style: AppType.labelMedium.copyWith(color: tokens.textSecondary),
          ),
          const SizedBox(height: Space.x3),
          _PreviewRow(
            label: 'Projected interest',
            value: MoneyText(
              hasEntry ? projectedInterest : 0,
              style: AppType.numericMedium,
              color: tokens.success,
              label: 'Projected interest at maturity',
            ),
          ),
          _PreviewRow(
            label: 'Maturity date',
            value: Text(
              Dates.shortDay(maturityDate),
              style: AppType.numericSmall.copyWith(color: tokens.textPrimary),
            ),
          ),
          _PreviewRow(
            label: 'Total at maturity',
            value: MoneyText(
              hasEntry ? roundMoney(principal + projectedInterest) : 0,
              style: AppType.numericMedium,
              label: 'Total at maturity',
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.x2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: AppType.bodyMedium.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: Space.x3),
        value,
      ],
    ),
  );
}
