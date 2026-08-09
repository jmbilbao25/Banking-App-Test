import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_bank_app/core/design/glass.dart';
import 'package:mobile_bank_app/core/design/theme.dart';
import 'package:mobile_bank_app/core/design/tokens.dart';
import 'package:mobile_bank_app/core/design/typography.dart';
import 'package:mobile_bank_app/presentation/widgets/brand.dart';
import 'package:mobile_bank_app/presentation/widgets/liquid_glass.dart';

import 'golden_harness.dart';

/// A specimen sheet for the glass material itself.
///
/// The other fourteen goldens render screens, and every one of them pumps the
/// screen directly rather than through the shell, so not one of them contains the
/// navigation bar. The bar is the most visible piece of glass in the application
/// and it had no visual coverage at all, which is how it drifted into looking
/// like a grey slab without anything failing.
///
/// This renders the material on its own instead: both tiers, at the geometry the
/// bar and the cards actually use, over the brand backdrop they actually sit on.
/// It cannot judge the bar's contents, but it does pin the thing they sit in, and
/// it gives the material somewhere to be looked at.
///
/// Note what these images can and cannot show. Under `flutter test` there is no
/// Impeller, so the lens degrades to its frosted path and the refraction is
/// absent here by design. What these pin is the geometry, the washes, the rim and
/// the sheen. The refraction has to be judged on a device.
void main() {
  setUpAll(loadAppFonts);

  Future<void> pumpSpecimen(WidgetTester tester, {required bool dark}) async {
    tester.view
      ..physicalSize = goldenViewport * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: FrostBackdrop(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(Space.x5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Chrome tier',
                        style: AppType.labelMedium.copyWith(
                          color: context.tokens.textOnBrand,
                        ),
                      ),
                      const SizedBox(height: Space.x3),
                      // The navigation bar's own geometry: 68 tall, stadium.
                      SizedBox(
                        height: 68,
                        child: LiquidGlass(
                          radius: 34,
                          child: Center(
                            child: Text(
                              'Activity',
                              style: AppType.labelSmall.copyWith(
                                color: Glass.of(context).onGlass,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: Space.x8),
                      Text(
                        'Panel tier',
                        style: AppType.labelMedium.copyWith(
                          color: context.tokens.textOnBrand,
                        ),
                      ),
                      const SizedBox(height: Space.x3),
                      GlassPanel(
                        child: Text(
                          'Available',
                          style: AppType.titleMedium.copyWith(
                            color: Glass.panelOf(context).onGlass,
                          ),
                        ),
                      ),
                      const SizedBox(height: Space.x8),
                      Text(
                        'Icon controls',
                        style: AppType.labelMedium.copyWith(
                          color: context.tokens.textOnBrand,
                        ),
                      ),
                      const SizedBox(height: Space.x3),
                      Row(
                        children: [
                          GlassIconButton(
                            icon: Icons.remove_red_eye_outlined,
                            label: 'Hide balances',
                            onTap: () {},
                          ),
                          const SizedBox(width: Space.x3),
                          GlassIconButton(
                            icon: Icons.notifications_none_rounded,
                            label: 'Notifications',
                            badgeCount: 3,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('glass material, dark', (tester) async {
    await pumpSpecimen(tester, dark: true);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/glass_material_dark.png'),
    );
  });

  testWidgets('glass material, light', (tester) async {
    await pumpSpecimen(tester, dark: false);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/glass_material_light.png'),
    );
  });

  testWidgets('reduced transparency collapses the pane to an opaque fill', (
    tester,
  ) async {
    tester.view
      ..physicalSize = goldenViewport * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: MediaQuery(
          data: const MediaQueryData(highContrast: true),
          child: Builder(
            builder: (context) => Scaffold(
              body: FrostBackdrop(
                child: Center(
                  child: SizedBox(
                    width: 300,
                    height: 68,
                    child: LiquidGlass(
                      radius: 34,
                      child: Center(
                        child: Text(
                          'Activity',
                          style: AppType.labelSmall.copyWith(
                            color: Glass.of(context).onGlass,
                          ),
                        ),
                      ),
                    ),
                  ),
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
      matchesGoldenFile('goldens/glass_material_reduced.png'),
    );
  });
}
