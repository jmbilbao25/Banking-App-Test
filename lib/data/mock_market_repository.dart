import 'dart:math';

import '../domain/models.dart';
import '../domain/repositories.dart';

/// Offline stand in for [MarketRepository].
///
/// Requirement 6.4 requires every read in the default build to complete without
/// a network request, and requirement 5.9 forbids shipping an API key to make a
/// live venue reachable. This repository therefore supplies the crypto surface
/// with deterministic, believable bars so the charts, the 24 hour change colours
/// and the portfolio totals all render real shapes offline.
///
/// MOCK DATA: every price, every open, high, low and close, and every percentage
/// on this type is generated locally. No figure here came from a market.
class MockMarketRepository implements MarketRepository {
  MockMarketRepository({DateTime Function()? clock, Random? random})
    : _clock = clock ?? DateTime.now,
      _random = random ?? Random(20260808);

  final DateTime Function() _clock;
  final Random _random;

  /// Anchor prices, chosen to sit in a plausible range for each asset.
  /// MOCK DATA: these are invented reference levels, not quoted prices.
  static const Map<String, double> _anchorPrice = {
    'BTC': 64218.42,
    'ETH': 3182.75,
    'SOL': 148.63,
    'XRP': 0.5427,
    'LTC': 82.19,
  };

  /// Signed 24 hour drift per asset, so the list shows both gainers and losers
  /// and the Success and Error semantic tokens are both exercised.
  /// MOCK DATA: invented percentage moves.
  static const Map<String, double> _dayDriftPercent = {
    'BTC': 1.84,
    'ETH': 2.41,
    'SOL': -3.12,
    'XRP': -0.87,
    'LTC': 0.63,
  };

  static const _fallbackAnchor = 100.0;
  static const _fallbackDrift = 0.75;

  double _anchorFor(CryptoAsset asset) =>
      _anchorPrice[asset.code] ?? _fallbackAnchor;

  double _driftFor(CryptoAsset asset) =>
      _dayDriftPercent[asset.code] ?? _fallbackDrift;

  /// Mirrors the observable latency of the mock data source so the crypto
  /// skeletons stay visible, per requirement 6.5.
  Future<void> _latency() => Future<void>.delayed(
    Duration(milliseconds: 300 + _random.nextInt(600)),
  );

  @override
  Future<List<CryptoQuote>> fetchCryptoQuotes(List<CryptoAsset> assets) async {
    await _latency();
    final now = _clock();
    return assets.map((asset) {
      final price = _anchorFor(asset);
      final percentChange = _driftFor(asset);
      final previousClose = price / (1 + percentChange / 100);
      final change = price - previousClose;
      final spread = price * 0.021;
      return CryptoQuote(
        symbol: asset.symbol,
        code: asset.code,
        name: asset.name,
        exchange: 'FrostBank Reference',
        price: price,
        open: previousClose,
        dayHigh: max(price, previousClose) + spread,
        dayLow: min(price, previousClose) - spread,
        previousClose: previousClose,
        change: change,
        percentChange: percentChange,
        asOf: now,
        rolling1dChangePercent: percentChange,
        yearLow: price * 0.58,
        yearHigh: price * 1.47,
      );
    }).toList(growable: false);
  }

  @override
  Future<CryptoSeries> fetchCryptoSeries(
    CryptoAsset asset,
    ChartRange range,
  ) async {
    await _latency();

    final bars = range.bars;
    final step = _stepFor(range);
    final end = _clock();
    final close = _anchorFor(asset);

    // Walk backwards from the current anchor so the final bar closes on the
    // same price the quote reports, then reverse into oldest first order.
    // A per asset seed keeps the shape stable across rebuilds.
    final walk = Random(asset.code.hashCode ^ range.index);
    final amplitude = close * 0.014;
    var cursor = close;

    final reversed = <CryptoCandle>[];
    for (var i = 0; i < bars; i++) {
      final at = end.subtract(step * i);
      final drift = (walk.nextDouble() - 0.48) * amplitude;
      final open = (cursor - drift).clamp(close * 0.35, close * 2.4);
      final high = max(cursor, open) + walk.nextDouble() * amplitude * 0.6;
      final low = min(cursor, open) - walk.nextDouble() * amplitude * 0.6;
      reversed.add(
        CryptoCandle(
          at: at,
          open: open,
          high: high,
          low: max(low, 0.0000001),
          close: cursor,
        ),
      );
      cursor = open;
    }

    return CryptoSeries(
      symbol: asset.symbol,
      range: range,
      candles: reversed.reversed.toList(growable: false),
    );
  }

  Duration _stepFor(ChartRange range) => switch (range) {
    ChartRange.today => const Duration(minutes: 15),
    ChartRange.week => const Duration(hours: 2),
    ChartRange.month => const Duration(hours: 8),
    ChartRange.threeMonths => const Duration(days: 1),
    ChartRange.sixMonths => const Duration(days: 1),
    ChartRange.year => const Duration(days: 7),
  };
}
