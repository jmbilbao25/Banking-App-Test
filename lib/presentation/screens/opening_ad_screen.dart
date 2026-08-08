import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/motion.dart';
import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../state/providers.dart';
import '../../state/session_controller.dart';
import '../widgets/brand.dart';
import '../widgets/grid_pattern_painter.dart';
import '../widgets/pressable.dart';
import '../widgets/surfaces.dart';

/// Opening Screen Advertisement showcase.
///
/// Both layouts read the semantic token set, so light and dark are the same
/// code resolved against a different theme rather than two colour tables.
class OpeningAdScreen extends ConsumerStatefulWidget {
  const OpeningAdScreen({super.key});

  @override
  ConsumerState<OpeningAdScreen> createState() => _OpeningAdScreenState();
}

class _OpeningAdScreenState extends ConsumerState<OpeningAdScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    // Storytelling: the advertisement fades and rises once on entry, so the
    // offer arrives as one surface instead of assembling in front of the reader.
    _animController = AnimationController(vsync: this, duration: Motion.medium);

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Motion.emphasized,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Motion.emphasized),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    // Req 2.9: the entrance controller is released with the screen.
    _animController.dispose();
    super.dispose();
  }

  void _dismissAndNavigate() {
    ref.read(openingAdDismissedProvider.notifier).dismiss();
    final session = ref.read(sessionProvider);

    if (!mounted) return;
    if (GoRouter.maybeOf(context) != null) {
      if (session is SessionSignedIn) {
        context.go('/');
      } else {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        child: ResponsiveShell(
          child: AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              if (Motion.isReduced(context)) {
                return child!;
              }
              return FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(position: _slideAnim, child: child),
              );
            },
            child: tokens.isDark
                ? _DarkAdLayout(onDismiss: _dismissAndNavigate)
                : _LightAdLayout(onDismiss: _dismissAndNavigate),
          ),
        ),
      ),
    );
  }
}

/// Light Mode Advertisement layout ("The Future of Banking is Digital.")
class _LightAdLayout extends StatelessWidget {
  const _LightAdLayout({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    // The brand navy to blue fall, shared by the graphic accent and the pills.
    final brand = tokens.gradientPrimary;

    // The device mock is a dark object sitting on a light sheet, so it reads the
    // dark token set rather than inventing its own greys.
    const ink = AppTokens.dark;

    return Stack(
      children: [
        // Grid pattern background
        Positioned.fill(
          child: CustomPaint(
            painter: GridPatternPainter(
              lineColor: tokens.border.withValues(alpha: 0.6),
              gridSize: 32,
            ),
          ),
        ),

        // Top Right Curved Navy Graphic Accent
        Positioned(
          top: -40,
          right: -80,
          child: Container(
            width: 280,
            height: 480,
            decoration: BoxDecoration(
              borderRadius: AppRadius.all(AppRadius.pill),
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [brand.first, tokens.interactivePrimary, brand.last],
              ),
              boxShadow: [
                BoxShadow(
                  color: tokens.interactivePrimary.withValues(alpha: 0.3),
                  blurRadius: 32,
                  offset: const Offset(-8, 12),
                ),
              ],
            ),
          ),
        ),

        // Content
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.x6,
                vertical: Space.x4,
              ),
              child: Row(
                children: [
                  const FrostMark(size: 32),
                  const SizedBox(width: Space.x2),
                  Text(
                    'FrostBank',
                    style: AppType.titleLarge.copyWith(
                      color: tokens.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  // Skip button
                  Pressable(
                    onTap: onDismiss,
                    semanticLabel: 'Skip advertisement',
                    borderRadius: AppRadius.pill,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.x4,
                        vertical: Space.x2,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.surfaceRaised,
                        borderRadius: AppRadius.all(AppRadius.pill),
                        border: Border.all(
                          color: tokens.border.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Text(
                        'Skip',
                        style: AppType.labelLarge.copyWith(
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: Space.x4),

            // Main Text Showcase
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.x6),
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Headline with inline "Future" pill badge
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'The ',
                                style: AppType.displayLarge.copyWith(
                                  color: tokens.textPrimary,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Space.x5,
                                  vertical: Space.x2,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: AppRadius.all(AppRadius.xl),
                                  gradient: LinearGradient(
                                    colors: [
                                      tokens.interactivePrimary,
                                      brand.last,
                                      tokens.accent,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: tokens.accent.withValues(
                                        alpha: 0.4,
                                      ),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'Future',
                                  style: AppType.displayMedium.copyWith(
                                    color: tokens.textOnBrand,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: Space.x1),
                          Text(
                            'of Banking',
                            style: AppType.displayLarge.copyWith(
                              color: tokens.textPrimary,
                            ),
                          ),
                          Text(
                            'is Digital.',
                            style: AppType.displayLarge.copyWith(
                              color: tokens.textPrimary,
                            ),
                          ),

                          const SizedBox(height: Space.x4),

                          // Subtitle
                          Text(
                            'Banking is no longer just transactions. It is speed, security, and smart financial control.',
                            style: AppType.bodyLarge.copyWith(
                              color: tokens.textSecondary,
                            ),
                          ),

                          const SizedBox(height: Space.x5),

                          // Feature badges
                          Wrap(
                            direction: Axis.vertical,
                            spacing: Space.x3,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Space.x5,
                                  vertical: Space.x3,
                                ),
                                decoration: BoxDecoration(
                                  color: tokens.info,
                                  borderRadius: AppRadius.all(AppRadius.pill),
                                  boxShadow: [
                                    BoxShadow(
                                      color: tokens.info.withValues(alpha: 0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'Experience Smarter',
                                  style: AppType.titleMedium.copyWith(
                                    color: tokens.textOnBrand,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Space.x5,
                                  vertical: Space.x3,
                                ),
                                decoration: BoxDecoration(
                                  color: tokens.interactivePrimary,
                                  borderRadius: AppRadius.all(AppRadius.pill),
                                  boxShadow: [
                                    BoxShadow(
                                      color: tokens.interactivePrimary
                                          .withValues(alpha: 0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'Banking Today!',
                                  style: AppType.titleMedium.copyWith(
                                    color: tokens.textOnBrand,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Clears the device mock anchored to the bottom right.
                          const SizedBox(height: Space.x16 + Space.x10),
                        ],
                      ),
                    ),

                    // Phone Graphic Preview (Bottom Right)
                    Positioned(
                      bottom: -40,
                      right: -30,
                      child: Container(
                        width: 200,
                        height: 340,
                        decoration: BoxDecoration(
                          color: ink.background,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(AppRadius.xl),
                            topRight: Radius.circular(AppRadius.xl),
                          ),
                          border: Border.all(color: ink.border, width: 6),
                          boxShadow: [
                            BoxShadow(
                              color: tokens.shadow.withValues(alpha: 0.25),
                              blurRadius: 28,
                              offset: const Offset(-8, 16),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: Space.x3),
                            // Notch / Speaker
                            Container(
                              width: 60,
                              height: 6,
                              decoration: BoxDecoration(
                                color: ink.border,
                                borderRadius: AppRadius.all(AppRadius.xs),
                              ),
                            ),
                            const Spacer(),
                            const FrostMark(size: 48),
                            const SizedBox(height: Space.x2),
                            Text(
                              'FrostBank',
                              style: AppType.labelMedium.copyWith(
                                color: ink.textSecondary,
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom CTA Button
            Padding(
              padding: const EdgeInsets.all(Space.x6),
              child: Pressable(
                onTap: onDismiss,
                borderRadius: AppRadius.pill,
                child: Container(
                  width: double.infinity,
                  height: Layout.minTapTarget + Space.x2,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.all(AppRadius.pill),
                    gradient: LinearGradient(
                      colors: [tokens.interactivePrimary, tokens.accent],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: tokens.accent.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Get Started',
                        style: AppType.titleMedium.copyWith(
                          color: tokens.textOnBrand,
                        ),
                      ),
                      const SizedBox(width: Space.x2),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: tokens.textOnBrand,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Dark Mode Advertisement layout ("Pay Your Way, Anytime")
class _DarkAdLayout extends StatelessWidget {
  const _DarkAdLayout({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Stack(
      children: [
        // Ambient Dark Background with gradient glow
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.background,
              gradient: RadialGradient(
                center: const Alignment(0.4, -0.2),
                radius: 1.2,
                colors: [
                  tokens.surfaceRaised,
                  tokens.backgroundAlt,
                  tokens.background,
                ],
              ),
            ),
          ),
        ),

        // Content
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.x6,
                vertical: Space.x4,
              ),
              child: Row(
                children: [
                  // Skip button on top left
                  Pressable(
                    onTap: onDismiss,
                    semanticLabel: 'Skip advertisement',
                    borderRadius: AppRadius.pill,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.x4,
                        vertical: Space.x2,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.surfaceRaised,
                        borderRadius: AppRadius.all(AppRadius.pill),
                        border: Border.all(color: tokens.border),
                      ),
                      child: Text(
                        'Skip',
                        style: AppType.labelLarge.copyWith(
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'FrostBank',
                    style: AppType.titleLarge.copyWith(
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(width: Space.x2),
                  const FrostMark(size: 32),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: Space.x3),
                    // Headline & Content Showcase
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.x6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pay Your Way,\nAnytime',
                            style: AppType.displayLarge.copyWith(
                              color: tokens.info,
                            ),
                          ),

                          const SizedBox(height: Space.x3),

                          Text(
                            'Send, receive, and manage\nmoney effortlessly',
                            style: AppType.bodyLarge.copyWith(
                              color: tokens.textSecondary,
                            ),
                          ),

                          const SizedBox(height: Space.x5),

                          // Primary CTA Button
                          Pressable(
                            onTap: onDismiss,
                            borderRadius: AppRadius.sm,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Space.x8,
                                vertical: Space.x4,
                              ),
                              decoration: BoxDecoration(
                                color: tokens.interactivePrimary,
                                borderRadius: AppRadius.all(AppRadius.sm),
                                boxShadow: [
                                  BoxShadow(
                                    color: tokens.interactivePrimary.withValues(
                                      alpha: 0.4,
                                    ),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Text(
                                'Get Started Now',
                                style: AppType.titleMedium.copyWith(
                                  color: tokens.textOnBrand,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: Space.x8),

                    // Visual Center Illustration & Coin Doodles
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          // Floating Coins Illustration Overlay
                          Positioned(
                            top: -45,
                            left: 15,
                            child: Column(
                              children: [
                                Icon(
                                  Icons.monetization_on_outlined,
                                  size: 32,
                                  color: tokens.info.withValues(alpha: 0.9),
                                ),
                                const SizedBox(height: Space.x1),
                                Icon(
                                  Icons.currency_exchange_rounded,
                                  size: 24,
                                  color: tokens.interactiveActive.withValues(
                                    alpha: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Night User Graphic Container
                          Container(
                            width: 240,
                            height: 180,
                            decoration: BoxDecoration(
                              borderRadius: AppRadius.all(AppRadius.lg),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  tokens.surface.withValues(alpha: 0.8),
                                  tokens.backgroundAlt,
                                ],
                              ),
                              border: Border.all(color: tokens.border),
                              boxShadow: [
                                BoxShadow(
                                  color: tokens.shadow.withValues(alpha: 0.4),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.smartphone_rounded,
                                  size: 60,
                                  color: tokens.interactiveActive.withValues(
                                    alpha: 0.9,
                                  ),
                                ),
                                const SizedBox(height: Space.x2),
                                Text(
                                  'Instant & Secure',
                                  style: AppType.titleMedium.copyWith(
                                    color: tokens.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.x6),
                  ],
                ),
              ),
            ),

            // Bottom Trust Badges
            DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.background.withValues(alpha: 0.3),
                border: Border(top: BorderSide(color: tokens.border)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.x4,
                  vertical: Space.x4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const FrostMark(size: 18),
                            const SizedBox(width: Space.x1),
                            Text(
                              'Instant Transfers',
                              style: AppType.labelMedium.copyWith(
                                color: tokens.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: Space.x2),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const FrostMark(size: 18),
                            const SizedBox(width: Space.x1),
                            Text(
                              '100% Secure Payments',
                              style: AppType.labelMedium.copyWith(
                                color: tokens.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
