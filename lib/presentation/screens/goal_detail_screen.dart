import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/format/money.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import '../widgets/brand.dart';
import '../widgets/money_text.dart';
import '../widgets/states.dart';
import '../widgets/surfaces.dart';
import 'open_goal_sheet.dart' show NumPadSheet, resolveGoalIcon;

class GoalDetailScreen extends ConsumerWidget {
  const GoalDetailScreen({required this.goalId, super.key});

  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalAsync = ref.watch(goalProvider(goalId));

    return Scaffold(
      body: goalAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorBody(
          message: e.toString(),
          onRetry: () => ref.invalidate(goalProvider(goalId)),
        ),
        data: (goal) => _GoalBody(goal: goal),
      ),
    );
  }
}

// ── Full body once data is loaded ─────────────────────────────────────────────

class _GoalBody extends ConsumerStatefulWidget {
  const _GoalBody({required this.goal});

  final GoalSave goal;

  @override
  ConsumerState<_GoalBody> createState() => _GoalBodyState();
}

class _GoalBodyState extends ConsumerState<_GoalBody> {
  @override
  Widget build(BuildContext context) {
    // Re-watch so mutations refresh the header in place.
    final goalAsync = ref.watch(goalProvider(widget.goal.id));
    final goal = goalAsync.value ?? widget.goal;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Brand backdrop app bar ─────────────────────────────────
          SliverAppBar(
            expandedHeight: 230,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _GoalHeroHeader(goal: goal),
            ),
            title: Text(goal.name),
            foregroundColor: Colors.white,
            backgroundColor: Palette.frostBaseTop,
          ),

          SliverToBoxAdapter(
            child: ResponsiveShell(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.x5,
                  Space.x5,
                  Space.x5,
                  Space.x16 + Space.x8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Transfer actions ──────────────────────────────
                    if (goal.status == GoalSaveStatus.active)
                      _TransferRow(goal: goal),

                    const SizedBox(height: Space.x6),

                    // ── Stats row ─────────────────────────────────────
                    _StatsRow(goal: goal),

                    const SizedBox(height: Space.x6),

                    // ── Transaction history ───────────────────────────
                    const SectionHeader(title: 'History'),
                    _GoalHistory(goalId: goal.id),

                    const SizedBox(height: Space.x6),

                    // ── Close goal ────────────────────────────────────
                    if (goal.status == GoalSaveStatus.active)
                      _CloseGoalButton(goal: goal),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero gradient header ──────────────────────────────────────────────────────

class _GoalHeroHeader extends StatelessWidget {
  const _GoalHeroHeader({required this.goal});

  final GoalSave goal;

  @override
  Widget build(BuildContext context) {
    return FrostBackdrop(
      glow: 0.9,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Space.x5,
          MediaQuery.of(context).padding.top + Space.x16,
          Space.x5,
          Space.x5,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Goal icon in a frosted circle
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: AppRadius.all(AppRadius.pill),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    resolveGoalIcon(goal.emoji),
                    size: 24,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: Space.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MoneyText(
                        goal.balance,
                        style: AppType.numericLarge,
                        color: Colors.white,
                        label: '${goal.name} balance',
                      ),
                      const SizedBox(height: Space.x1),
                      Text(
                        goal.hasTarget
                            ? 'of ${Money.format(goal.targetAmount)} goal'
                            : 'No target set',
                        style: AppType.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (goal.hasTarget) ...[
              const SizedBox(height: Space.x3),
              ClipRRect(
                borderRadius: AppRadius.all(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: goal.progress,
                  minHeight: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    goal.progress >= 1.0
                        ? context.tokens.success
                        : Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: Space.x1),
              Text(
                '${(goal.progress * 100).toStringAsFixed(1)}% of goal reached',
                style: AppType.labelSmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Transfer row (Add / Withdraw) ─────────────────────────────────────────────

class _TransferRow extends ConsumerWidget {
  const _TransferRow({required this.goal});

  final GoalSave goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () =>
                _showTransferPad(context, ref, goal: goal, isDeposit: true),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add funds'),
          ),
        ),
        const SizedBox(width: Space.x3),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: goal.balance > 0
                ? () => _showTransferPad(context, ref,
                    goal: goal, isDeposit: false)
                : null,
            icon: const Icon(Icons.remove_rounded),
            label: const Text('Withdraw'),
          ),
        ),
      ],
    );
  }

  Future<void> _showTransferPad(
    BuildContext context,
    WidgetRef ref, {
    required GoalSave goal,
    required bool isDeposit,
  }) async {
    final label = isDeposit ? 'Add funds' : 'Withdraw funds';
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NumPadSheet(label: label, initial: ''),
    );

    if (result == null || !context.mounted) return;
    final amount = double.tryParse(result);
    if (amount == null || amount <= 0) return;

    // Validate withdraw limit
    if (!isDeposit && amount > goal.balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Exceeds available balance (${Money.format(goal.balance)})',
          ),
        ),
      );
      return;
    }

    final controller = ref.read(savingsControllerProvider.notifier);
    final ok = isDeposit
        ? await controller.transferIn(goalId: goal.id, amount: amount)
        : await controller.transferOut(goalId: goal.id, amount: amount);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? isDeposit
                  ? '${Money.format(amount)} added to ${goal.name}.'
                  : '${Money.format(amount)} withdrawn from ${goal.name}.'
              : (ref.read(savingsControllerProvider) is SavingsError
                  ? (ref.read(savingsControllerProvider) as SavingsError)
                      .message
                  : 'Something went wrong.'),
        ),
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.goal});

  final GoalSave goal;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Interest earned',
            value: Money.format(goal.interestEarned),
            icon: Icons.auto_graph_rounded,
            iconColor: tokens.success,
          ),
        ),
        const SizedBox(width: Space.x3),
        Expanded(
          child: _StatCard(
            label: 'Daily interest',
            value: '+${Money.format(goal.dailyInterestAmount)}',
            icon: Icons.trending_up_rounded,
            iconColor: tokens.accent,
          ),
        ),
        const SizedBox(width: Space.x3),
        Expanded(
          child: _StatCard(
            label: 'Daily rate',
            value: '${goal.dailyRatePercent.toStringAsFixed(6)}%',
            icon: Icons.percent_rounded,
            iconColor: tokens.info,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(Space.x3),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: AppRadius.all(AppRadius.md),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(height: Space.x2),
          Text(
            value,
            style: AppType.titleSmall.copyWith(color: tokens.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: Space.x1),
          Text(
            label,
            style: AppType.bodySmall.copyWith(color: tokens.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Transaction history ───────────────────────────────────────────────────────

class _GoalHistory extends ConsumerWidget {
  const _GoalHistory({required this.goalId});

  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txns = ref.watch(goalTransactionsProvider(goalId));

    return AsyncSection<List<GoalTxn>>(
      value: txns,
      onRetry: () => ref.invalidate(goalTransactionsProvider(goalId)),
      skeleton: const SkeletonRows(count: 4),
      isEmpty: (rows) => rows.isEmpty,
      empty: const _EmptyHistory(),
      builder: (rows) => Column(
        children: [
          for (final txn in rows)
            Column(
              children: [
                _GoalTxnRow(txn: txn),
                if (txn != rows.last) SoftDivider(inset: Space.x4 + 44),
              ],
            ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.x6),
      child: Center(
        child: Text(
          'No transactions yet.',
          style: AppType.bodyMedium.copyWith(color: tokens.textSecondary),
        ),
      ),
    );
  }
}

class _GoalTxnRow extends StatelessWidget {
  const _GoalTxnRow({required this.txn});

  final GoalTxn txn;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isCredit = txn.kind.isCredit;

    Color iconBg;
    IconData icon;
    Color amountColor;

    switch (txn.kind) {
      case GoalTxnKind.transferIn:
        iconBg = tokens.success.withValues(alpha: 0.12);
        icon = Icons.arrow_downward_rounded;
        amountColor = tokens.success;
      case GoalTxnKind.transferOut:
        iconBg = tokens.error.withValues(alpha: 0.12);
        icon = Icons.arrow_upward_rounded;
        amountColor = tokens.error;
      case GoalTxnKind.interest:
        iconBg = tokens.accent.withValues(alpha: 0.12);
        icon = Icons.auto_graph_rounded;
        amountColor = tokens.accent;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.x3),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: AppRadius.all(AppRadius.pill),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: amountColor),
          ),
          const SizedBox(width: Space.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn.kind.label,
                  style: AppType.titleSmall.copyWith(
                    color: tokens.textPrimary,
                  ),
                ),
                Text(
                  _formatDate(txn.date),
                  style: AppType.bodySmall.copyWith(
                    color: tokens.textSecondary,
                  ),
                ),
                if (txn.note != null)
                  Text(
                    txn.note!,
                    style: AppType.bodySmall.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : '-'}${Money.format(txn.amount)}',
                style: AppType.numericSmall.copyWith(color: amountColor),
              ),
              Text(
                'Bal: ${Money.format(txn.runningBalance)}',
                style: AppType.bodySmall.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '${months[date.month - 1]} ${date.day}, ${date.year} · $h:$m';
  }
}

// ── Close goal button ─────────────────────────────────────────────────────────

class _CloseGoalButton extends ConsumerWidget {
  const _CloseGoalButton({required this.goal});

  final GoalSave goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SoftDivider(),
        const SizedBox(height: Space.x4),
        OutlinedButton.icon(
          onPressed: () => _confirmClose(context, ref),
          icon: Icon(Icons.close_rounded, color: tokens.error),
          label: Text(
            'Close goal save',
            style: TextStyle(color: tokens.error),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: tokens.error.withValues(alpha: 0.4)),
          ),
        ),
        const SizedBox(height: Space.x2),
        Text(
          'Closing returns the full balance to your savings account.',
          style: AppType.bodySmall.copyWith(color: tokens.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Future<void> _confirmClose(BuildContext context, WidgetRef ref) async {
    final tokens = context.tokens;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(Space.x2),
              decoration: BoxDecoration(
                color: tokens.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.savings_outlined, color: tokens.error, size: 22),
            ),
            const SizedBox(width: Space.x3),
            Expanded(
              child: Text(
                'Close goal save?',
                style: AppType.titleMedium.copyWith(color: tokens.textPrimary),
              ),
            ),
          ],
        ),
        content: Text(
          'Your balance of ${Money.format(goal.balance)} will be returned to your account.',
          style: AppType.bodyMedium.copyWith(color: tokens.textSecondary),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          Space.x4,
          0,
          Space.x4,
          Space.x4,
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.textPrimary,
                    side: BorderSide(color: tokens.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: Space.x3),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: Space.x3),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: Space.x3),
                  ),
                  child: const Text('Close Goal'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final ok =
        await ref.read(savingsControllerProvider.notifier).closeGoal(goal.id);

    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Goal closed. Funds returned to your account.'),
        ),
      );
      Navigator.of(context).pop();
    } else {
      final err = ref.read(savingsControllerProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            err is SavingsError ? err.message : 'Something went wrong.',
          ),
        ),
      );
    }
  }
}

// ── Error body ────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(Space.x5),
            child: ErrorStateView(message: message, onRetry: onRetry),
          ),
        ),
      );
}
