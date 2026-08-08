import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_bank_app/core/design/theme.dart';
import 'package:mobile_bank_app/presentation/screens/card_detail_screen.dart';
import 'package:mobile_bank_app/presentation/screens/dashboard_screen.dart';
import 'package:mobile_bank_app/presentation/screens/login_screen.dart';
import 'package:mobile_bank_app/presentation/screens/notifications_screen.dart';
import 'package:mobile_bank_app/presentation/screens/time_deposit_screen.dart';

import 'golden_harness.dart';

/// Renders the real screens to PNG so they can be put next to the design
/// reference in `Reference Images/image.png` and judged side by side.
///
/// These double as regression goldens: once accepted, a later change that moves
/// the layout fails here rather than silently drifting away from the reference.
/// Regenerate deliberately with:
///
///   flutter test test/golden --update-goldens
void main() {
  setUpAll(loadAppFonts);

  testWidgets('dashboard, light', (tester) async {
    await pumpForGolden(tester, const DashboardScreen());
    await expectLater(
      find.byType(DashboardScreen),
      matchesGoldenFile('goldens/dashboard_light.png'),
    );
  });

  testWidgets('dashboard, dark', (tester) async {
    await pumpForGolden(
      tester,
      const DashboardScreen(),
      theme: AppTheme.dark(),
    );
    await expectLater(
      find.byType(DashboardScreen),
      matchesGoldenFile('goldens/dashboard_dark.png'),
    );
  });

  testWidgets('login', (tester) async {
    await pumpForGolden(tester, const LoginScreen());
    await expectLater(
      find.byType(LoginScreen),
      matchesGoldenFile('goldens/login.png'),
    );
  });

  testWidgets('card detail', (tester) async {
    await pumpForGolden(tester, const CardDetailScreen(cardId: 'card_001'));
    await expectLater(
      find.byType(CardDetailScreen),
      matchesGoldenFile('goldens/card_detail.png'),
    );
  });

  testWidgets('notifications', (tester) async {
    await pumpForGolden(tester, const NotificationsScreen());
    await expectLater(
      find.byType(NotificationsScreen),
      matchesGoldenFile('goldens/notifications.png'),
    );
  });

  testWidgets('time deposit', (tester) async {
    await pumpForGolden(tester, const TimeDepositScreen());
    await expectLater(
      find.byType(TimeDepositScreen),
      matchesGoldenFile('goldens/time_deposit.png'),
    );
  });
}
