import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'core/design/theme.dart';
import 'core/persistence/persistence_store.dart';
import 'core/supabase_config.dart';
import 'presentation/router.dart';
import 'presentation/widgets/app_lock_scope.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Compile the lens fragment programs before the first frame.
  //
  // Every glass surface in the application is one shared pair of programs, and
  // compiling them is the single most expensive thing that happens on the raster
  // thread. Left to itself the first lens to mount loads them asynchronously and
  // renders frosted until they arrive, which puts a stall on whichever screen
  // happens to be first - in practice the navigation bar, on the frame the user
  // has just navigated. Compiling here moves that cost into the launch sequence,
  // where there is already a wait and no motion to interrupt.
  //
  // Started without awaiting so it compiles alongside the I/O below rather than
  // in series with it: both of the awaits that follow are round trips, so this
  // costs no wall clock at all. Failure is swallowed on purpose - a build with a
  // missing shader asset should still launch, and the lens retries its own load.
  final shaders = LiquidGlassShaders.ensureLoaded().catchError((_) {});

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await SupabaseConfig.initialize();

  // Persistence_Store is opened before the first frame so preference reads are
  // synchronous. Hydrating later would show the default theme and then correct
  // it, which reads as a flash on every launch.
  final store = await openPersistenceStore();

  await shaders;

  runApp(
    ProviderScope(
      retry: noAutomaticRetry,
      overrides: [persistenceStoreProvider.overrideWithValue(store)],
      child: const FrostBankApp(),
    ),
  );
}

class FrostBankApp extends ConsumerWidget {
  const FrostBankApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final preferences = ref.watch(preferencesProvider);

    return MaterialApp.router(
      title: 'FrostBank',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: preferences.themeMode,
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        // Keeps very large system scales from breaking layouts while still
        // honouring the user's preference up to 1.4.
        maxScaleFactor: 1.4,
        child: AppLockScope(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
