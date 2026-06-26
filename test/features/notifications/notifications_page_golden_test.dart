// Goldens for the notification screen (the "Refined" Liquid Glass design).
//
// APPLE-ONLY: refresh with `make test-gold` on macOS.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/notifications/models/notification_item.dart';
import 'package:xplore/features/notifications/presentation/notifications_page.dart';

import '../../helpers/pump_app.dart';

const _phone = Size(390, 844);

List<NotificationSection> _allRead(List<NotificationSection> sections) => [
  for (final section in sections)
    section.copyWith(items: [for (final item in section.items) item.copyWith(isRead: true)]),
];

/// A hand-built feed standing in for what the future `NotificationCubit` stream
/// (FEAT-012) will hand the page — deliberately *not* [sampleNotifications] so
/// the populated render is also covered against backend-shaped, all-unread data
/// (the most common "fresh batch" a push delivers). Exercises every
/// [NotificationKind] plus the avatar vs. icon-chip split and the per-section
/// "N new" badge.
const List<NotificationSection> _mockedFeed = [
  NotificationSection(
    label: 'Today',
    items: [
      NotificationItem(
        id: 'm1',
        kind: NotificationKind.tripInvite,
        title: 'Theo invited you to Tokyo \u201927',
        body: 'Join the trip to vote on dates and start a shared itinerary.',
        timeLabel: 'now',
        avatarInitials: 'T',
      ),
      NotificationItem(
        id: 'm2',
        kind: NotificationKind.location,
        title: 'The group is gathering at Shibuya Crossing',
        body: '4 travellers checked in nearby — share your location to meet up.',
        timeLabel: '5m',
      ),
      NotificationItem(
        id: 'm3',
        kind: NotificationKind.itinerary,
        title: 'Priya proposed a teamLab Planets visit',
        body: 'Added to Day 2 — tap to confirm the 10:30 reservation slot.',
        timeLabel: '18m',
        avatarInitials: 'P',
      ),
    ],
  ),
  NotificationSection(
    label: 'Yesterday',
    items: [
      NotificationItem(
        id: 'm4',
        kind: NotificationKind.gallery,
        title: '27 new photos from the night market',
        body: 'Kenji and 3 others added shots to the shared gallery.',
        timeLabel: '1d',
      ),
      NotificationItem(
        id: 'm5',
        kind: NotificationKind.system,
        title: 'Weather alert for your Hakone day trip',
        body: 'Rain is forecast Thursday — consider swapping the outdoor onsen.',
        timeLabel: '1d',
      ),
    ],
  ),
];

void main() {
  testWidgets('NotificationsPage – default feed', (tester) async {
    // The runtime default is now an empty feed, so the populated golden has to
    // pass [sampleNotifications] explicitly.
    await pumpForGolden(tester, const NotificationsPage(sections: sampleNotifications), size: _phone);

    await expectLater(find.byType(NotificationsPage), matchesGoldenFile('goldens/notifications_default.png'));
  });

  testWidgets('NotificationsPage – all read', (tester) async {
    await pumpForGolden(tester, NotificationsPage(sections: _allRead(sampleNotifications)), size: _phone);

    await expectLater(find.byType(NotificationsPage), matchesGoldenFile('goldens/notifications_all_read.png'));
  });

  testWidgets('NotificationsPage – mocked feed', (tester) async {
    // Renders a backend-shaped, all-unread feed (see [_mockedFeed]) so the
    // populated screen is covered with data other than [sampleNotifications].
    await pumpForGolden(tester, const NotificationsPage(sections: _mockedFeed), size: _phone);

    await expectLater(find.byType(NotificationsPage), matchesGoldenFile('goldens/notifications_mocked.png'));
  });

  testWidgets('NotificationsPage – empty by default', (tester) async {
    await pumpForGolden(tester, const NotificationsPage(), size: _phone);

    expect(find.text('You\u2019re all caught up'), findsOneWidget);
    expect(find.text('New trip activity will show up here.'), findsOneWidget);
  });
}
