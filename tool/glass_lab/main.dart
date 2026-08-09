// Render harness for the app shell's glass.
//
// Not part of the application. Its only job is to photograph the shipped
// navigation bar so a reviewer can put it beside a reference and pick one.
//
// It stages the two situations the bar is actually in, and only those two. An
// earlier version staged the bar over the full brand gradient, which looked like
// a harder test and was in fact an easier one: a smooth gradient has no structure,
// so the one question worth asking about a lens - does anything visibly bend when
// it crosses the boundary - could not be asked. Both phones now put a list of
// transactions behind the bar, because that is what is behind it on the device,
// and it is content a reviewer can check for displacement glyph by glyph.
//
// Build:
//   flutter build web -t tool/glass_lab/main.dart --release -o build/glass_lab
//
// On the web the engine is Skia, which has no live backdrop shader, so the lens
// needs a [LiquidGlassView] to have something to refract. That wrapper is a
// property of this harness, not of the application: on the phone Impeller samples
// the live backdrop with no setup.

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:mobile_bank_app/core/design/theme.dart';
import 'package:mobile_bank_app/core/design/tokens.dart';
import 'package:mobile_bank_app/core/design/typography.dart';
import 'package:mobile_bank_app/presentation/shell/app_shell.dart';
import 'package:mobile_bank_app/presentation/widgets/brand.dart';

void main() => runApp(const GlassLab());

/// Phone the reference screenshots were taken on.
const Size _phone = Size(390, 844);

/// `?mode=full` renders the bar as shipped, `?mode=bare` renders the pane with
/// nothing in it, and `?mode=off` leaves the bar out entirely.
///
/// The three together are the instrument. Subtracting `off` from `bare` isolates
/// exactly what the glass does to its own backdrop, in the same pixels, which is
/// the only honest way to measure a transparent surface.
enum _Mode { full, bare, off }

_Mode get _mode => switch (Uri.base.queryParameters['mode']) {
  'bare' => _Mode.bare,
  'off' => _Mode.off,
  _ => _Mode.full,
};

/// `?bar=ref` swaps our bar for the package's own [LiquidGlassBottomNavBar] at
/// its documented [LiquidGlassBottomNavBar.defaultStyle], in the same rectangle
/// over the same backdrop.
///
/// This is the control the comparison needed from the start and did not have. The
/// reference material available to look at was a promotional gif of that bar over
/// album art, and ours sits over a list of transactions, so every earlier round
/// compared two panes over two different backdrops. That is not a blind test of
/// the glass, it is a test of what happens to be behind it - a reviewer can always
/// tell which is which, and worse, a pane that scrambles 12 pixel type may look
/// flawless over a photograph. Rendering the reference bar here, on our content,
/// in the same renderer and the same shot, makes the two panes differ in exactly
/// one thing.
bool get _refBar => Uri.base.queryParameters['bar'] == 'ref';

class GlassLab extends StatelessWidget {
  const GlassLab({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    home: const _Stage(),
  );
}

/// Both brightnesses side by side, each over its own content sheet.
class _Stage extends StatelessWidget {
  const _Stage();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF3A3A42),
    child: Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final dark in [false, true])
              Padding(
                padding: const EdgeInsets.all(16),
                child: RepaintBoundary(
                  child: SizedBox.fromSize(
                    size: _phone,
                    child: Theme(
                      data: dark ? AppTheme.dark() : AppTheme.light(),
                      child: const _Phone(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _Phone extends StatelessWidget {
  const _Phone();

  @override
  Widget build(BuildContext context) {
    // Material, because Flutter marks text with no Material ancestor by drawing
    // a yellow underline under it, which would land in every screenshot.
    return Material(
      color: context.tokens.backgroundAlt,
      child: LiquidGlassView(
        // 3, not the default 1.
        //
        // A measurement correctness fix, not a look fix. On Skia the view captures
        // the background into a texture and the lens refracts that texture; at
        // pixelRatio 1 the capture is one device pixel per logical pixel, and this
        // harness shoots at a device pixel ratio of 2, so everything seen through
        // the lens would be upsampled before it reached the screen. That puts a
        // blur floor under every reading which has nothing to do with the
        // application's own blur. On the phone Impeller samples the live backdrop
        // and none of this applies.
        // Swept over 1, 2 and 3 while chasing the mangled transmitted text
        // described in [Glass.light]'s lensBand. It made no difference at all -
        // 2 and 3 were bit identical and 1 was within a hundredth on every
        // reading - so the capture resolution was not the cause and this is back
        // to a fixed value. Kept at 3 rather than 1 for the original reason: the
        // shot is taken at a device pixel ratio of 2, and capturing below that
        // would upsample everything seen through the lens and put a blur floor
        // under every measurement that has nothing to do with the pane.
        pixelRatio: 3,
        // [backgroundWidget] is drawn to the screen as well as captured for the
        // lens to sample, so this is the one and only copy of the backdrop.
        //
        // An earlier version of this harness also drew the backdrop inside
        // [child], on the assumption that this slot was capture-only. It is not;
        // the package documents it as rendering behind the content. That copy was
        // pixel identical and sat underneath the bar, so removing it changed the
        // render by a mean of zero per channel - it was wasted paint rather than a
        // fault. Recording it because it was the first suspect for the doubled
        // text two reviewers reported, and it was innocent: the doubling was a
        // fold in the lens's own displacement, which is the material's problem and
        // was fixed there.
        backgroundWidget: const _Backdrop(),
        child: _mode == _Mode.off
            ? null
            : _refBar
            ? const _ReferenceBar()
            : Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  height: 100,
                  child: ShellNavBarPreview(
                    activeBranch: 0,
                    showContent: _mode == _Mode.full,
                  ),
                ),
              ),
      ),
    );
  }
}

/// The package's bar, sized and positioned to occupy our bar's exact rectangle.
///
/// Width, height and bottom margin are overridden away from the package's
/// defaults on purpose. They are the only values changed: the geometry has to
/// match ours or the two panes would be photographed at different sizes over
/// different pieces of the backdrop, and pane size is one of the things being
/// argued about. Everything optical is left at [defaultStyle].
class _ReferenceBar extends StatelessWidget {
  const _ReferenceBar();

  @override
  Widget build(BuildContext context) => Align(
    // Not optional, and it cost a round to find out. [LiquidGlassView] lays its
    // child out under tight, full-screen constraints, so the bar's own
    // `SizedBox(width: 350, height: 68)` was being stretched to the whole phone:
    // the first reference shot was a full-screen lens with no capsule in it, which
    // is not the reference bar and is not a comparison. An [Align] fills the
    // constraints itself and hands its child loose ones, which is also how our own
    // bar is mounted here, so the two now sit in the same rectangle.
    //
    // It was not a wasted round. Blown up to 390x844 the reference's shader showed
    // the same doubled transmitted text that reviewers had flagged in our bar,
    // which is what confirmed the fold was a property of the refraction being
    // driven too hard rather than a mistake unique to our recipe.
    alignment: Alignment.bottomCenter,
    child: Padding(
      // Matches the shipped bar's 16 pixel gap above the bottom edge.
      padding: const EdgeInsets.only(bottom: 16),
      child: LiquidGlassBottomNavBar(
        items: const [
          LiquidGlassTabBarItem(
            icon: Icons.receipt_long_outlined,
            label: 'Activity',
          ),
          LiquidGlassTabBarItem(icon: Icons.credit_card, label: 'Cards'),
          LiquidGlassTabBarItem(icon: Icons.home_rounded, label: 'Home'),
          LiquidGlassTabBarItem(icon: Icons.pie_chart, label: 'Hub'),
          LiquidGlassTabBarItem(icon: Icons.person, label: 'Profile'),
        ],
        selectedIndex: 0,
        onChanged: _ignore,
        width: 350,
        height: 68,
      ),
    ),
  );

  static void _ignore(int _) {}
}

/// Stand in for the dashboard: the brand gradient header, then the content sheet,
/// with rows still running past where the bar sits.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return ColoredBox(
      color: tokens.backgroundAlt,
      child: Column(
        children: [
          const SizedBox(
            height: 300,
            child: FrostBackdrop(child: SizedBox.expand()),
          ),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.surfaceRaised,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.xl),
                ),
              ),
              child: const _Rows(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Rows extends StatelessWidget {
  const _Rows();

  // Long enough that rows are still passing behind the bar at the bottom of the
  // screen. A backdrop that has run out of content by the time it reaches the bar
  // cannot show whether the pane is transparent, which is the whole question.
  static const _entries = <(String, String, String)>[
    ('HT', 'Halden Transit Authority', r'-$3.25'),
    ('VG', 'Verdant Grocers', r'-$84.37'),
    ('LC', 'Ludlow Coffee House', r'-$6.85'),
    ('MW', 'Marchmont Water', r'-$41.00'),
    ('SB', 'Stonebridge Books', r'-$18.90'),
    ('KP', 'Kelso Pharmacy', r'-$12.40'),
    ('AT', 'Aldgate Transport', r'-$2.80'),
    ('BN', 'Brayton Newsagent', r'-$9.15'),
    ('CF', 'Corbie Fishmonger', r'-$27.60'),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.x5, Space.x5, Space.x5, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transactions',
            style: AppType.titleLarge.copyWith(color: tokens.textPrimary),
          ),
          const SizedBox(height: Space.x4),
          for (final (initials, name, amount) in _entries)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.x4),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tokens.interactiveSecondary,
                    ),
                    child: Text(
                      initials,
                      style: AppType.labelMedium.copyWith(
                        color: tokens.isDark
                            ? tokens.textPrimary
                            : Palette.primaryPurple,
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.x3),
                  Expanded(
                    child: Text(
                      name,
                      style: AppType.bodyLarge.copyWith(
                        color: tokens.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    amount,
                    style: AppType.bodyLarge.copyWith(
                      color: tokens.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
