import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import 'brand.dart';
import 'surfaces.dart';

/// The one way a screen establishes itself.
///
/// Before this existed the application had four header systems at once: the
/// dashboard's brand lockup, the money screens' gradient plus title plus
/// subtitle, and a plain Material `AppBar` on Notifications and Time Deposit,
/// which had no gradient at all. On a contact sheet the six screens read as
/// several products rather than one, and the header was the largest reason.
///
/// Everything below is fixed so it cannot drift again: the gradient depth, the
/// sheet radius, the overlap, the single soft shadow at the seam, and the page
/// inset. A screen chooses its title, an optional subtitle, optional trailing
/// controls and an optional header body, and nothing else.
class BrandScreenScaffold extends StatelessWidget {
  const BrandScreenScaffold({
    required this.title,
    required this.children,
    this.subtitle,
    this.actions = const [],
    this.header,
    this.scrollable = true,
    super.key,
  });

  /// Sentence case, so it matches its siblings.
  final String title;

  /// One short line under the title. Held to the 25 word cap of requirement 25.7.
  final String? subtitle;

  /// Trailing controls in the brand region, in place of an AppBar's actions.
  final List<Widget> actions;

  /// Optional content inside the brand region, typically a balance card.
  final Widget? header;

  final List<Widget> children;

  /// False when the caller supplies its own scrolling, for example a long list
  /// that should not be wrapped in a second scroll view.
  final bool scrollable;

  /// The page inset every screen shares, so the left margin cannot drift between
  /// one screen and the next.
  static const double pageInset = Space.x5;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // No bottom rounding on the gradient. The sheet overlaps it and rounds
        // its own top; rounding both leaves a flare either side of the sheet.
        FrostBackdrop(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                pageInset,
                Space.x2,
                pageInset,
                Space.x10,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _BackControl(),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            title,
                            style: AppType.headlineMedium.copyWith(
                              color: tokens.textOnBrand,
                            ),
                          ),
                        ),
                      ),
                      ...actions,
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: Space.x2),
                    Text(
                      subtitle!,
                      style: AppType.bodySmall.copyWith(
                        color: tokens.textOnBrand.withValues(alpha: 0.76),
                      ),
                    ),
                  ],
                  if (header != null) ...[
                    const SizedBox(height: Space.x5),
                    header!,
                  ],
                ],
              ),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -Space.x6),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: tokens.backgroundAlt,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
              boxShadow: [
                BoxShadow(
                  color: tokens.shadow.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(
              pageInset,
              Space.x6,
              pageInset,
              Space.x10,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: tokens.backgroundAlt,
      // ResponsiveShell sits inside the scroll view, not around it. It centres on
      // both axes, so wrapping a body shorter than the viewport left a band of
      // scaffold colour above the gradient and below the sheet.
      body: scrollable
          ? SingleChildScrollView(child: ResponsiveShell(child: body))
          : ResponsiveShell(child: body),
    );
  }
}

class _BackControl extends StatelessWidget {
  const _BackControl();

  @override
  Widget build(BuildContext context) {
    if (!Navigator.of(context).canPop()) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: Space.x2),
      child: GlassIconButton(
        icon: Icons.arrow_back_rounded,
        label: 'Go back',
        onTap: () => Navigator.of(context).pop(),
      ),
    );
  }
}
