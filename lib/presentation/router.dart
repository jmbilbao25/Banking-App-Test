import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/providers.dart';
import '../state/session_controller.dart';
import 'screens/account_detail_screen.dart';
import 'screens/card_detail_screen.dart';
import 'screens/cards_screen.dart';
import 'screens/crypto_detail_screen.dart';
import 'screens/crypto_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/goal_detail_screen.dart';
import 'screens/hub_screen.dart';
import 'screens/currency_selection_screen.dart';
import 'screens/create_split_bill_screen.dart';
import 'screens/login_screen.dart';
import 'screens/not_in_build_screen.dart';
import 'screens/opening_ad_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/qr_scanner_screen.dart';
import 'screens/pin_lock_screen.dart';
import 'screens/register_screen.dart';
import 'screens/savings_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/split_bill_detail_screen.dart';
import 'screens/split_bill_qr_screen.dart';
import 'screens/split_bills_screen.dart';
import 'screens/transaction_detail_screen.dart';
import 'screens/transaction_history_screen.dart';
import 'shell/app_shell.dart';
import 'shell/branch_transition.dart';

//for routing to deposit, transfer, and qr
import 'screens/deposit_screen.dart';
import 'screens/transfer_screen.dart';
import 'screens/qr_screen.dart';
import 'screens/netkeiba_race_screen.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Declarative routes plus one guard. Branch state, including scroll offset,
/// survives switching between destinations.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final location = state.matchedLocation;

      const authRoutes = {'/login', '/register', '/forgot-password', '/pin-lock'};

      return switch (session) {
        SessionUnknown() => location == '/splash' ? null : '/splash',
        SessionSignedOut() => authRoutes.contains(location) ? null : '/login',
        // Requirements 5.1 and 5.4: while App_Lock is engaged no authenticated
        // route resolves, so the dashboard cannot be reached by deep link or by
        // returning from the background.
        SessionSignedIn() => switch (location) {
          '/splash' || '/ad' => '/pin-lock',
          '/pin-lock' => ref.read(appLockProvider) ? null : '/',
          _ => ref.read(appLockProvider) ? '/pin-lock' : null,
        },
      };
    },
    errorBuilder: (context, state) =>
        RouteErrorScreen(location: state.uri.toString()),
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/ad', builder: (_, _) => const OpeningAdScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/pin-lock', builder: (_, _) => const PinLockScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(
        path: '/account/:id',
        builder: (_, state) =>
            AccountDetailScreen(accountId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/card/:id',
        builder: (_, state) =>
            CardDetailScreen(cardId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/txn/:id',
        builder: (_, state) =>
            TransactionDetailScreen(txnId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/crypto', builder: (_, _) => const CryptoScreen()),
      GoRoute(
        path: '/crypto/:code',
        builder: (_, state) =>
            CryptoDetailScreen(code: state.pathParameters['code']!),
      ),
      GoRoute(
        path: '/savings',
        builder: (_, _) => const SavingsScreen(),
      ),
      GoRoute(
        path: '/savings/:id',
        builder: (_, state) =>
            GoalDetailScreen(goalId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/currency',
        builder: (_, _) => const CurrencySelectionScreen(),
      ),
      GoRoute(
        path: '/split-bills',
        builder: (_, _) => const SplitBillsScreen(),
        routes: [
          GoRoute(
            path: 'create',
            builder: (_, _) => const CreateSplitBillScreen(),
          ),
          GoRoute(
            path: 'scan',
            builder: (_, state) => QrScannerScreen(
              initialPayload: state.uri.queryParameters['payload'],
            ),
          ),
          GoRoute(
            path: 'qr/:billId/:participantId',
            builder: (_, state) => SplitBillQrScreen(
              billId: state.pathParameters['billId']!,
              participantId: state.pathParameters['participantId']!,
            ),
          ),
          GoRoute(
            path: ':id',
            builder: (_, state) => SplitBillDetailScreen(
              billId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/soon/:feature',
        builder: (_, state) =>
            NotInBuildScreen(feature: state.pathParameters['feature']!),
      ),
      GoRoute(
        path: '/deposit',
        builder: (_, state) => const DepositScreen(),
      ),
      GoRoute(
        path: '/transfer',
        builder: (_, state) => const TransferScreen(),
      ),
      GoRoute(
        path: '/qr-scanner',
        builder: (_, state) => const QRScreen(),
      ),
      GoRoute(
        path: '/netkeiba',
        builder: (_, _) => const NetkeibaRaceScreen(),
      ),
      // The plain indexedStack constructor is not used, because it hard codes an
      // IndexedStack that swaps branches on a single frame. BranchTransition is
      // that same always mounted container with a cross fade over the swap.
      StatefulShellRoute(
        builder: (_, _, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        navigatorContainerBuilder: (_, navigationShell, children) =>
            BranchTransition(
              currentIndex: navigationShell.currentIndex,
              children: children,
            ),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/', builder: (_, _) => const DashboardScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/activity',
                builder: (_, _) => const TransactionHistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/cards', builder: (_, _) => const CardsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/hub', builder: (_, _) => const HubScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Bridges Riverpod session changes into the router so the guard re-runs.
class _SessionRefresh extends ChangeNotifier {
  _SessionRefresh(Ref ref) {
    ref.listen<SessionState>(
      sessionProvider,
      (_, _) => notifyListeners(),
      fireImmediately: false,
    );
    ref.listen<bool>(
      openingAdDismissedProvider,
      (_, _) => notifyListeners(),
      fireImmediately: false,
    );
    // A lock engaged by the background timeout has to re-run the guard, or the
    // dashboard would stay on screen until the next navigation.
    ref.listen<bool>(
      appLockProvider,
      (_, _) => notifyListeners(),
      fireImmediately: false,
    );
  }
}
