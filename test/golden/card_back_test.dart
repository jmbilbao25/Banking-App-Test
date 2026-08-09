import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_bank_app/core/design/theme.dart';
import 'package:mobile_bank_app/core/design/tokens.dart';
import 'package:mobile_bank_app/domain/models.dart';
import 'package:mobile_bank_app/presentation/widgets/brand.dart';
import 'package:mobile_bank_app/presentation/widgets/card_face.dart';

import 'golden_harness.dart';

/// The back of the card, on all three colourways.
///
/// The front has had golden coverage since the visual gate went in. The back is
/// new, it carries the only four pieces of information in the application that
/// sit behind App_Lock, and its layout is the kind that breaks quietly: every
/// measurement on it is a fraction of the card width, so a change to the deck's
/// sizing moves the stripe, the panel and the code all at once.
///
/// Three cards rather than one, because the id decides the colourway and the back
/// has to stay legible on all of them. The digits here are the seeded mock
/// values, which are Luhn valid and belong to no one.
void main() {
  setUpAll(loadAppFonts);

  BankCard card(String id, CardNetwork network, CardStatus status) => BankCard(
    id: id,
    accountId: 'acc_wallet',
    label: 'FrostBank Signature',
    holderName: 'Ava Mercado',
    number: '4137 8947 1175 1879',
    cvc: '678',
    expiry: '09/29',
    network: network,
    kind: CardKind.credit,
    status: status,
    balance: 12106.20,
    currencyCode: 'USD',
    spendingLimit: 5000,
  );

  testWidgets('card back, three colourways', (tester) async {
    tester.view
      ..physicalSize = goldenViewport * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: Scaffold(
          body: FrostBackdrop(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(Space.x4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // One at the width the deck actually hands it, which is what
                    // pins whether the digits and the code stay readable.
                    //
                    // The height comes from CardFace, deliberately. The back takes
                    // its box from its parent exactly as the front does, because
                    // the two swap inside a FlipCard and a back that sized itself
                    // would change shape halfway through the turn.
                    // Frozen at full size, deliberately. This is the case that
                    // can actually fail: frost is pale, the digits are light, and
                    // the only text in the application that sits behind App_Lock
                    // has to stay readable through it. An active card back cannot
                    // catch that regression.
                    SizedBox(
                      width: 248,
                      height: CardFace.heightFor(248),
                      child: CardBackFace(
                        card: card('card_003', CardNetwork.visa, CardStatus.frozen),
                      ),
                    ),
                    const SizedBox(height: Space.x5),
                    // Two more ids, so the hash lands on the other colourways.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final entry in const [
                          ('card_002', CardNetwork.mastercard, CardStatus.active),
                          ('card_001', CardNetwork.visa, CardStatus.active),
                        ]) ...[
                          SizedBox(
                            width: 132,
                            height: CardFace.heightFor(132),
                            child: CardBackFace(
                              card: card(entry.$1, entry.$2, entry.$3),
                            ),
                          ),
                          const SizedBox(width: Space.x4),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/card_back.png'),
    );
  });
}
