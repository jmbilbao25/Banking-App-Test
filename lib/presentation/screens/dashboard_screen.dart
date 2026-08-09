import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/motion.dart';
import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/format/money.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import '../widgets/brand.dart';
import '../widgets/card_face.dart';
import '../widgets/money_text.dart';
import '../widgets/motion_effects.dart';
import '../widgets/opening_ad_modal.dart';
import '../widgets/pressable.dart';
import '../widgets/states.dart';
import '../widgets/surfaces.dart';
import '../widgets/transaction_list.dart';
import 'new_card_sheet.dart';

// Added imports for basic wealth movement methods:
//import '../screens/deposit_screen.dart';
//import '../screens/transfer_screen.dart';
//import '../screens/qr_screen.dart';

/// Distance every sheet section travels on its entrance.
const Offset _sectionRise = Offset(0, 22);

/// Authenticated home. Gradient top region over a rounded sheet that carries
/// quick actions, the Finance Hub, recent activity, and offers.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showOpeningAdModal(context, ref);
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(accountsProvider);
    ref.invalidate(cardsProvider);
    ref.invalidate(promosProvider);
    ref.invalidate(transactionsProvider);
    await ref.read(accountsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.backgroundAlt,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: tokens.accent,
        child: ResponsiveShell(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _TopRegion(),
                Transform.translate(
                  offset: const Offset(0, -Space.x6),
                  child: Container(
                    decoration: BoxDecoration(
                      color: tokens.backgroundAlt,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppRadius.xl),
                      ),
                      // One soft shadow, so the sheet reads as sitting over the
                      // gradient rather than being cut out of it.
                      boxShadow: [
                        BoxShadow(
                          color: tokens.shadow.withValues(alpha: 0.18),
                          blurRadius: 24,
                          offset: const Offset(0, -6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(
                      Space.x5,
                      Space.x6,
                      Space.x5,
                      Space.x16 + Space.x8,
                    ),
                    // Storytelling: the sheet resolves top down, so the eye is
                    // led from the actions to the ledger rather than met by a
                    // finished page.
                    //
                    // Order matters here. The ledger sits directly under the
                    // quick actions, ahead of the Finance Hub, because a home
                    // screen exists to answer two questions: how much do I have,
                    // and what just happened to my money. The Finance Hub is a
                    // set of destinations rather than information, so it cannot
                    // stand between the customer and their transactions.
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FadeSlideIn(
                          offset: _sectionRise,
                          child: _QuickActions(),
                        ),
                        SizedBox(height: Space.x8),
                        FadeSlideIn(
                          index: 2,
                          offset: _sectionRise,
                          child: _RecentTransactions(),
                        ),
                        SizedBox(height: Space.x8),
                        FadeSlideIn(
                          index: 4,
                          offset: _sectionRise,
                          child: _FinanceHub(),
                        ),
                        SizedBox(height: Space.x8),
                        FadeSlideIn(
                          index: 6,
                          offset: _sectionRise,
                          child: _Offers(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopRegion extends ConsumerWidget {
  const _TopRegion();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final accounts = ref.watch(accountsProvider);
    final selected = ref.watch(selectedAccountProvider);
    final hidden = ref.watch(preferencesProvider).balancesHidden;

    // No bottom rounding. The sheet below overlaps this region and rounds its
    // own top, so rounding here too left the gradient's corners visible either
    // side of the sheet as two small flares.
    return FrostBackdrop(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.x5,
            Space.x4,
            Space.x5,
            Space.x10,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const FrostLockup(markSize: 32),
                  const Spacer(),
                  GlassIconButton(
                    icon: hidden
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    label: hidden ? 'Show balances' : 'Hide balances',
                    onTap: () => ref
                        .read(preferencesProvider.notifier)
                        .toggleBalanceVisibility(),
                  ),
                  const SizedBox(width: Space.x2),
                  GlassIconButton(
                    icon: Icons.notifications_none_rounded,
                    label: 'Notifications',
                    // Requirement 12.16: the badge follows the real unread
                    // count, so it disappears once the feed is read.
                    badgeCount: ref.watch(unreadNotificationCountProvider),
                    onTap: () => context.push('/notifications'),
                  ),
                ],
              ),
              const SizedBox(height: Space.x4),
              const _SearchField(),
              const SizedBox(height: Space.x6),
              AsyncSection<List<Account>>(
                value: accounts,
                onRetry: () => ref.invalidate(accountsProvider),
                skeleton: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBlock(width: 220, height: 34, radius: AppRadius.pill),
                    SizedBox(height: Space.x6),
                    SkeletonBlock(width: 200, height: 40),
                    SizedBox(height: Space.x3),
                    SkeletonBlock(width: 140, height: 14),
                  ],
                ),
                builder: (rows) {
                  final active = selected.value;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AccountChips(accounts: rows),
                      const SizedBox(height: Space.x6),
                      if (active != null) ...[
                        // The figure below is the selected account's balance,
                        // not a total across accounts, so the label names the
                        // account. Calling it "Total balance" while Savings and
                        // Crypto are visible in the chip row above mislabelled
                        // the largest number on the screen.
                        Text(
                          '${active.name} balance',
                          style: AppType.labelMedium.copyWith(
                            color: Colors.white.withValues(alpha: 0.76),
                          ),
                        ),
                        const SizedBox(height: Space.x2),
                        HeroBalance(
                          accountName: active.name,
                          value: active.totalBalance,
                          currencyCode: active.currencyCode,
                          color: tokens.textOnBrand,
                        ),
                        const SizedBox(height: Space.x2),
                        Row(
                          children: [
                            Text(
                              'Available ',
                              style: AppType.bodySmall.copyWith(
                                color: Colors.white.withValues(alpha: 0.76),
                              ),
                            ),
                            MoneyText(
                              active.availableBalance,
                              style: AppType.numericSmall,
                              color: Colors.white.withValues(alpha: 0.9),
                              currencyCode: active.currencyCode,
                              label: '${active.name} available',
                            ),
                            if (active.isCrypto &&
                                active.cryptoQuantity != null) ...[
                              Text(
                                '  \u2022  ',
                                style: AppType.bodySmall.copyWith(
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                              NumericText(
                                Money.quantity(
                                  active.cryptoQuantity!,
                                  active.cryptoUnit ?? '',
                                ),
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ],
                          ],
                        ),
                      ],
                      const SizedBox(height: Space.x6),
                      const _CardsCarousel(),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends ConsumerStatefulWidget {
  const _SearchField();

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search(String value) {
    if (value.trim().isEmpty) return;
    ref.read(txnFilterProvider.notifier).setQuery(value.trim());
    context.go('/activity');
  }

  @override
  Widget build(BuildContext context) {
    // The search field sits on the brand surface, so its text is white rather
    // than theme coloured.
    final border = OutlineInputBorder(
      borderRadius: AppRadius.all(AppRadius.pill),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
    );

    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.search,
      onSubmitted: _search,
      cursorColor: Colors.white,
      style: AppType.bodyMedium.copyWith(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Search transactions',
        hintStyle: AppType.bodyMedium.copyWith(
          color: Colors.white.withValues(alpha: 0.56),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.1),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: Space.x3),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: Colors.white.withValues(alpha: 0.7),
          size: 20,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.all(AppRadius.pill),
          borderSide: const BorderSide(color: Palette.frostIcePale, width: 2),
        ),
      ),
    );
  }
}

class _AccountChips extends ConsumerWidget {
  const _AccountChips({required this.accounts});

  final List<Account> accounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeId = ref.watch(selectedAccountProvider).value?.id;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final account in accounts)
            Padding(
              padding: const EdgeInsets.only(right: Space.x2),
              child: _AccountChip(
                account: account,
                isActive: account.id == activeId,
                onTap: () => ref
                    .read(selectedAccountIdProvider.notifier)
                    .select(account.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _AccountChip extends StatelessWidget {
  const _AccountChip({
    required this.account,
    required this.isActive,
    required this.onTap,
  });

  final Account account;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Pressable(
      onTap: onTap,
      semanticLabel:
          '${account.name}, ${Money.spoken(account.totalBalance, currencyCode: account.currencyCode)}'
          '${isActive ? ', selected' : ''}',
      borderRadius: AppRadius.md,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.x4,
          vertical: Space.x2,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: isActive ? 0.2 : 0.1),
          borderRadius: AppRadius.all(AppRadius.md),
          border: Border.all(
            color: Colors.white.withValues(alpha: isActive ? 0.44 : 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              account.shortCode,
              style: AppType.labelSmall.copyWith(
                color: Colors.white.withValues(alpha: 0.82),
              ),
            ),
            const SizedBox(height: 2),
            MoneyText(
              account.totalBalance,
              style: AppType.numericSmall,
              color: Colors.white,
              currencyCode: account.currencyCode,
              maskable: true,
            ),
            const SizedBox(height: Space.x1),
            // Hierarchy: the underline marks which account every figure below
            // belongs to.
            AnimatedContainer(
              duration: Motion.resolve(context, Motion.short),
              curve: Motion.standard,
              height: 2,
              width: isActive ? 28 : 0,
              decoration: BoxDecoration(
                color: tokens.accent,
                borderRadius: AppRadius.all(AppRadius.pill),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardsCarousel extends ConsumerWidget {
  const _CardsCarousel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(cardsProvider);

    // Portrait, matching the card face on the Cards screen, so a card is the
    // same object wherever it appears.
    //
    // Deliberately small. At 94 the strip stood 154 logical pixels tall, about a
    // fifth of the viewport, and pushed the transaction list off the first
    // screen. Cards are a way in to the Cards screen here, not the subject of
    // this one, so they earn a thumbnail and no more.
    const thumbWidth = 54.0;

    return SizedBox(
      height: CardFace.heightFor(thumbWidth) + Space.x3,
      child: AsyncSection<List<BankCard>>(
        value: cards,
        onRetry: () => ref.invalidate(cardsProvider),
        skeleton: Row(
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.only(right: Space.x3),
                child: SkeletonBlock(
                  width: thumbWidth,
                  height: CardFace.heightFor(thumbWidth),
                  radius: AppRadius.sm,
                ),
              ),
          ],
        ),
        builder: (rows) => ListView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          children: [
            for (var index = 0; index < rows.length; index++)
              Padding(
                padding: const EdgeInsets.only(right: Space.x3),
                child: FadeSlideIn(
                  index: index,
                  offset: const Offset(18, 0),
                  child: _CardThumb(card: rows[index], width: thumbWidth),
                ),
              ),
            FadeSlideIn(
              index: rows.length,
              offset: const Offset(18, 0),
              child: Pressable(
                onTap: () => showNewCardSheet(context),
                semanticLabel: 'Add card',
                borderRadius: AppRadius.sm,
                child: AddCardTile(width: thumbWidth, onBrand: true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardThumb extends StatelessWidget {
  const _CardThumb({required this.card, required this.width});

  final BankCard card;
  final double width;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: () => context.go('/cards'),
    semanticLabel:
        '${card.label}, ${card.kind.label} ${card.network.label} '
        'ending ${card.last4}, ${card.status.label}',
    borderRadius: AppRadius.sm,
    child: MiniCardFace(card: card, width: width),
  );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: staggered(
      // Sentence case, like every other label in the app. These four were the
      // only all caps text in the product, which made the dashboard read as its
      // own dialect. "Add money" and "Send money" also now match the titles of
      // the screens they open, so the label the user taps is the label that
      // greets them.
      const [
        _QuickAction(
          icon: Icons.south_west_rounded,
          label: 'Add money',
          route: '/deposit',
        ),
        _QuickAction(
          icon: Icons.north_east_rounded,
          label: 'Send money',
          route: '/transfer',
        ),
        _QuickAction(
          icon: Icons.qr_code_scanner_rounded,
          label: 'Scan',
          route: '/qr-scanner',
        ),
        _QuickAction(
          icon: Icons.receipt_long_rounded,
          label: 'History',
          route: '/activity',
        ),
      ],
      offset: const Offset(0, 14),
    ),
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isBranch = route.startsWith('/activity') || route.startsWith('/cards');
    return Pressable(
      onTap: () => isBranch ? context.go(route) : context.push(route),
      semanticLabel: label.toLowerCase(),
      borderRadius: AppRadius.md,
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: AppRadius.all(AppRadius.md),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Palette.frostBaseTop, Palette.frostLift],
                ),
                boxShadow: [
                  BoxShadow(
                    color: tokens.shadow,
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: Space.x2),
            Text(
              label,
              style: AppType.labelSmall.copyWith(color: tokens.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FinanceHub extends StatelessWidget {
  const _FinanceHub();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Requirement 12.9: exactly four entries, labelled Savings, Crypto,
      // Split Bills, and Time Deposit. Cards had a fifth tile here while also
      // being a shell destination, and a horse racing screen had a sixth.
      const SectionHeader(title: 'Finance Hub'),
      Row(
        children: const [
          Expanded(
            child: HubTile(
              // One icon weight across the grid. It previously mixed a filled
              // piggy bank, a hairline currency glyph, a filled people mark and
              // a filled padlock, which read as four different icon sets.
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
    ],
  );
}

/// Finance Hub entry, also reused by the hub branch screen.
class HubTile extends StatelessWidget {
  const HubTile({
    required this.icon,
    required this.label,
    required this.route,
    super.key,
  });

  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isBranch = route == '/cards' || route == '/activity' || route == '/hub' || route == '/profile';
    return Pressable(
      onTap: () => isBranch ? context.go(route) : context.push(route),
      semanticLabel: label,
      borderRadius: AppRadius.lg,
      child: SoftCard(
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: tokens.interactiveSecondary,
                borderRadius: AppRadius.all(AppRadius.sm),
              ),
              child: Icon(icon, size: 20, color: tokens.accent),
            ),
            const SizedBox(width: Space.x3),
            Expanded(
              child: Text(
                label,
                style: AppType.titleSmall.copyWith(color: tokens.textPrimary),
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTransactions extends ConsumerWidget {
  const _RecentTransactions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountId = ref.watch(selectedAccountProvider).value?.id;
    final rows = ref.watch(transactionsProvider(accountId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Transactions',
          action: TextButton(
            onPressed: () => context.go('/activity'),
            child: const Text('View all'),
          ),
        ),
        AsyncSection<List<Txn>>(
          value: rows,
          onRetry: () => ref.invalidate(transactionsProvider(accountId)),
          skeleton: const SkeletonRows(),
          isEmpty: (data) => data.isEmpty,
          empty: EmptyStateView(
            heading: 'No activity yet',
            message: 'Transactions on this account will appear here.',
            actionLabel: 'Add funds',
            icon: Icons.receipt_long_rounded,
            onAction: () => context.push('/deposit'),
          ),
          builder: (data) => GroupedTransactions(
            rows: data,
            limit: 8,
            onSelect: (txn) => context.push('/txn/${txn.id}'),
          ),
        ),
      ],
    );
  }
}

class _Offers extends ConsumerWidget {
  const _Offers();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promos = ref.watch(promosProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Tips and offers'),
        SizedBox(
          height: 188,
          child: AsyncSection<List<Promo>>(
            value: promos,
            onRetry: () => ref.invalidate(promosProvider),
            skeleton: ListView(
              scrollDirection: Axis.horizontal,
              children: const [
                SkeletonBlock(width: 240, height: 180, radius: AppRadius.lg),
                SizedBox(width: Space.x3),
                SkeletonBlock(width: 240, height: 180, radius: AppRadius.lg),
              ],
            ),
            builder: (rows) => ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(width: Space.x3),
              itemBuilder: (context, index) {
                final promo = rows[index];
                return SizedBox(
                  width: 262,
                  child: FrostCardSurface(
                    radius: AppRadius.lg,
                    padding: const EdgeInsets.all(Space.x4),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            promo.title,
                            style: AppType.titleMedium.copyWith(
                              color: Colors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: Space.x2),
                          Expanded(
                            child: Text(
                              promo.body,
                              style: AppType.bodySmall.copyWith(
                                color: Colors.white.withValues(alpha: 0.86),
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: Space.x2),
                          Pressable(
                            onTap: () => context.push('/soon/offers'),
                            semanticLabel: '${promo.actionLabel}, ${promo.title}',
                            borderRadius: AppRadius.pill,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Space.x4,
                                vertical: Space.x2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: AppRadius.all(AppRadius.pill),
                              ),
                              child: Text(
                                promo.actionLabel,
                                style: AppType.labelMedium.copyWith(
                                  color: Palette.frostBaseTop,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
              },
            ),
          ),
        ),
      ],
    );
  }
}
