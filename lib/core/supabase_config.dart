import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Central configuration for Supabase integration in FrostBank.
///
/// Requirement 5.9 forbids any credential value in the application source, so
/// neither field carries a default. A build that does not pass both defines
/// runs fully offline against the mock repository layer, which is the primary
/// mode described in the design document.
///
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://your-project.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=your_anon_key
/// ```
class SupabaseConfig {
  SupabaseConfig._();

  /// Project URL, supplied at build time by `--dart-define=SUPABASE_URL=...`.
  static const String url = String.fromEnvironment('SUPABASE_URL');

  /// Anonymous key, supplied at build time by
  /// `--dart-define=SUPABASE_ANON_KEY=...`.
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// True only when both credentials were supplied at build time.
  static bool get isConfigured =>
      url.trim().isNotEmpty && anonKey.trim().isNotEmpty;

  /// Supabase is used only when it was actually configured. Without credentials
  /// the application stays on the mock repository layer rather than starting a
  /// client that cannot authenticate.
  static bool get shouldInitialize => isConfigured;

  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  /// Initializes the Supabase client if credentials are configured.
  static Future<void> initialize() async {
    if (_initialized) return;

    if (!isConfigured) {
      debugPrint(
        'Supabase credentials were not supplied at build time. '
        'FrostBank is running offline against the mock repository layer. '
        'Pass --dart-define=SUPABASE_URL and --dart-define=SUPABASE_ANON_KEY '
        'to use a live project.',
      );
      return;
    }

    try {
      await Supabase.initialize(
        url: url,
        // ignore: deprecated_member_use
        anonKey: anonKey,
        debug: kDebugMode,
      );
      _initialized = true;
      debugPrint('Supabase initialized successfully.');
    } catch (e) {
      debugPrint('Failed to initialize Supabase: $e');
    }
  }

  /// Helper getter for the global Supabase client instance.
  static SupabaseClient get client => Supabase.instance.client;
}
