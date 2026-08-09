import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_bank_app/core/design/theme.dart';
import 'package:mobile_bank_app/core/design/tokens.dart';
import 'package:mobile_bank_app/presentation/screens/opening_ad_screen.dart';
import 'package:mobile_bank_app/presentation/widgets/opening_ad_modal.dart';
import 'package:mobile_bank_app/presentation/widgets/pressable.dart';
import 'package:mobile_bank_app/state/providers.dart';

class _FakeRandom implements Random {
  _FakeRandom(this.fixedValue);

  final double fixedValue;

  @override
  double nextDouble() => fixedValue;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;
}

Widget _harness(Widget child, {bool isDark = false, double textScale = 1.0}) =>
    ProviderScope(
      child: MaterialApp(
        theme: isDark ? AppTheme.dark() : AppTheme.light(),
        builder: (context, inner) => MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: inner!,
        ),
        home: child,
      ),
    );

/// Pumps on a tall viewport, so a layout that cannot absorb larger text
/// overflows rather than being clipped off screen unnoticed.
Future<void> _pumpTall(
  WidgetTester tester,
  Widget widget, {
  Size size = const Size(420, 3000),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

/// The rendered size of the tap target that owns [inner].
Size _tapTarget(WidgetTester tester, Finder inner) {
  final pressable = find.ancestor(of: inner, matching: find.byType(Pressable));
  expect(pressable, findsOneWidget);
  return tester.getSize(pressable);
}

void main() {
  test('selectRandomAdAsset selects ad_uma.webp on low roll (< 0.10)', () {
    final rng = _FakeRandom(0.05);
    final selected = selectRandomAdAsset(rng: rng);
    expect(selected, equals('assets/images/ad_uma.webp'));
  });

  test('selectRandomAdAsset selects standard ad on normal roll (>= 0.10)', () {
    final rng = _FakeRandom(0.50);
    final selected = selectRandomAdAsset(rng: rng);
    expect(selected, equals('assets/images/ad_light.png'));
  });

  testWidgets('OpeningAdModal renders Light Mode ad asset correctly', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        OpeningAdModal(
          onDismiss: () {},
          assetPath: 'assets/images/ad_light.png',
        ),
        isDark: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FrostBank'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Experience Smarter Banking'), findsOneWidget);
  });

  testWidgets('OpeningAdModal renders Dark Mode ad asset correctly', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        OpeningAdModal(onDismiss: () {}, assetPath: 'assets/images/ad_dark.png'),
        isDark: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FrostBank'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Get Started Now'), findsOneWidget);
  });

  testWidgets('OpeningAdModal renders ad_uma.webp rare asset correctly', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        OpeningAdModal(onDismiss: () {}, assetPath: 'assets/images/ad_uma.webp'),
        isDark: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FrostBank'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Get Started Now'), findsOneWidget);
  });

  testWidgets('Tapping Skip fires onDismiss callback and updates state', (
    tester,
  ) async {
    late ProviderContainer container;

    final widget = UncontrolledProviderScope(
      container: container = ProviderContainer(),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              container.read(openingAdDismissedProvider.notifier).dismiss();
            },
            child: const Text('Dismiss Ad'),
          ),
        ),
      ),
    );

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(container.read(openingAdDismissedProvider), isFalse);

    await tester.tap(find.text('Dismiss Ad'));
    await tester.pumpAndSettle();

    expect(container.read(openingAdDismissedProvider), isTrue);
  });

  group('Req 4.1: the dismiss control is named', () {
    // An advertisement is the one surface where the dismiss control has to be
    // findable without sight, so it is named by its action rather than left to
    // be inferred from a close glyph.
    testWidgets('the modal skip control speaks its action', (tester) async {
      await tester.pumpWidget(
        _harness(
          OpeningAdModal(
            onDismiss: () {},
            assetPath: 'assets/images/ad_light.png',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Skip advertisement'), findsOneWidget);
    });

    for (final isDark in [false, true]) {
      final mode = isDark ? 'dark' : 'light';
      testWidgets('the $mode ad screen skip control speaks its action', (
        tester,
      ) async {
        await _pumpTall(
          tester,
          _harness(const OpeningAdScreen(), isDark: isDark),
        );

        expect(find.bySemanticsLabel('Skip advertisement'), findsOneWidget);
      });
    }
  });

  group('Req 4.2: the dismiss control clears the 48 by 48 floor', () {
    testWidgets('the modal skip pill is at least 48 by 48', (tester) async {
      await tester.pumpWidget(
        _harness(
          OpeningAdModal(
            onDismiss: () {},
            assetPath: 'assets/images/ad_dark.png',
          ),
          isDark: true,
        ),
      );
      await tester.pumpAndSettle();

      final size = _tapTarget(tester, find.text('Skip'));
      expect(size.width, greaterThanOrEqualTo(Layout.minTapTarget));
      expect(size.height, greaterThanOrEqualTo(Layout.minTapTarget));
    });

    for (final isDark in [false, true]) {
      final mode = isDark ? 'dark' : 'light';
      testWidgets('the $mode ad screen skip pill is at least 48 by 48', (
        tester,
      ) async {
        await _pumpTall(
          tester,
          _harness(const OpeningAdScreen(), isDark: isDark),
        );

        final size = _tapTarget(tester, find.text('Skip'));
        expect(size.width, greaterThanOrEqualTo(Layout.minTapTarget));
        expect(size.height, greaterThanOrEqualTo(Layout.minTapTarget));
      });
    }
  });

  group('Req 4.3: the opening ad surface renders at a 1.3 text scale', () {
    // A RenderFlex overflow or a failed layout assertion surfaces through
    // takeException, so these are real layout checks rather than smoke tests.
    for (final scale in [1.0, 1.3]) {
      testWidgets('the light modal at $scale does not overflow', (
        tester,
      ) async {
        await _pumpTall(
          tester,
          _harness(
            OpeningAdModal(
              onDismiss: () {},
              assetPath: 'assets/images/ad_light.png',
            ),
            textScale: scale,
          ),
          size: const Size(420, 900),
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('the dark modal at $scale does not overflow', (tester) async {
        await _pumpTall(
          tester,
          _harness(
            OpeningAdModal(
              onDismiss: () {},
              assetPath: 'assets/images/ad_dark.png',
            ),
            isDark: true,
            textScale: scale,
          ),
          size: const Size(420, 900),
        );

        expect(tester.takeException(), isNull);
      });

      for (final isDark in [false, true]) {
        final mode = isDark ? 'dark' : 'light';
        testWidgets('the $mode ad screen at $scale does not overflow', (
          tester,
        ) async {
          await _pumpTall(
            tester,
            _harness(
              const OpeningAdScreen(),
              isDark: isDark,
              textScale: scale,
            ),
          );

          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('the ad screen offers its call to action in both themes', () {
    testWidgets('the light layout leads with Get Started', (tester) async {
      await _pumpTall(tester, _harness(const OpeningAdScreen()));

      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('is Digital.'), findsOneWidget);
    });

    testWidgets('the dark layout leads with Get Started Now', (tester) async {
      await _pumpTall(
        tester,
        _harness(const OpeningAdScreen(), isDark: true),
      );

      expect(find.text('Get Started Now'), findsOneWidget);
      expect(find.text('Instant Transfers'), findsOneWidget);
    });
  });

  testWidgets('tapping Skip on the ad screen records the dismissal', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await _pumpTall(
      tester,
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const OpeningAdScreen(),
        ),
      ),
    );

    expect(container.read(openingAdDismissedProvider), isFalse);

    await tester.tap(find.bySemanticsLabel('Skip advertisement'));
    await tester.pumpAndSettle();

    expect(container.read(openingAdDismissedProvider), isTrue);
  });

  group('Req 1.7: the opening ad surface names no colour of its own', () {
    // The migration is only worth as much as the thing that keeps it: a hex
    // literal or a raw palette read reintroduced here fails the build.
    final files = <String>[
      'lib/presentation/screens/opening_ad_screen.dart',
      'lib/presentation/widgets/opening_ad_modal.dart',
    ];

    bool isComment(String line) {
      final trimmed = line.trimLeft();
      return trimmed.startsWith('//') ||
          trimmed.startsWith('*') ||
          trimmed.startsWith('/*');
    }

    List<String> scan(RegExp pattern) {
      final offenders = <String>[];
      for (final path in files) {
        final lines = File(path).readAsStringSync().split('\n');
        for (var i = 0; i < lines.length; i++) {
          if (isComment(lines[i])) continue;
          if (pattern.hasMatch(lines[i])) {
            offenders.add('$path:${i + 1}: ${lines[i].trim()}');
          }
        }
      }
      return offenders;
    }

    test('no raw hex colour', () {
      expect(
        scan(RegExp(r'0x[0-9a-fA-F]{6,8}')),
        isEmpty,
        reason: 'Read the colour from context.tokens instead.',
      );
    });

    test('no direct palette read', () {
      expect(
        scan(RegExp(r'\bPalette\.')),
        isEmpty,
        reason:
            'Palette is the raw brand sheet. Screens read the semantic tokens '
            'so the value resolves per theme.',
      );
    });
  });
}
