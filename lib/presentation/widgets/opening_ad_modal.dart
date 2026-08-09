import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/glass.dart';
import '../../core/design/motion.dart';
import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../state/providers.dart';
import 'brand.dart';
import 'grid_pattern_painter.dart';
import 'liquid_glass.dart';
import 'pressable.dart';

/// Rotates available ad assets randomly with a rare chance (10%) for `ad_uma.webp`.
String selectRandomAdAsset({Random? rng}) {
  final random = rng ?? Random();

  // 10% rare chance for ad_uma.webp
  if (random.nextDouble() < 0.10) {
    return 'assets/images/ad_uma.webp';
  }

  // 90% chance to rotate between standard ads
  const standardAds = [
    'assets/images/ad_light.png',
    'assets/images/ad_dark.png',
  ];

  return standardAds[random.nextInt(standardAds.length)];
}

/// Shows the opening advertisement modal if it has not been dismissed yet.
Future<void> showOpeningAdModal(
  BuildContext context,
  WidgetRef ref, {
  String? overrideAssetPath,
}) async {
  final isDismissed = ref.read(openingAdDismissedProvider);
  if (isDismissed) return;

  final selectedAssetPath = overrideAssetPath ?? selectRandomAdAsset();

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    // The scrim is the same ink the token set uses for elevation, so the dialog
    // sits on the brand navy rather than on pure black. Held below the old 0.7 so
    // the card has something left to refract: the whole point of the glass frame
    // is that the session is still visible underneath it.
    barrierColor: AppTokens.dark.backgroundAlt.withValues(alpha: 0.58),
    builder: (dialogContext) => OpeningAdModal(
      assetPath: selectedAssetPath,
      onDismiss: () {
        ref.read(openingAdDismissedProvider.notifier).dismiss();
        if (Navigator.of(dialogContext, rootNavigator: true).canPop()) {
          Navigator.of(dialogContext, rootNavigator: true).pop();
        }
      },
    ),
  );

  // Every way out counts as having seen it. The controls call dismiss on the way
  // through, but the barrier and the Android back gesture close the route without
  // touching them, and an advertisement that came back because you tapped beside
  // it instead of on it is the most irritating possible bug.
  ref.read(openingAdDismissedProvider.notifier).dismiss();
}

/// Rotating Opening Advertisement modal dialog with theme matching and rare ad support.
///
/// The frame is glass, and that is a deliberate choice about what an
/// advertisement is. This one is uninvited: it arrives over a session the
/// customer had already started, on top of their own money. Drawn as an opaque
/// panel it read as a new screen that had replaced the dashboard. Drawn as glass,
/// with the dashboard still visible and bending through the frame around the
/// poster, it reads as an object set down on top of something that is still
/// there. That is the honest description of what it is, and it also makes the
/// single control that removes it feel like the obvious thing to do.
class OpeningAdModal extends StatefulWidget {
  const OpeningAdModal({required this.onDismiss, this.assetPath, super.key});

  final VoidCallback onDismiss;
  final String? assetPath;

  @override
  State<OpeningAdModal> createState() => _OpeningAdModalState();
}

class _OpeningAdModalState extends State<OpeningAdModal>
    with SingleTickerProviderStateMixin {
  /// Storytelling: the card is set down once, as one object, so the interruption
  /// arrives complete instead of assembling itself in front of the reader.
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: Motion.medium,
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _entrance,
    curve: Motion.emphasized,
  );

  late final Animation<Offset> _rise = Tween<Offset>(
    begin: const Offset(0, 0.06),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _entrance, curve: Motion.emphasized));

  @override
  void initState() {
    super.initState();
    _entrance.forward();
  }

  @override
  void dispose() {
    // Req 2.9: the entrance controller is released with the card.
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final activeAsset = widget.assetPath ?? selectRandomAdAsset();

    // Determine card theme based on the selected ad content rather than system mode alone.
    final isDarkCard =
        activeAsset.contains('ad_dark') || activeAsset.contains('ad_uma');

    // The frame around a dark poster stays dark in either theme, so the chrome
    // reads as part of the artwork. One branch here resolves every colour on the
    // card, instead of a light and a dark literal at each call site.
    final card = isDarkCard ? AppTokens.dark : tokens;

    // The glass follows the poster too, for the same reason the tokens do. A pale
    // frosted frame around dark artwork reads as a mount around a photograph
    // rather than as the same object.
    final frame = isDarkCard ? Glass.dark.panel : Glass.light.panel;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: Space.x4,
        vertical: Space.x6,
      ),
      child: Center(
        child: AnimatedBuilder(
          animation: _entrance,
          builder: (context, child) {
            if (Motion.isReduced(context)) return child!;
            return FadeTransition(
              opacity: _fade,
              child: SlideTransition(position: _rise, child: child),
            );
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 620),
            child: FrostPane(
              radius: AppRadius.xl,
              recipe: frame,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.x5,
                      Space.x4,
                      Space.x4,
                      Space.x3,
                    ),
                    child: Row(
                      children: [
                        const FrostMark(size: 26),
                        const SizedBox(width: Space.x2),
                        Text(
                          'FrostBank',
                          style: AppType.titleMedium.copyWith(
                            color: card.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        // Integrated Skip / Close Pill Button
                        Pressable(
                          onTap: widget.onDismiss,
                          semanticLabel: 'Skip advertisement',
                          borderRadius: AppRadius.pill,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Space.x3,
                              vertical: Space.x1,
                            ),
                            decoration: BoxDecoration(
                              color: card.surface,
                              borderRadius: AppRadius.all(AppRadius.pill),
                              border: Border.all(color: card.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Skip',
                                  style: AppType.labelMedium.copyWith(
                                    color: card.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: Space.x1),
                                Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: card.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Main Image Poster Display
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.x3),
                      child: ClipRRect(
                        borderRadius: AppRadius.all(AppRadius.lg),
                        child: Image.asset(
                          activeAsset,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return isDarkCard
                                ? _DarkAdFallback(tokens: card)
                                : _LightAdFallback(tokens: card);
                          },
                        ),
                      ),
                    ),
                  ),

                  // Bottom Action Pill Button Bar
                  Padding(
                    padding: const EdgeInsets.all(Space.x4),
                    child: Pressable(
                      onTap: widget.onDismiss,
                      borderRadius: AppRadius.pill,
                      child: Container(
                        width: double.infinity,
                        height: Layout.minTapTarget + Space.x1,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: AppRadius.all(AppRadius.pill),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: card.gradientPrimary,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: card.accent.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  isDarkCard
                                      ? 'Get Started Now'
                                      : 'Experience Smarter Banking',
                                  style: AppType.titleMedium.copyWith(
                                    color: card.textOnBrand,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: Space.x2),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: card.textOnBrand,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fallback Light Mode layout if image asset is missing.
class _LightAdFallback extends StatelessWidget {
  const _LightAdFallback({required this.tokens});

  /// Resolved from the card rather than from the platform theme, so the fallback
  /// matches the frame it is drawn inside.
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: tokens.background),
    child: Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: GridPatternPainter(
              lineColor: tokens.border.withValues(alpha: 0.6),
              gridSize: 28,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(Space.x5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'The Future of Banking is Digital.',
                style: AppType.displayMedium.copyWith(
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: Space.x3),
              Text(
                'Banking is no longer just transactions. It is speed, security, and smart financial control.',
                style: AppType.bodyMedium.copyWith(color: tokens.textSecondary),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Fallback Dark Mode layout if image asset is missing.
class _DarkAdFallback extends StatelessWidget {
  const _DarkAdFallback({required this.tokens});

  /// Resolved from the card rather than from the platform theme, so the fallback
  /// matches the frame it is drawn inside.
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: tokens.background),
    child: Padding(
      padding: const EdgeInsets.all(Space.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Pay Your Way,\nAnytime',
            style: AppType.displayMedium.copyWith(color: tokens.info),
          ),
          const SizedBox(height: Space.x3),
          Text(
            'Send, receive, and manage money effortlessly',
            style: AppType.bodyMedium.copyWith(color: tokens.textSecondary),
          ),
        ],
      ),
    ),
  );
}
