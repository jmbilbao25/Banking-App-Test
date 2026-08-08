import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/format/money.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import '../widgets/money_text.dart';
import '../widgets/pressable.dart';
import '../widgets/states.dart';
import '../widgets/surfaces.dart';
import 'dashboard_screen.dart' show HubTile;

/// Finance Hub index. Each entry opens its own screen in a later slice.
class HubScreen extends ConsumerWidget {
  const HubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final accounts = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Finance Hub')),
      body: ResponsiveShell(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Space.x5,
            Space.x2,
            Space.x5,
            Space.x16 + Space.x8,
          ),
          children: [
            AsyncSection<List<Account>>(
              value: accounts,
              onRetry: () => ref.invalidate(accountsProvider),
              skeleton: const SkeletonBlock(height: 108, radius: AppRadius.lg),
              builder: (rows) {
                final total = rows.fold<double>(
                  0,
                  (sum, account) => sum + account.totalBalance,
                );
                return Container(
                  padding: const EdgeInsets.all(Space.x5),
                  decoration: BoxDecoration(
                    color: tokens.surface,
                    borderRadius: AppRadius.all(AppRadius.lg),
                    border: Border.all(color: tokens.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Across all accounts',
                        style: AppType.labelMedium.copyWith(
                          color: tokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: Space.x2),
                      MoneyText(
                        total,
                        style: AppType.numericLarge,
                        label: 'Total across all accounts',
                      ),
                      const SizedBox(height: Space.x3),
                      Text(
                        'Every figure in this build is mock data.',
                        style: AppType.bodySmall.copyWith(
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: Space.x6),
            const SectionHeader(title: 'Grow your money'),
            Row(
              children: const [
                Expanded(
                  child: HubTile(
                    icon: Icons.savings_outlined,
                    label: 'Savings',
                    route: '/savings',
                  ),
                ),
                SizedBox(width: Space.x3),
                Expanded(
                  child: HubTile(
                    icon: Icons.currency_bitcoin_rounded,
                    label: 'Crypto',
                    route: '/crypto',
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.x3),
            Row(
              children: const [
                Expanded(
                  child: HubTile(
                    icon: Icons.groups_outlined,
                    label: 'Split Bills',
                    route: '/split-bills',
                  ),
                ),
                SizedBox(width: Space.x3),
                Expanded(
                  child: HubTile(
                    icon: Icons.lock_clock_outlined,
                    label: 'Time Deposit',
                    route: '/time-deposit',
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.x8),
            const SectionHeader(title: 'Your accounts'),
            AsyncSection<List<Account>>(
              value: accounts,
              onRetry: () => ref.invalidate(accountsProvider),
              skeleton: const SkeletonRows(count: 3),
              isEmpty: (rows) => rows.isEmpty,
              empty: EmptyStateView(
                heading: 'No accounts yet',
                message: 'Open an account to start tracking your money.',
                actionLabel: 'Open account',
                icon: Icons.account_balance_rounded,
                onAction: () => context.push('/soon/new-account'),
              ),
              builder: (rows) => Column(
                children: [
                  for (final account in rows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.x2),
                      child: Pressable(
                        onTap: () => context.push('/account/${account.id}'),
                        semanticLabel:
                            '${account.name}, ${account.kind.label}, '
                            '${Money.spoken(account.totalBalance, currencyCode: account.currencyCode)}',
                        borderRadius: AppRadius.lg,
                        child: Container(
                          padding: const EdgeInsets.all(Space.x4),
                          decoration: BoxDecoration(
                            color: tokens.surfaceRaised,
                            borderRadius: AppRadius.all(AppRadius.lg),
                            border: Border.all(color: tokens.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: tokens.interactiveSecondary,
                                  borderRadius: AppRadius.all(AppRadius.sm),
                                ),
                                child: Icon(
                                  switch (account.kind) {
                                    AccountKind.wallet =>
                                      Icons.account_balance_wallet_rounded,
                                    AccountKind.savings => Icons.savings_outlined,
                                    AccountKind.crypto =>
                                      Icons.currency_bitcoin_rounded,
                                  },
                                  size: 20,
                                  color: tokens.accent,
                                ),
                              ),
                              const SizedBox(width: Space.x3),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      account.name,
                                      style: AppType.titleSmall.copyWith(
                                        color: tokens.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      account.maskedNumber,
                                      style: AppType.bodySmall.copyWith(
                                        color: tokens.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              MoneyText(
                                account.totalBalance,
                                style: AppType.numericMedium,
                                currencyCode: account.currencyCode,
                                label: '${account.name} balance',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
