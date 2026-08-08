import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_bank_app/core/design/theme.dart';
import 'package:mobile_bank_app/core/format/money.dart';
import 'package:mobile_bank_app/data/mock_data_source.dart';
import 'package:mobile_bank_app/data/mock_seed.dart';
import 'package:mobile_bank_app/presentation/screens/dashboard_screen.dart';
import 'package:mobile_bank_app/presentation/screens/login_screen.dart';
import 'package:mobile_bank_app/presentation/widgets/states.dart';
import 'package:mobile_bank_app/state/providers.dart';

MockDataSource _instantSource() =>
    MockDataSource(now: DateTime(2026, 8, 5))
      ..latencyOverride = (() => Duration.zero);

class _DismissedAdController extends OpeningAdDismissedController {
  @override
  bool build() => true;
}

Widget _harness(Widget child, {MockDataSource? source}) => ProviderScope(
  retry: noAutomaticRetry,
  overrides: [
    mockDataSourceProvider.overrideWithValue(source ?? _instantSource()),
    openingAdDismissedProvider.overrideWith(_DismissedAdController.new),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: child),
);

void main() {
  testWidgets('dashboard shows skeletons first, then the seeded balance', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const DashboardScreen()));

    expect(find.byType(SkeletonBlock), findsWidgets);

    await tester.pumpAndSettle();

    expect(find.text(Money.format(12480.55)), findsWidgets);
    expect(find.text('Transactions'), findsOneWidget);
    expect(find.text('Finance Hub'), findsOneWidget);
    expect(find.byType(SkeletonBlock), findsNothing);
  });

  testWidgets('hiding balances replaces every figure with the mask', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const DashboardScreen()));
    await tester.pumpAndSettle();

    expect(find.text(Money.format(12480.55)), findsWidgets);

    await tester.tap(find.bySemanticsLabel('Hide balances'));
    await tester.pumpAndSettle();

    expect(find.text(Money.format(12480.55)), findsNothing);
    expect(find.text(Money.maskGlyphs), findsWidgets);
  });

  testWidgets('quick actions and the Finance Hub render their four entries', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const DashboardScreen()));
    await tester.pumpAndSettle();

    for (final label in ['Add money', 'Send money', 'Scan', 'History']) {
      expect(find.text(label), findsOneWidget);
    }
    for (final label in ['Savings', 'Crypto', 'Split Bills', 'Time Deposit']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('login opens clean form and allows sign in', (tester) async {
    await tester.pumpWidget(_harness(const LoginScreen()));

    expect(find.text('WELCOME BACK'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), MockSeed.demoEmail);
    await tester.enterText(find.byType(TextField).at(1), MockSeed.demoPassword);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
  });

  testWidgets('a repository failure renders an inline retry', (tester) async {
    final source = _instantSource()..errorSimulation.add('accounts');
    await tester.pumpWidget(_harness(const DashboardScreen(), source: source));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorStateView), findsWidgets);
    expect(find.text('Try again'), findsWidgets);
  });
}
