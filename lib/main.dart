import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/design/theme.dart';
import 'core/persistence/persistence_store.dart';
import 'core/supabase_config.dart';
import 'presentation/router.dart';
import 'presentation/widgets/app_lock_scope.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await SupabaseConfig.initialize();

  // Persistence_Store is opened before the first frame so preference reads are
  // synchronous. Hydrating later would show the default theme and then correct
  // it, which reads as a flash on every launch.
  final store = await openPersistenceStore();

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
