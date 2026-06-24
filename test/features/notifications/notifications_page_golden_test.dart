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

void main() {
  testWidgets('NotificationsPage – default feed', (tester) async {
    await pumpForGolden(tester, const NotificationsPage(), size: _phone);

    await expectLater(find.byType(NotificationsPage), matchesGoldenFile('goldens/notifications_default.png'));
  });

  testWidgets('NotificationsPage – all read', (tester) async {
    await pumpForGolden(tester, NotificationsPage(sections: _allRead(sampleNotifications)), size: _phone);

    await expectLater(find.byType(NotificationsPage), matchesGoldenFile('goldens/notifications_all_read.png'));
  });
}
