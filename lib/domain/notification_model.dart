/// Notifications domain. Plain immutable value types, one repository contract,
/// and the seeded content, with no data source and no Flutter knowledge.
///
/// Every figure, name, and identifier below is mock data, per requirement 6.9.
library;

// ---------------------------------------------------------------------------
// Enumerations
// ---------------------------------------------------------------------------

/// The five streams a notification can belong to.
///
/// [label] lives here rather than in the presentation layer because it is the
/// domain's own name for the stream, not a piece of styling.
enum NotificationCategory {
  payment,
  security,
  savings,
  card,
  offer;

  String get label => switch (this) {
    NotificationCategory.payment => 'Payment',
    NotificationCategory.security => 'Security',
    NotificationCategory.savings => 'Savings',
    NotificationCategory.card => 'Card',
    NotificationCategory.offer => 'Offer',
  };
}

// ---------------------------------------------------------------------------
// AppNotification
// ---------------------------------------------------------------------------

/// One entry in the notification feed.
///
/// [body] is held to at most 20 words by requirement 22.1. That cap is a content
/// rule rather than a runtime one, so it is asserted on seeded content by the
/// test suite instead of being enforced with a throw at construction.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.at,
    this.read = false,
    this.linkTarget,
  });

  final String id;
  final String title;
  final String body;
  final NotificationCategory category;

  /// When the event happened. Rendered as a relative stamp.
  final DateTime at;

  final bool read;

  /// Route this notification points at, for example `/txn/txn_003`. Null when
  /// the notification is informational and leads nowhere.
  final String? linkTarget;

  bool get hasLink => linkTarget != null && linkTarget!.isNotEmpty;

  /// Word count of [body], used to hold the 20 word cap of requirement 22.1.
  int get bodyWordCount =>
      body.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    NotificationCategory? category,
    DateTime? at,
    bool? read,
    String? linkTarget,
  }) => AppNotification(
    id: id ?? this.id,
    title: title ?? this.title,
    body: body ?? this.body,
    category: category ?? this.category,
    at: at ?? this.at,
    read: read ?? this.read,
    linkTarget: linkTarget ?? this.linkTarget,
  );
}

// ---------------------------------------------------------------------------
// Repository contract (requirement 6.1)
// ---------------------------------------------------------------------------

/// The one contract for the notifications domain. Presentation code depends on
/// this and on [AppNotification], never on a data source.
abstract interface class NotificationRepository {
  /// Newest first.
  Future<List<AppNotification>> fetchNotifications();

  /// Marks one notification as read. An already read identifier is a no op, and
  /// an unknown identifier is ignored rather than raised.
  Future<void> markRead(String id);

  /// Marks every notification as read.
  Future<void> markAllRead();
}

// ---------------------------------------------------------------------------
// Seed
// ---------------------------------------------------------------------------

/// Seeded notification feed for the offline build.
///
/// Mock data. The merchants, venues, and utilities named here are real
/// businesses referenced for plausibility, per requirement 24.2, and no figure
/// or identifier belongs to a real account.
abstract final class NotificationSeed {
  /// Takes [now] so relative ages are deterministic under test, mirroring
  /// `MockSeed.transactions({now})`.
  static List<AppNotification> notifications({DateTime? now}) {
    final reference = now ?? DateTime.now();

    return [
      // Mock data: a ride fare that cleared minutes ago.
      AppNotification(
        id: 'ntf_001',
        title: 'Payment sent to Grab',
        body:
            'Your ride fare to Grab Philippines cleared. The receipt now sits '
            'in your activity feed.',
        category: NotificationCategory.payment,
        at: reference.subtract(const Duration(minutes: 6)),
        linkTarget: '/txn/txn_003',
      ),

      // Mock data: a sign in from a second device.
      AppNotification(
        id: 'ntf_002',
        title: 'New sign in on Chrome',
        body:
            'A new device signed in from Makati. Review the session if this '
            'was not you.',
        category: NotificationCategory.security,
        at: reference.subtract(const Duration(minutes: 42)),
      ),

      // Mock data: daily interest credited to a goal save.
      AppNotification(
        id: 'ntf_003',
        title: 'Europe Trip goal grew',
        body:
            'Daily interest landed in your Europe Trip pocket. The balance is '
            'climbing steadily this month.',
        category: NotificationCategory.savings,
        at: reference.subtract(const Duration(hours: 5)),
        linkTarget: '/savings/goal_europe',
      ),

      // Mock data: a card the holder froze yesterday.
      AppNotification(
        id: 'ntf_004',
        title: 'Card ending 4821 frozen',
        body:
            'You froze your FrostBank Meridian card. Unfreeze it any time from '
            'the cards deck.',
        category: NotificationCategory.card,
        at: reference.subtract(const Duration(days: 1, hours: 2)),
        read: true,
        linkTarget: '/card/card_visa',
      ),

      // Mock data: a merchant funded cashback offer.
      AppNotification(
        id: 'ntf_005',
        title: 'Cashback at Jollibee',
        body:
            'Spend with your FrostBank card at Jollibee this week and earn '
            'five percent back.',
        category: NotificationCategory.offer,
        at: reference.subtract(const Duration(days: 2, hours: 7)),
        read: true,
      ),

      // Mock data: a scheduled utility bill that settled on time.
      AppNotification(
        id: 'ntf_006',
        title: 'Meralco bill paid',
        body:
            'Your scheduled Meralco electricity bill went out on time. Nothing '
            'further is needed.',
        category: NotificationCategory.payment,
        at: reference.subtract(const Duration(days: 4, hours: 3)),
        read: true,
      ),

      // Mock data: an inbound salary credit from a named employer.
      AppNotification(
        id: 'ntf_007',
        title: 'Salary from Globe Telecom',
        body:
            'Your Globe Telecom salary credit landed in your everyday wallet '
            'this morning.',
        category: NotificationCategory.payment,
        at: reference.subtract(const Duration(hours: 19)),
        read: true,
      ),
    ];
  }
}
