import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/format/dates.dart';
import '../../domain/notification_model.dart';
import '../../state/providers.dart';
import '../widgets/brand.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/pressable.dart';
import '../widgets/states.dart';
import '../widgets/surfaces.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// The notification feed.
///
/// Async_Surface, so the list carries a shape matched skeleton, an empty state
/// with a heading, one sentence, and one action, and an inline failure with a
/// retry control, all through [AsyncSection].
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({this.onOpenTarget, super.key});

  /// Escape hatch for tests and for hosts without a router in scope. When null,
  /// a linked notification hands its target to [GoRouter].
  final void Function(String target)? onOpenTarget;

  Future<void> _markRead(WidgetRef ref, AppNotification row) async {
    if (row.read) return;
    await ref.read(notificationRepositoryProvider).markRead(row.id);
    ref.invalidate(notificationsProvider);
  }

  Future<void> _markAllRead(WidgetRef ref) async {
    await ref.read(notificationRepositoryProvider).markAllRead();
    ref.invalidate(notificationsProvider);
  }

  void _navigate(BuildContext context, String target) {
    final handler = onOpenTarget;
    if (handler != null) {
      handler(target);
      return;
    }
    GoRouter.of(context).go(target);
  }

  Future<void> _openLink(
    BuildContext context,
    WidgetRef ref,
    AppNotification row,
  ) async {
    // Following the link is also opening the notification, so the read mark is
    // applied here as well rather than only on the row tap.
    await _markRead(ref, row);
    if (!context.mounted) return;
    _navigate(context, row.linkTarget!);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadNotificationCountProvider);
    final rows = feed.hasValue ? feed.requireValue : null;

    // The shared header, so this screen stops being the one with no gradient at
    // all. Requirement 4.7's heading announcement comes from BrandScreenScaffold,
    // which wraps its title in Semantics(header: true).
    return BrandScreenScaffold(
      title: 'Notifications',
      subtitle: unread == 0
          ? 'You are up to date on payments, cards and savings.'
          : 'You have $unread alert${unread == 1 ? '' : 's'} to catch up on.',
      actions: [
        // Requirement 25.6 caps a label at three words, so this stays an icon
        // control carrying its own name rather than a wide button.
        GlassIconButton(
          icon: Icons.done_all_rounded,
          label: 'Mark all read',
          onTap: unread == 0 ? () {} : () => _markAllRead(ref),
        ),
      ],
      children: [
        if (rows != null && rows.isNotEmpty) ...[
          _UnreadSummary(count: unread),
          const SizedBox(height: Space.x4),
        ],
        AsyncSection<List<AppNotification>>(
              value: feed,
              onRetry: () => ref.invalidate(notificationsProvider),
              skeleton: const _NotificationSkeleton(),
              isEmpty: (data) => data.isEmpty,
              empty: EmptyStateView(
                icon: Icons.notifications_none_rounded,
                heading: 'You are all caught up',
                message:
                    'Alerts about payments, cards, and savings will land here '
                    'as they happen.',
                actionLabel: 'Refresh',
                onAction: () => ref.invalidate(notificationsProvider),
              ),
              builder: (data) => Column(
                children: [
                  for (final row in data)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.x3),
                      child: NotificationTile(
                        notification: row,
                        onOpen: () => _markRead(ref, row),
                        onOpenLink: row.hasLink
                            ? () => _openLink(context, ref, row)
                            : null,
                      ),
                    ),
                ],
              ),
            ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Unread summary
// ---------------------------------------------------------------------------

class _UnreadSummary extends StatelessWidget {
  const _UnreadSummary({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final label = count == 0 ? 'No unread alerts' : '$count unread';
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          Text(
            label,
            style: AppType.labelMedium.copyWith(
              color: count == 0 ? tokens.textSecondary : tokens.accent,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Row
// ---------------------------------------------------------------------------

/// One feed row.
///
/// Requirement 22.2: an unread row carries the accent tinted surface while a read
/// row carries the plain one, so the two read as different weights of the same
/// surface rather than as two different components.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    required this.notification,
    required this.onOpen,
    this.onOpenLink,
    super.key,
  });

  final AppNotification notification;
  final VoidCallback onOpen;
  final VoidCallback? onOpenLink;

  /// Key on the tinted surface of the row for [id], so a test can read the tint
  /// that requirement 22.2 asks for.
  static ValueKey<String> surfaceKey(String id) =>
      ValueKey<String>('notification_surface_$id');

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final row = notification;
    final stamp = Dates.relative(row.at);
    final unread = !row.read;

    return Container(
      key: surfaceKey(row.id),
      decoration: BoxDecoration(
        color: unread ? tokens.interactiveSecondary : tokens.surface,
        borderRadius: AppRadius.all(AppRadius.lg),
        border: Border.all(
          color: unread
              ? tokens.accent.withValues(alpha: 0.42)
              : tokens.border.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Pressable(
            onTap: onOpen,
            borderRadius: AppRadius.lg,
            // Requirement 4.1: the whole row reads as one labelled control.
            semanticLabel:
                '${row.title}. ${row.category.label}. $stamp. '
                '${unread ? 'Unread' : 'Read'}. ${row.body}',
            child: Padding(
              padding: const EdgeInsets.all(Space.x4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CategoryGlyph(category: row.category),
                  const SizedBox(width: Space.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                row.title,
                                style: AppType.titleSmall.copyWith(
                                  color: tokens.textPrimary,
                                ),
                              ),
                            ),
                            if (unread) ...[
                              const SizedBox(width: Space.x2),
                              Container(
                                width: Space.x2,
                                height: Space.x2,
                                margin: const EdgeInsets.only(top: Space.x1),
                                decoration: BoxDecoration(
                                  color: tokens.accent,
                                  borderRadius: AppRadius.all(AppRadius.pill),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: Space.x1),
                        Text(
                          row.body,
                          style: AppType.bodySmall.copyWith(
                            color: tokens.textSecondary,
                          ),
                        ),
                        const SizedBox(height: Space.x3),
                        Row(
                          children: [
                            StatusPill(
                              label: row.category.label,
                              color: _categoryColor(tokens, row.category),
                            ),
                            const SizedBox(width: Space.x3),
                            Expanded(
                              child: Text(
                                stamp,
                                style: AppType.labelSmall.copyWith(
                                  color: tokens.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Requirement 22.5: a linked notification carries its own control to
          // the target. It sits outside the row Pressable so it keeps its own
          // semantics and its own 48 logical pixel target.
          if (onOpenLink != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.x3,
                0,
                Space.x4,
                Space.x2,
              ),
              child: Semantics(
                button: true,
                label: 'Open ${row.title}',
                excludeSemantics: true,
                child: TextButton.icon(
                  onPressed: onOpenLink,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('View details'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(
                      Layout.minTapTarget,
                      Layout.minTapTarget,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static Color _categoryColor(AppTokens tokens, NotificationCategory category) =>
      switch (category) {
        NotificationCategory.payment => tokens.info,
        NotificationCategory.security => tokens.warning,
        NotificationCategory.savings => tokens.success,
        NotificationCategory.card => tokens.accent,
        NotificationCategory.offer => tokens.interactivePrimary,
      };
}

class _CategoryGlyph extends StatelessWidget {
  const _CategoryGlyph({required this.category});

  final NotificationCategory category;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = NotificationTile._categoryColor(tokens, category);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: AppRadius.all(AppRadius.pill),
      ),
      // The category is already spoken by the row label and shown by the pill,
      // so the glyph is decorative.
      child: ExcludeSemantics(child: Icon(_icon, color: color, size: 20)),
    );
  }

  IconData get _icon => switch (category) {
    NotificationCategory.payment => Icons.swap_horiz_rounded,
    NotificationCategory.security => Icons.shield_outlined,
    NotificationCategory.savings => Icons.savings_rounded,
    NotificationCategory.card => Icons.credit_card_rounded,
    NotificationCategory.offer => Icons.local_offer_rounded,
  };
}

// ---------------------------------------------------------------------------
// Skeleton
// ---------------------------------------------------------------------------

/// Shape matched placeholder: the glyph, the title, the body, and the meta line
/// of [NotificationTile] in the same positions.
class _NotificationSkeleton extends StatelessWidget {
  const _NotificationSkeleton();

  /// Four rows, which fills the first viewport without implying a length the
  /// feed may not have.
  static const int count = 4;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var index = 0; index < count; index++)
        Padding(
          padding: const EdgeInsets.only(bottom: Space.x3),
          child: Padding(
            padding: const EdgeInsets.all(Space.x4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBlock(width: 44, height: 44, radius: AppRadius.pill),
                SizedBox(width: Space.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBlock(width: 170, height: 14),
                      SizedBox(height: Space.x2),
                      SkeletonBlock(width: 220, height: 11),
                      SizedBox(height: Space.x3),
                      SkeletonBlock(width: 96, height: 11),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}
