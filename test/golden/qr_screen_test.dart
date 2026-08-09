import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_bank_app/presentation/screens/qr_screen.dart';

import 'golden_harness.dart';

/// The QR payment surface as it opens, so its finish can be put beside Transfer
/// and Deposit rather than assumed to match them.
///
/// Only the code surface is captured. The pay surface is a camera preview, which
/// needs a platform channel and would render as an error view here, so a golden
/// of it would record the absence of a camera rather than the design.
void main() {
  setUpAll(loadAppFonts);

  testWidgets('qr payments', (tester) async {
    await pumpForGolden(tester, const QRScreen());
    await expectLater(
      find.byType(QRScreen),
      matchesGoldenFile('goldens/qr_screen.png'),
    );
  });
}
