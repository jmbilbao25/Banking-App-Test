import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../domain/time_deposit_model.dart';
import '../../state/providers.dart';
import '../widgets/brand.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/money_text.dart';
import '../widgets/pressable.dart';
import '../widgets/states.dart';
import '../widgets/surfaces.dart';
import 'open_time_deposit_sheet.dart';

/// Time Deposit, the sibling of Savings.
///
/// Covers Req 21.1 (every field on every deposit), Req 21.2 (total principal as
/// one large GeistMono figure), Req 21.7 (days remaining while a deposit is
/// running), Req 21.8 (the early withdrawal quote before the withdrawal), and
/// Req 21.10 (the mock rate statement).
class TimeDepositScreen extends ConsumerWidget {
  const TimeDepositScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deposits = ref.watch(timeDepositsProvider);
    final totalPrincipal = ref.watch(timeDepositTotalPrincipalProvider);
    final now = ref.watch(timeDepositClockProvider)();

    // The same header every other screen uses. This screen previously had a
    // plain AppBar plus a full bleed square cornered gradient slab below it,
    // which turned the brand gradient from chrome into a component and made the
    // screen read as a different product on a contact sheet. The total principal
    // is now the standard inset hero card inside the brand region.
    //
    // The floating "Open deposit" button is gone. It overlapped the second
    // deposit card, hiding its maturity date and interest and clipping the days
    // remaining line, and it was a second label for the intent the header's
    // "New deposit" already carries, which requirement 25.8 forbids.
    return BrandScreenScaffold(
      title: 'Time deposit',
      subtitle: 'Lock a principal for a fixed term and collect the interest.',
      header: _TotalPrincipalCard(totalPrincipal: totalPrincipal),
      children: [
        SectionHeader(
          title: 'Placed deposits',
          // Hidden while the list is empty, because the empty state already
          // offers this exact action. Two identical controls on one screen is the
          // same problem as two labels for one intent, seen from the other side.
          action: (!deposits.hasValue || deposits.requireValue.isEmpty)
              ? null
              : TextButton.icon(
                  onPressed: () => openTimeDepositFlow(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New deposit'),
                ),
        ),

        // Req 3.1, 3.3, 3.4: one async surface with a shape matched skeleton, an
        // empty state, and inline retry.
        AsyncSection<List<TimeDeposit>>(
          value: deposits,
          onRetry: () {
            ref.invalidate(timeDepositsProvider);
            ref.invalidate(timeDepositTotalPrincipalProvider);
          },
          skeleton: const _DepositSkeleton(),
          isEmpty: (rows) => rows.isEmpty,
          empty: EmptyStateView(
            icon: Icons.lock_clock_rounded,
            heading: 'No time deposits yet',
            message:
                'Lock a principal for a fixed term and collect the interest at '
                'maturity.',
            actionLabel: 'New deposit',
            onAction: () => openTimeDepositFlow(context),
          ),
          builder: (rows) => Column(
            children: [
              for (final deposit in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.x3),
                  child: _DepositCard(deposit: deposit, now: now),
                ),
            ],
          ),
        ),

        const SizedBox(height: Space.x4),
        const _MockRateNotice(),
      ],
    );
  }
}

/// Total principal placed, as the inset hero card the money screens use for the
/// account balance, so the same role reads at the same size across the app.
class _TotalPrincipalCard extends StatelessWidget {
  const _TotalPrincipalCard({required this.totalPrincipal});

  final AsyncValue<double> totalPrincipal;

  @override
  Widget build(BuildContext context) {
    final onBrand = context.tokens.textOnBrand;
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total principal placed',
            style: AppType.labelMedium.copyWith(
              color: onBrand.withValues(alpha: 0.76),
            ),
          ),
          const SizedBox(height: Space.x2),
          totalPrincipal.when(
            loading: () => const SkeletonBlock(
              width: 180,
              height: 36,
              radius: AppRadius.sm,
            ),
            error: (_, _) => Text(
              Money.maskGlyphs,
              style: AppType.numericHero.copyWith(color: onBrand),
            ),
            // numericHero, matching the dashboard balance, because this figure is
            // the subject of its screen. The money screens use numericLarge for
            // their account card because there the balance is context for a
            // transfer rather than the thing being looked at. Two roles, two
            // steps, applied consistently, rather than one role at three sizes.
            data: (amount) => MoneyText(
              amount,
              style: AppType.numericHero,
              color: onBrand,
              label: 'Total principal placed',
            ),
          ),
          const SizedBox(height: Space.x3),
          Text(
            TimeDepositRates.mockRateStatement,
            style: AppType.bodySmall.copyWith(
              color: onBrand.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the create flow. Shared by the header action, the empty state, and the
/// floating action button, so all three land in the same place.
Future<void> openTimeDepositFlow(BuildContext context) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const OpenTimeDepositSheet(),
    ).then((_) {});

class _DepositCard extends StatelessWidget {
  const _DepositCard({required this.deposit, required this.now});

  final TimeDeposit deposit;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final running = deposit.isActive && !deposit.hasReachedMaturity(now);
    final days = deposit.daysRemaining(now);

    return Pressable(
      onTap: running ? () => _openWithdrawSheet(context) : null,
      isButton: running,
      semanticLabel:
          '${deposit.termMonths} month time deposit, principal '
          '${Money.spoken(deposit.principal)}, '
          '${deposit.annualRate.toStringAsFixed(2)} percent per year, '
          'matures ${Dates.shortDay(deposit.maturityDate)}'
          '${running ? ', $days days remaining' : ', ${deposit.status.label}'}',
      borderRadius: AppRadius.lg,
      child: Container(
        padding: const EdgeInsets.all(Space.x4),
        decoration: BoxDecoration(
          color: tokens.surfaceRaised,
          borderRadius: AppRadius.all(AppRadius.lg),
          border: Border.all(color: tokens.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: tokens.interactiveSecondary,
                    borderRadius: AppRadius.all(AppRadius.sm),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.lock_clock_rounded,
                    size: 22,
                    color: tokens.accent,
                  ),
                ),
                const SizedBox(width: Space.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Req 21.1: principal, as a monetary figure.
                      MoneyText(
                        deposit.principal,
                        style: AppType.numericLarge,
                        label: 'Principal',
                      ),
                      Text(
                        'Principal in ${deposit.accountName}',
                        style: AppType.bodySmall.copyWith(
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Space.x3),
                StatusPill(
                  label: deposit.status.label,
                  color: switch (deposit.status) {
                    TimeDepositStatus.active => tokens.info,
                    TimeDepositStatus.matured => tokens.success,
                    TimeDepositStatus.withdrawnEarly => tokens.warning,
                  },
                ),
              ],
            ),

            const SizedBox(height: Space.x3),
            const SoftDivider(inset: 0),
            const SizedBox(height: Space.x1),

            // Req 21.1: annual rate, term, start date, maturity date, and
            // projected interest at maturity.
            _FieldRow(
              label: 'Annual rate',
              child: Text(
                '${deposit.annualRate.toStringAsFixed(2)}% per year',
                style: AppType.numericSmall.copyWith(color: tokens.textPrimary),
              ),
            ),
            _FieldRow(
              label: 'Term',
              child: Text(
                '${deposit.termMonths} months',
                style: AppType.numericSmall.copyWith(color: tokens.textPrimary),
              ),
            ),
            _FieldRow(
              label: 'Start date',
              child: Text(
                Dates.shortDay(deposit.startDate),
                style: AppType.numericSmall.copyWith(color: tokens.textPrimary),
              ),
            ),
            _FieldRow(
              label: 'Maturity date',
              child: Text(
                Dates.shortDay(deposit.maturityDate),
                style: AppType.numericSmall.copyWith(color: tokens.textPrimary),
              ),
            ),
            _FieldRow(
              label: 'Interest at maturity',
              child: MoneyText(
                deposit.projectedInterest,
                style: AppType.numericSmall,
                color: tokens.success,
                label: 'Interest at maturity',
              ),
            ),

            // Req 21.7: days remaining while the deposit is still running.
            if (running) ...[
              const SizedBox(height: Space.x3),
              _DaysRemainingBar(deposit: deposit, days: days),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openWithdrawSheet(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => EarlyWithdrawalSheet(deposit: deposit, now: now),
      );
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    // No fixed height, so nothing clips at text scale 1.3 (Req 4.3).
    padding: const EdgeInsets.symmetric(vertical: Space.x2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: AppType.bodySmall.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: Space.x3),
        child,
      ],
    ),
  );
}

class _DaysRemainingBar extends StatelessWidget {
  const _DaysRemainingBar({required this.deposit, required this.days});

  final TimeDeposit deposit;
  final int days;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final total = deposit.maturityDate
        .difference(deposit.startDate)
        .inDays
        .clamp(1, 1 << 30);
    final elapsed = (total - days).clamp(0, total);
    final progress = (elapsed / total).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: AppRadius.all(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: tokens.border,
                  valueColor: AlwaysStoppedAnimation<Color>(tokens.accent),
                ),
              ),
            ),
            const SizedBox(width: Space.x3),
            Text(
              // Req 21.7.
              '$days ${days == 1 ? 'day' : 'days'} remaining',
              style: AppType.labelSmall.copyWith(color: tokens.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Early withdrawal (Req 21.8)
// ---------------------------------------------------------------------------

/// Shows the penalty and the net amount, then performs the withdrawal only once
/// the user confirms.
class EarlyWithdrawalSheet extends ConsumerStatefulWidget {
  const EarlyWithdrawalSheet({
    required this.deposit,
    required this.now,
    super.key,
  });

  final TimeDeposit deposit;
  final DateTime now;

  @override
  ConsumerState<EarlyWithdrawalSheet> createState() =>
      _EarlyWithdrawalSheetState();
}

class _EarlyWithdrawalSheetState extends ConsumerState<EarlyWithdrawalSheet> {
  bool _submitting = false;
  String? _failure;

  Future<void> _confirm() async {
    // Req 3.7: rejects further activation while it works.
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _failure = null;
    });
    try {
      await ref
          .read(timeDepositRepositoryProvider)
          .withdrawEarly(widget.deposit.id);
      ref.invalidate(timeDepositsProvider);
      ref.invalidate(timeDepositTotalPrincipalProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
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
    // Built from the domain, with no repository call, so nothing has happened
    // yet when these figures appear.
    final quote = widget.deposit.earlyWithdrawalQuote(widget.now);

    return Container(
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
                  'Withdraw before maturity',
                  style: AppType.headlineLarge.copyWith(
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: Space.x2),
              Text(
                'This deposit still has ${quote.daysRemaining} days to run. '
                'Breaking it now forfeits part of the interest.',
                style: AppType.bodyMedium.copyWith(color: tokens.textSecondary),
              ),
              const SizedBox(height: Space.x5),

              _FieldRow(
                label: 'Principal returned',
                child: MoneyText(
                  quote.principal,
                  style: AppType.numericSmall,
                  label: 'Principal returned',
                ),
              ),
              _FieldRow(
                label: 'Interest earned so far',
                child: MoneyText(
                  quote.accruedInterest,
                  style: AppType.numericSmall,
                  color: tokens.success,
                  label: 'Interest earned so far',
                ),
              ),
              _FieldRow(
                label:
                    'Early withdrawal penalty '
                    '(${quote.penaltyPercent.toStringAsFixed(0)}% of interest)',
                child: MoneyText(
                  quote.penalty,
                  style: AppType.numericSmall,
                  color: tokens.error,
                  label: 'Early withdrawal penalty',
                ),
              ),

              const SizedBox(height: Space.x2),
              const SoftDivider(inset: 0),
              const SizedBox(height: Space.x3),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'Net amount',
                      style: AppType.titleSmall.copyWith(
                        color: tokens.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.x3),
                  MoneyText(
                    quote.netAmount,
                    style: AppType.numericLarge,
                    label: 'Net amount',
                  ),
                ],
              ),

              if (_failure != null) ...[
                const SizedBox(height: Space.x4),
                Text(
                  _failure!,
                  style: AppType.bodySmall.copyWith(color: tokens.error),
                ),
              ],

              const SizedBox(height: Space.x5),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _confirm,
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
                      : const Text('Withdraw now'),
                ),
              ),
              const SizedBox(height: Space.x3),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(Layout.minTapTarget),
                  ),
                  child: const Text('Keep deposit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton and notice
// ---------------------------------------------------------------------------

/// Shape matched to [_DepositCard]: an avatar, two heading lines, a status pill,
/// then five field rows (Req 3.3).
class _DepositSkeleton extends StatelessWidget {
  const _DepositSkeleton();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var card = 0; card < 2; card++)
        Padding(
          padding: const EdgeInsets.only(bottom: Space.x3),
          child: Container(
            padding: const EdgeInsets.all(Space.x4),
            decoration: BoxDecoration(
              color: context.tokens.surfaceRaised,
              borderRadius: AppRadius.all(AppRadius.lg),
              border: Border.all(color: context.tokens.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SkeletonBlock(
                      width: 44,
                      height: 44,
                      radius: AppRadius.sm,
                    ),
                    const SizedBox(width: Space.x3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          SkeletonBlock(width: 120, height: 22),
                          SizedBox(height: Space.x2),
                          SkeletonBlock(width: 140, height: 11),
                        ],
                      ),
                    ),
                    const SizedBox(width: Space.x3),
                    const SkeletonBlock(
                      width: 60,
                      height: 22,
                      radius: AppRadius.pill,
                    ),
                  ],
                ),
                const SizedBox(height: Space.x4),
                for (var row = 0; row < 5; row++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.x2),
                    child: Row(
                      children: const [
                        SkeletonBlock(width: 110, height: 12),
                        Spacer(),
                        SkeletonBlock(width: 72, height: 12),
                      ],
                    ),
                  ),
                const SizedBox(height: Space.x3),
                const SkeletonBlock(height: 6, radius: AppRadius.pill),
              ],
            ),
          ),
        ),
    ],
  );
}

/// Req 21.10, stated a second time next to the deposit list along with the
/// policy figures that come from the same mock table.
class _MockRateNotice extends StatelessWidget {
  const _MockRateNotice();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(Space.x4),
      decoration: BoxDecoration(
        color: tokens.interactiveSecondary,
        borderRadius: AppRadius.all(AppRadius.lg),
        border: Border.all(color: tokens.accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: tokens.accent),
          const SizedBox(width: Space.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  TimeDepositRates.mockRateStatement,
                  style: AppType.bodySmall.copyWith(
                    color: tokens.textSecondary,
                  ),
                ),
                const SizedBox(height: Space.x1),
                Text(
                  'Minimum principal '
                  '${Money.format(TimeDepositRates.minimumPrincipal)}. '
                  'Interest is simple, not compounded.',
                  style: AppType.bodySmall.copyWith(
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
