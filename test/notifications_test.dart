import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_bank_app/core/design/theme.dart';
import 'package:mobile_bank_app/core/design/tokens.dart';
import 'package:mobile_bank_app/data/mock_notification_repository.dart';
import 'package:mobile_bank_app/domain/notification_model.dart';
import 'package:mobile_bank_app/presentation/screens/notifications_screen.dart';
import 'package:mobile_bank_app/presentation/widgets/states.dart';
import 'package:mobile_bank_app/state/providers.dart';

/// Seeded against the wall clock so the relative stamps of requirement 22.1 land
/// on the same wording they would in the running application.
MockNotificationRepository _repository({
  List<AppNotification>? seed,
  Duration latency = Duration.zero,
  bool failing = false,
}) {
  final repository = MockNotificationRepository(
    now: DateTime.now(),
    seed: seed,
  )..latencyOverride = (() => latency);
  if (failing) repository.errorSimulation.add('notifications');
  return repository;
}

Widget _harness(MockNotificationRepository repository, {Widget? screen}) =>
    ProviderScope(
      retry: noAutomaticRetry,
      overrides: [
        notificationRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: screen ?? const NotificationsScreen(),
      ),
    );

Color _tintOf(WidgetTester tester, String id) {
  final surface = tester.widget<Container>(
    find.byKey(NotificationTile.surfaceKey(id)),
  );
  return (surface.decoration! as BoxDecoration).color!;
}

/// Two rows, one linked and one not, for the criteria that do not need the whole
/// seeded feed.
List<AppNotification> _pair(DateTime now) => [
  AppNotification(
    id: 'ntf_a',
    title: 'Payment sent to Grab',
    body: 'Your ride fare to Grab Philippines cleared this afternoon.',
    category: NotificationCategory.payment,
    at: now.subtract(const Duration(hours: 3)),
    linkTarget: '/txn/txn_003',
  ),
  AppNotification(
    id: 'ntf_b',
    title: 'Cashback at Jollibee',
    body: 'Earn five percent back at Jollibee this week.',
    category: NotificationCategory.offer,
    at: now.subtract(const Duration(days: 2)),
    read: true,
  ),
];

void main() {
  group('Requirement 22, Notifications_Screen', () {
    testWidgets(
      '22.1 renders the title, the body, the relative stamp, and the category '
      'of every notification',
      (tester) async {
        await tester.pumpWidget(_harness(_repository()));
        await tester.pumpAndSettle();

        // Title.
        expect(find.text('Europe Trip goal grew'), findsOneWidget);
        // Body, held under the 20 word cap of requirement 22.1.
        expect(
          find.text(
            'Daily interest landed in your Europe Trip pocket. The balance is '
            'climbing steadily this month.',
          ),
          findsOneWidget,
        );
        // Relative stamp, formatted by the shared Dates helper.
        expect(find.text('5 hours ago'), findsOneWidget);
        expect(find.text('2 days ago'), findsOneWidget);
        // Category, one savings row in the seeded feed.
        expect(find.text('Savings'), findsOneWidget);
        expect(find.text('Security'), findsOneWidget);
        // Three payment rows are seeded.
        expect(find.text('Payment'), findsNWidgets(3));
      },
    );

    test('22.1 every seeded body stays within twenty words', () {
      for (final row in NotificationSeed.notifications(now: DateTime.now())) {
        expect(
          row.bodyWordCount,
          lessThanOrEqualTo(20),
          reason: '${row.id} carries ${row.bodyWordCount} words',
        );
      }
    });

    testWidgets(
      '22.2 renders unread rows with a stronger surface tint than read rows',
      (tester) async {
        await tester.pumpWidget(_harness(_repository()));
        await tester.pumpAndSettle();

        final unreadTint = _tintOf(tester, 'ntf_001');
        final readTint = _tintOf(tester, 'ntf_005');

        expect(unreadTint, isNot(readTint));
        expect(unreadTint, AppTokens.light.interactiveSecondary);
        expect(readTint, AppTokens.light.surface);
      },
    );

    testWidgets(
      '22.3 opening a notification marks it read and drops the unread count',
      (tester) async {
        final repository = _repository();
        await tester.pumpWidget(_harness(repository));
        await tester.pumpAndSettle();

        expect(find.text('3 unread'), findsOneWidget);
        expect(repository.unreadCount, 3);
        expect(_tintOf(tester, 'ntf_001'), AppTokens.light.interactiveSecondary);

        await tester.tap(find.text('Payment sent to Grab'));
        await tester.pumpAndSettle();

        expect(repository.unreadCount, 2);
        expect(find.text('2 unread'), findsOneWidget);
        expect(find.text('3 unread'), findsNothing);
        expect(_tintOf(tester, 'ntf_001'), AppTokens.light.surface);
      },
    );

    testWidgets(
      '22.4 activating the mark all as read control marks every notification '
      'as read',
      (tester) async {
        final repository = _repository();
        await tester.pumpWidget(_harness(repository));
        await tester.pumpAndSettle();

        expect(repository.unreadCount, 3);

        await tester.tap(find.byTooltip('Mark all read'));
        await tester.pumpAndSettle();

        expect(repository.unreadCount, 0);
        expect(find.text('No unread alerts'), findsOneWidget);
        expect(find.text('3 unread'), findsNothing);

        // Every seeded row now carries the read tint, so the write reached all
        // of them and not only the one that was tapped.
        for (final row in NotificationSeed.notifications(now: DateTime.now())) {
          expect(_tintOf(tester, row.id), AppTokens.light.surface);
        }
      },
    );

    testWidgets(
      '22.5 a notification carrying a linked target renders a control that '
      'navigates to that target',
      (tester) async {
        final targets = <String>[];
        final repository = _repository(seed: _pair(DateTime.now()));

        await tester.pumpWidget(
          _harness(
            repository,
            screen: NotificationsScreen(onOpenTarget: targets.add),
          ),
        );
        await tester.pumpAndSettle();

        // Only the linked row carries the control.
        expect(find.text('View details'), findsOneWidget);
        expect(
          find.bySemanticsLabel('Open Payment sent to Grab'),
          findsOneWidget,
        );

        await tester.tap(find.text('View details'));
        await tester.pumpAndSettle();

        expect(targets, ['/txn/txn_003']);
      },
    );

    testWidgets('22.6 zero notifications renders the Empty_State', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(_repository(seed: const <AppNotification>[])),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EmptyStateView), findsOneWidget);
      expect(find.text('You are all caught up'), findsOneWidget);
      expect(
        find.text(
          'Alerts about payments, cards, and savings will land here as they '
          'happen.',
        ),
        findsOneWidget,
      );
      expect(find.text('Refresh'), findsOneWidget);
      expect(find.byType(NotificationTile), findsNothing);
    });
  });

  group('Requirement 3, Async_Surface', () {
    testWidgets(
      '3.1 renders a shape matched skeleton while the feed is loading',
      (tester) async {
        await tester.pumpWidget(
          _harness(_repository(latency: const Duration(milliseconds: 400))),
        );
        await tester.pump();

        expect(find.byType(SkeletonBlock), findsWidgets);
        expect(find.byType(NotificationTile), findsNothing);

        await tester.pumpAndSettle();

        expect(find.byType(SkeletonBlock), findsNothing);
        expect(find.byType(NotificationTile), findsNWidgets(7));
      },
    );

    testWidgets(
      '3.4 renders an inline error with a retry control that reloads the feed',
      (tester) async {
        final repository = _repository(failing: true);
        await tester.pumpWidget(_harness(repository));
        await tester.pumpAndSettle();

        expect(find.byType(ErrorStateView), findsOneWidget);
        expect(
          find.text('We could not load your notifications right now.'),
          findsOneWidget,
        );
        expect(find.text('Try again'), findsOneWidget);

        repository.errorSimulation.clear();
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();

        expect(find.byType(ErrorStateView), findsNothing);
        expect(find.byType(NotificationTile), findsNWidgets(7));
      },
    );
  });

  group('Requirements 6 and 12, repository contract', () {
    test(
      '12.16 the unread count is readable for the Dashboard_Screen badge',
      () async {
        final container = ProviderContainer(
          overrides: [
            notificationRepositoryProvider.overrideWithValue(_repository()),
          ],
        );
        addTearDown(container.dispose);

        await container.read(notificationsProvider.future);

        expect(container.read(unreadNotificationCountProvider), 3);

        await container.read(notificationRepositoryProvider).markAllRead();
        container.invalidate(notificationsProvider);
        await container.read(notificationsProvider.future);

        expect(container.read(unreadNotificationCountProvider), 0);
      },
    );

    test('6.5 a read resolves after a delay of at least 300ms', () async {
      final repository = MockNotificationRepository(now: DateTime.now());
      final watch = Stopwatch()..start();
      await repository.fetchNotifications();
      watch.stop();

      expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(295));
      expect(watch.elapsedMilliseconds, lessThan(2000));
    });

    test('6.1 the mock repository honours the single domain contract', () {
      expect(_repository(), isA<NotificationRepository>());
    });
  });
}
