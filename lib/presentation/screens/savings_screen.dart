import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/format/money.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import '../widgets/brand.dart';
import '../widgets/money_text.dart';
import '../widgets/pressable.dart';
import '../widgets/states.dart';
import '../widgets/surfaces.dart';
import 'open_goal_sheet.dart' show OpenGoalSheet, resolveGoalIcon;

class SavingsScreen extends ConsumerWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    final totalSavings = ref.watch(totalSavingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Savings')),
      body: ResponsiveShell(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(
                0,
                0,
                0,
                Space.x16 + Space.x8,
              ),
              children: [
                // ── Hero card (edge-to-edge like crypto) ──────────────────────
                _SavingsHeroCard(totalSavings: totalSavings),
                const SizedBox(height: Space.x6),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.x5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Section header + open-goal button ──────────────────
                      SectionHeader(
                        title: 'Goal Saves',
                        action: TextButton.icon(
                          onPressed: () => _openGoalSheet(context, ref),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('New goal'),
                        ),
                      ),

                      // ── Goal list ──────────────────────────────────────────
                      AsyncSection<List<GoalSave>>(
                        value: goals,
                        onRetry: () => ref.invalidate(goalsProvider),
                        skeleton: const SkeletonRows(count: 3),
                        isEmpty: (rows) => rows
                            .where((g) => g.status == GoalSaveStatus.active)
                            .isEmpty,
                        empty: EmptyStateView(
                          icon: Icons.savings_rounded,
                          heading: 'No goal saves yet',
                          message:
                              'Open a goal save to start growing your money with daily interest.',
                          actionLabel: 'Open a goal save',
                          onAction: () => _openGoalSheet(context, ref),
                        ),
                        builder: (rows) {
                          final active = rows
                              .where((g) => g.status == GoalSaveStatus.active)
                              .toList();
                          return Column(
                            children: [
                              for (final goal in active)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: Space.x3),
                                  child: _GoalTile(goal: goal),
                                ),
                            ],
                          );
                        },
                      ),

                      // ── Interest info blurb ────────────────────────────────
                      const SizedBox(height: Space.x4),
                      _InterestInfoCard(),
                    ],
                  ),
                ),
              ],
            ),

            // ── FAB constrained within responsive shell ───────────────────────
            Positioned(
              bottom: Space.x5,
              left: 0,
              right: 0,
              child: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: Space.x5),
                  child: FloatingActionButton.extended(
                    onPressed: () => _openGoalSheet(context, ref),
                    icon: const Icon(Icons.savings_rounded),
                    label: const Text('Open goal save'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openGoalSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const OpenGoalSheet(),
    );
  }
}

// ── Hero card ────────────────────────────────────────────────────────────────

class _SavingsHeroCard extends ConsumerWidget {
  const _SavingsHeroCard({required this.totalSavings});

  final AsyncValue<double> totalSavings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FrostBackdrop(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(AppRadius.xl),
      ),
      glow: 0.34,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.x5,
          Space.x5,
          Space.x5,
          Space.x7,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total current savings',
              style: AppType.labelMedium.copyWith(
                color: Colors.white.withValues(alpha: 0.76),
              ),
            ),
            const SizedBox(height: Space.x2),
            totalSavings.when(
              loading: () => const SkeletonBlock(
                width: 160,
                height: 36,
                radius: AppRadius.sm,
              ),
              // Requirement 25.1 rules out the em dash that used to stand in
              // here, and the mask glyphs read as "unavailable" rather than as a
              // figure of zero.
              error: (_, _) => Text(
                Money.maskGlyphs,
                style: AppType.numericHero.copyWith(color: Colors.white),
              ),
              data: (amount) => MoneyText(
                amount,
                style: AppType.numericHero,
                color: Colors.white,
                label: 'Total current savings',
              ),
            ),
            const SizedBox(height: Space.x3),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.x3,
                    vertical: Space.x2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: AppRadius.all(AppRadius.pill),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.trending_up_rounded,
                        color: Colors.white.withValues(alpha: 0.95),
                        size: 14,
                      ),
                      const SizedBox(width: Space.x1 + 2),
                      Text(
                        '0.011918% daily interest',
                        style: AppType.labelSmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Space.x3),
                Text(
                  'today',
                  style: AppType.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.x4),
            Text(
              'Goal saves are mock ledger data. Interest rates are indicative.',
              style: AppType.bodySmall.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Goal tile ─────────────────────────────────────────────────────────────────

class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.goal});

  final GoalSave goal;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final pct = goal.hasTarget ? (goal.progress * 100).toStringAsFixed(0) : null;

    return Pressable(
      onTap: () => context.push('/savings/${goal.id}'),
      semanticLabel:
          '${goal.emoji} ${goal.name}, balance ${Money.spoken(goal.balance)}',
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
              children: [
                // Goal icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: tokens.interactiveSecondary,
                    borderRadius: AppRadius.all(AppRadius.sm),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    resolveGoalIcon(goal.emoji),
                    size: 22,
                    color: tokens.accent,
                  ),
                ),
                const SizedBox(width: Space.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        style: AppType.titleSmall.copyWith(
                          color: tokens.textPrimary,
                        ),
                      ),
                      Text(
                        goal.hasTarget
                            ? 'Goal: ${Money.format(goal.targetAmount)}'
                            : 'No target set',
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
                    MoneyText(
                      goal.balance,
                      style: AppType.numericMedium,
                      label: '${goal.name} balance',
                    ),
                    Text(
                      '+${Money.format(goal.dailyInterestAmount)}/day',
                      style: AppType.labelSmall.copyWith(
                        color: tokens.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Progress bar (only when there's a target)
            if (goal.hasTarget) ...[
              const SizedBox(height: Space.x3),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: AppRadius.all(AppRadius.pill),
                      child: LinearProgressIndicator(
                        value: goal.progress,
                        minHeight: 6,
                        backgroundColor: tokens.border,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          goal.progress >= 1.0
                              ? tokens.success
                              : tokens.accent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.x3),
                  Text(
                    '$pct%',
                    style: AppType.labelSmall.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Interest info card ────────────────────────────────────────────────────────

class _InterestInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(Space.x4),
      decoration: BoxDecoration(
        color: tokens.interactiveSecondary,
        borderRadius: AppRadius.all(AppRadius.lg),
        border: Border.all(
          color: tokens.accent.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: tokens.accent,
          ),
          const SizedBox(width: Space.x3),
          Expanded(
            child: Text(
              'Interest is credited daily at 0.011918% of your goal balance '
              '(≈ 4.35% APY). It appears as a transaction in each goal\'s history. '
              'All figures in this build are mock data.',
              style: AppType.bodySmall.copyWith(color: tokens.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
