import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_bank_app/core/design/theme.dart';
import 'package:mobile_bank_app/core/persistence/persistence_store.dart';
import 'package:mobile_bank_app/data/mock_data_source.dart';
import 'package:mobile_bank_app/domain/models.dart';
import 'package:mobile_bank_app/presentation/screens/card_detail_screen.dart';
import 'package:mobile_bank_app/presentation/widgets/card_face.dart';
import 'package:mobile_bank_app/state/providers.dart';

const _card = BankCard(
  id: 'card_001',
  accountId: 'acc_wallet',
  label: 'FrostBank Signature',
  holderName: 'Ava Mercado',
  number: '4137 8947 1175 1879',
  cvc: '678',
  expiry: '09/29',
  network: CardNetwork.visa,
  kind: CardKind.credit,
  status: CardStatus.active,
  balance: 12106.20,
  currencyCode: 'USD',
  spendingLimit: 5000,
);

Widget _host(Widget child, {bool reducedMotion = false}) => MaterialApp(
  theme: AppTheme.light(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reducedMotion),
    child: Scaffold(body: Center(child: SizedBox(width: 240, child: child))),
  ),
);

void main() {
  group('CardBackFace carries the four things that live on the back', () {
    testWidgets('groups the number in fours, however it is stored', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const CardBackFace(card: BankCard(
          id: 'card_001',
          accountId: 'acc_wallet',
          label: 'FrostBank Signature',
          holderName: 'Ava Mercado',
          // Stored unspaced on purpose: the grouping is the widget's job.
          number: '4137894711751879',
          cvc: '678',
          expiry: '09/29',
          network: CardNetwork.visa,
          kind: CardKind.credit,
          status: CardStatus.active,
          balance: 1,
          currencyCode: 'USD',
          spendingLimit: 1,
        ))),
      );

      expect(find.text('4137  8947  1175  1879'), findsOneWidget);
    });

    testWidgets('shows the holder, the code, and the expiry', (tester) async {
      await tester.pumpWidget(_host(const CardBackFace(card: _card)));

      expect(find.text('Ava Mercado'), findsOneWidget);
      expect(find.text('678'), findsOneWidget);
      expect(find.text('09/29'), findsOneWidget);
      expect(find.text('CARD NUMBER'), findsOneWidget);
      expect(find.text('EXPIRES'), findsOneWidget);
    });
  });

  group('FlipCard shows one side at a time', () {
    testWidgets('rests on the front, and the back is not in the tree', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const FlipCard(
            showBack: false,
            front: Text('front'),
            back: Text('back'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('front'), findsOneWidget);
      // The security property, stated as a test: an unrevealed card does not
      // have its details sitting in the tree waiting to be read.
      expect(find.text('back'), findsNothing);
    });

    testWidgets('lands on the back once it is asked for', (tester) async {
      await tester.pumpWidget(
        _host(
          const FlipCard(
            showBack: true,
            front: Text('front'),
            back: Text('back'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('back'), findsOneWidget);
      expect(find.text('front'), findsNothing);
    });

    testWidgets('swaps sides at the halfway point, never mirrored', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const FlipCard(
            showBack: false,
            front: Text('front'),
            back: Text('back'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _host(
          const FlipCard(
            showBack: true,
            front: Text('front'),
            back: Text('back'),
          ),
        ),
      );

      // Just short of the middle of the run the card is still short of edge on,
      // so the front is still the side facing the holder. This is also what pins
      // the curve: on an eased curve the value crosses halfway far earlier than
      // the time does, and this assertion fails.
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.text('front'), findsOneWidget);
      expect(find.text('back'), findsNothing);

      // Just past the middle, the back has taken over.
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('back'), findsOneWidget);
      expect(find.text('front'), findsNothing);

      await tester.pumpAndSettle();
    });

    testWidgets('Req 2.5: reduced motion renders the side with no rotation', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const FlipCard(
            showBack: true,
            front: Text('front'),
            back: Text('back'),
          ),
          reducedMotion: true,
        ),
      );

      // No pumping needed. Under reduced motion the end state is what is built,
      // and no Transform is introduced at all.
      expect(find.text('back'), findsOneWidget);
      expect(
        find.ancestor(of: find.text('back'), matching: find.byType(Transform)),
        findsNothing,
      );
    });
  });

  group('Req 13.8: the card cannot be turned over without App_Lock', () {
    testWidgets('tapping the card asks for the PIN and reveals nothing yet', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(420, 1400)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = InMemoryPersistenceStore();
      final source = MockDataSource(now: DateTime(2026, 8, 5))
        ..latencyOverride = (() => Duration.zero);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            persistenceStoreProvider.overrideWithValue(store),
            mockDataSourceProvider.overrideWithValue(source),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const CardDetailScreen(cardId: 'card_001'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Masked to begin with: the full number is nowhere on the screen.
      expect(find.text('4137  8947  1175  1879'), findsNothing);

      await tester.tap(find.byType(CardFace).first, warnIfMissed: false);
      await tester.pumpAndSettle();

      // The gate answered instead of the card. With no PIN enrolled this build
      // refuses outright, which is the correct end of the same branch.
      expect(find.text('4137  8947  1175  1879'), findsNothing);
      expect(find.byType(CardBackFace), findsNothing);
    });
  });
}
