/// Outbound API configuration.
///
/// Requirement 5.9 forbids any API key in the application source, so the key
/// carries no default value and is supplied at build time:
///
/// ```
/// flutter run --dart-define=TWELVE_DATA_API_KEY=your_key
/// ```
///
/// When the define is absent, [hasTwelveDataKey] is false and the market data
/// repository stays on its mock rates rather than issuing an unauthenticated
/// request that would fail.
library;

abstract final class ApiConfig {
  static const String twelveDataBaseUrl = 'https://api.twelvedata.com';

  static const String twelveDataApiKey = String.fromEnvironment(
    'TWELVE_DATA_API_KEY',
  );

  static bool get hasTwelveDataKey => twelveDataApiKey.trim().isNotEmpty;

  /// How long a request is given before it is treated as a failure. Market data
  /// that arrives late is worse than a retry control.
  static const Duration networkTimeout = Duration(seconds: 12);

  /// The free plan allows eight credits a minute, and one symbol in a quote or
  /// one time series call costs one credit. These two windows keep the
  /// application inside that budget without the user ever seeing a rate limit.
  static const Duration quoteCacheWindow = Duration(seconds: 20);
  static const Duration seriesCacheWindow = Duration(minutes: 2);

  /// Spacing between two outbound calls, so a burst of taps cannot spend the
  /// whole minute's budget at once.
  static const Duration minRequestSpacing = Duration(milliseconds: 250);
}
