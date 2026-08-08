import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../state/providers.dart';
import 'brand.dart';
import 'grid_pattern_painter.dart';
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
    // sits on the brand navy rather than on pure black.
    barrierColor: AppTokens.dark.backgroundAlt.withValues(alpha: 0.7),
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
}

/// Rotating Opening Advertisement modal dialog with theme matching and rare ad support.
class OpeningAdModal extends StatelessWidget {
  const OpeningAdModal({required this.onDismiss, this.assetPath, super.key});

  final VoidCallback onDismiss;
  final String? assetPath;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final activeAsset = assetPath ?? selectRandomAdAsset();

    // Determine card theme based on the selected ad content rather than system mode alone.
    final isDarkCard =
        activeAsset.contains('ad_dark') || activeAsset.contains('ad_uma');

    // The frame around a dark poster stays dark in either theme, so the chrome
    // reads as part of the artwork. One branch here resolves every colour on the
    // card, instead of a light and a dark literal at each call site.
    final card = isDarkCard ? AppTokens.dark : tokens;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: Space.x4,
        vertical: Space.x6,
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 620),
          decoration: BoxDecoration(
            color: card.background,
            borderRadius: AppRadius.all(AppRadius.xl),
            border: Border.all(color: card.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: card.shadow,
                blurRadius: 36,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: AppRadius.all(AppRadius.xl),
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
                        onTap: onDismiss,
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
                    onTap: onDismiss,
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
                style: AppType.bodyMedium.copyWith(
                  color: tokens.textSecondary,
                ),
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
