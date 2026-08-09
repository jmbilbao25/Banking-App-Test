import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/motion.dart';
import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import '../widgets/brand.dart';
import '../widgets/market.dart';
import '../widgets/money_text.dart';
import '../widgets/motion_effects.dart';
import '../widgets/pressable.dart';
import '../widgets/states.dart';
import '../widgets/surfaces.dart';

/// Crypto index.
///
/// The only screen in the application backed by a live service. Prices, moves,
/// and session ranges come from Twelve Data; the quantities held come from the
/// mock ledger. That split is stated on the screen, so nothing here pretends a
/// made up position is a real one.
class CryptoScreen extends ConsumerWidget {
  const CryptoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfolio = ref.watch(cryptoPortfolioProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crypto'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(cryptoQuotesProvider),
            tooltip: 'Refresh prices',
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: Space.x1),
        ],
      ),
      body: ResponsiveShell(
        child: RefreshIndicator(
          color: context.tokens.accent,
          onRefresh: () async {
            ref.invalidate(cryptoQuotesProvider);
            await ref.read(cryptoQuotesProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              0,
              0,
              0,
              Space.x16 + Space.x8,
            ),
            children: [
              AsyncSection<CryptoPortfolio>(
                value: portfolio,
                onRetry: () => ref.invalidate(cryptoQuotesProvider),
                skeleton: const _CryptoSkeleton(),
                builder: (data) => _Portfolio(portfolio: data),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Portfolio extends StatelessWidget {
  const _Portfolio({required this.portfolio});

  final CryptoPortfolio portfolio;

  @override
  Widget build(BuildContext context) {
    final held = portfolio.held;
    final watchlist = portfolio.watchlist;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FadeSlideIn(
          duration: Motion.long,
          offset: const Offset(0, 20),
          child: _ValueHeader(portfolio: portfolio),
        ),
        const SizedBox(height: Space.x6),
        if (held.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.x5),
            child: FadeSlideIn(
              index: 1,
              child: SectionHeader(
                title: 'Your coins',
                action: Text(
                  Money.format(portfolio.value),
                  style: AppType.numericSmall.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          for (var index = 0; index < held.length; index++)
            FadeSlideIn(
              index: 2 + index,
              child: _CoinRow(position: held[index]),
            ),
          const SizedBox(height: Space.x6),
        ],
        if (watchlist.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.x5),
            child: FadeSlideIn(
              index: 2 + held.length,
              child: const SectionHeader(title: 'Other coins'),
            ),
          ),
          for (var index = 0; index < watchlist.length; index++)
            FadeSlideIn(
              index: 3 + held.length + index,
              child: _CoinRow(position: watchlist[index]),
            ),
        ],
        const SizedBox(height: Space.x5),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.x5),
          child: _Provenance(asOf: portfolio.asOf),
        ),
      ],
    );
  }
}

/// Live valuation of the held positions, on the brand surface.
class _ValueHeader extends ConsumerWidget {
  const _ValueHeader({required this.portfolio});

  final CryptoPortfolio portfolio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FrostBackdrop(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(AppRadius.xl),
      ),
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
              'Portfolio value',
              style: AppType.labelMedium.copyWith(
                color: Colors.white.withValues(alpha: 0.76),
              ),
            ),
            const SizedBox(height: Space.x2),
            // A live figure, so it swaps rather than jumping when a new quote
            // lands.
            LiveValueSwap(
              child: MoneyText(
                portfolio.value,
                key: ValueKey(portfolio.value),
                style: AppType.numericHero,
                color: Colors.white,
                label: 'Crypto portfolio value',
              ),
            ),
            const SizedBox(height: Space.x3),
            Row(
              children: [
                MoveBadge(
                  percentChange: portfolio.percentChange,
                  amountChange: portfolio.change,
                  onBrand: true,
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
            // Requirement 19.8: the provenance line follows the actual source.
            // Claiming live prices while a build without a market key is serving
            // generated bars would be the one thing this screen must not do.
            Text(
              ref.watch(marketDataIsMockProvider)
                  ? 'Every rate and quantity here is mock data.'
                  : 'Quantities held are mock ledger data. Prices are live.',
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

class _CoinRow extends StatelessWidget {
  const _CoinRow({required this.position});

  final CryptoPosition position;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final quote = position.quote;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.x5,
        vertical: Space.x1,
      ),
      child: Pressable(
        onTap: () => context.push('/crypto/${quote.code}'),
        borderRadius: AppRadius.lg,
        semanticLabel: [
          '${quote.name}, ${quote.code}',
          Money.spoken(quote.price),
          Money.percentSpoken(quote.percentChange),
          if (position.isHeld)
            'holding ${Money.quantity(position.quantity, quote.code)}',
        ].join(', '),
        child: SoftCard(
          child: Row(
            children: [
              CoinBadge(code: quote.code, size: 40),
              const SizedBox(width: Space.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${quote.name} (${quote.code})',
                      style: AppType.titleSmall.copyWith(
                        color: tokens.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      position.isHeld
                          ? Money.quantity(position.quantity, quote.code)
                          : 'Not held',
                      style: AppType.numericSmall.copyWith(
                        color: tokens.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.x2),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Money.price(quote.price),
                    style: AppType.numericMedium.copyWith(
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  MoveBadge(
                    percentChange: quote.percentChange,
                    amountChange: position.isHeld
                        ? position.valueChange
                        : quote.change,
                    compact: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where the numbers came from and how fresh they are. A live figure without a
/// timestamp is not a live figure.
class _Provenance extends ConsumerWidget {
  const _Provenance({required this.asOf});

  final DateTime? asOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final isMock = ref.watch(marketDataIsMockProvider);
    return Row(
      children: [
        Icon(
          isMock ? Icons.science_outlined : Icons.bolt_rounded,
          size: 14,
          color: tokens.textSecondary.withValues(alpha: 0.8),
        ),
        const SizedBox(width: Space.x1),
        Expanded(
          child: Text(
            // Requirement 19.8. Naming the venue while serving generated bars
            // would attribute invented figures to a real market.
            isMock
                ? 'Mock rates, generated on this device'
                : asOf == null
                      ? 'Live prices from Twelve Data'
                      : 'Live prices from Twelve Data, quoted '
                            '${Dates.relative(asOf!).toLowerCase()}',
            style: AppType.bodySmall.copyWith(color: tokens.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _CryptoSkeleton extends StatelessWidget {
  const _CryptoSkeleton();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SkeletonBlock(height: 196, radius: AppRadius.xl),
      const SizedBox(height: Space.x6),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: Space.x5),
        child: SkeletonBlock(width: 120, height: 18),
      ),
      const SizedBox(height: Space.x3),
      for (var index = 0; index < 5; index++)
        const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: Space.x5,
            vertical: Space.x1,
          ),
          child: SkeletonBlock(height: 72, radius: AppRadius.lg),
        ),
    ],
  );
}
