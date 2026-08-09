import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_bank_app/core/design/theme.dart';
import 'package:mobile_bank_app/presentation/screens/account_detail_screen.dart';
import 'package:mobile_bank_app/presentation/screens/deposit_screen.dart';
import 'package:mobile_bank_app/presentation/screens/savings_screen.dart';
import 'package:mobile_bank_app/presentation/screens/split_bills_screen.dart';
import 'package:mobile_bank_app/presentation/screens/transfer_screen.dart';

import 'golden_harness.dart';

/// The money movement screens, rendered so their finish can be compared against
/// the dashboard rather than assumed.
void main() {
  setUpAll(loadAppFonts);

  // The dark renders matter more than usual here. These screens previously
  // branched on `isDark` by hand on almost every line, and the migration deleted
  // those branches in favour of tokens that resolve per theme. A dark golden is
  // what proves the tokens actually carry the theme rather than the branches
  // having been load bearing.
  testWidgets('transfer, dark', (tester) async {
    await pumpForGolden(
      tester,
      const TransferScreen(),
      theme: AppTheme.dark(),
    );
    await expectLater(
      find.byType(TransferScreen),
      matchesGoldenFile('goldens/transfer_dark.png'),
    );
  });

  testWidgets('deposit, dark', (tester) async {
    await pumpForGolden(
      tester,
      const DepositScreen(),
      theme: AppTheme.dark(),
    );
    await expectLater(
      find.byType(DepositScreen),
      matchesGoldenFile('goldens/deposit_dark.png'),
    );
  });

  testWidgets('transfer', (tester) async {
    await pumpForGolden(tester, const TransferScreen());
    await expectLater(
      find.byType(TransferScreen),
      matchesGoldenFile('goldens/transfer.png'),
    );
  });

  testWidgets('deposit', (tester) async {
    await pumpForGolden(tester, const DepositScreen());
    await expectLater(
      find.byType(DepositScreen),
      matchesGoldenFile('goldens/deposit.png'),
    );
  });

  testWidgets('savings', (tester) async {
    await pumpForGolden(tester, const SavingsScreen());
    await expectLater(
      find.byType(SavingsScreen),
      matchesGoldenFile('goldens/savings.png'),
    );
  });

  testWidgets('split bills', (tester) async {
    await pumpForGolden(tester, const SplitBillsScreen());
    await expectLater(
      find.byType(SplitBillsScreen),
      matchesGoldenFile('goldens/split_bills.png'),
    );
  });

  testWidgets('account detail', (tester) async {
    await pumpForGolden(
      tester,
      const AccountDetailScreen(accountId: 'acc_wallet'),
    );
    await expectLater(
      find.byType(AccountDetailScreen),
      matchesGoldenFile('goldens/account_detail.png'),
    );
  });
}
