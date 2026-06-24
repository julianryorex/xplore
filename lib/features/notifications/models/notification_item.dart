import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';

/// The kind of event a notification represents. Each kind carries its own
/// icon + accent so the list reads at a glance — the accent is what the
/// "deep glass" variant refracts through its nested chips.
enum NotificationKind {
  tripInvite,
  itinerary,
  gallery,
  location,
  system;

  IconData get icon => switch (this) {
    NotificationKind.tripInvite => Icons.group_add_rounded,
    NotificationKind.itinerary => Icons.event_note_rounded,
    NotificationKind.gallery => Icons.photo_library_rounded,
    NotificationKind.location => Icons.location_on_rounded,
    NotificationKind.system => Icons.auto_awesome_rounded,
  };

  /// Accent used for the icon chip / rim. Kept inside the brand palette so the
  /// screen never drifts from the design system.
  Color get accent => switch (this) {
    NotificationKind.tripInvite => XploreColors.alternate,
    NotificationKind.itinerary => XploreColors.info,
    NotificationKind.gallery => XploreColors.secondaryText,
    NotificationKind.location => XploreColors.warning,
    NotificationKind.system => XploreColors.alternate,
  };
}

/// A single, immutable notification row. Deliberately plain (no Freezed/codegen)
/// so the exploration screens compile without a build_runner pass.
@immutable
class NotificationItem {
  final String id;
  final NotificationKind kind;
  final String title;
  final String body;

  /// Human-friendly relative time, e.g. "2m", "1h", "Yesterday".
  final String timeLabel;
  final bool isRead;

  /// Optional avatar initials shown instead of the kind icon (people events).
  final String? avatarInitials;

  const NotificationItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.timeLabel,
    this.isRead = false,
    this.avatarInitials,
  });

  NotificationItem copyWith({bool? isRead}) {
    return NotificationItem(
      id: id,
      kind: kind,
      title: title,
      body: body,
      timeLabel: timeLabel,
      isRead: isRead ?? this.isRead,
      avatarInitials: avatarInitials,
    );
  }
}

/// A dated bucket of notifications ("Today", "Earlier this week", …).
@immutable
class NotificationSection {
  final String label;
  final List<NotificationItem> items;

  const NotificationSection({required this.label, required this.items});

  int get unreadCount => items.where((item) => !item.isRead).length;

  NotificationSection copyWith({List<NotificationItem>? items}) {
    return NotificationSection(label: label, items: items ?? this.items);
  }
}

/// Total unread across every section.
int unreadCountFor(List<NotificationSection> sections) => sections.fold(0, (sum, section) => sum + section.unreadCount);

/// Static sample feed used by every variant + the goldens. Replace with a real
/// `NotificationCubit` stream when the backend lands.
const List<NotificationSection> sampleNotifications = [
  NotificationSection(
    label: 'Today',
    items: [
      NotificationItem(
        id: 'n1',
        kind: NotificationKind.tripInvite,
        title: 'Mara invited you to Lisbon \u201826',
        body: 'Tap to join the trip and start planning together.',
        timeLabel: '2m',
        avatarInitials: 'M',
      ),
      NotificationItem(
        id: 'n2',
        kind: NotificationKind.itinerary,
        title: 'Day 3 itinerary updated',
        body: 'Jonas added "Sunset at Miradouro da Senhora do Monte".',
        timeLabel: '40m',
      ),
      NotificationItem(
        id: 'n3',
        kind: NotificationKind.gallery,
        title: '12 new photos in Shared gallery',
        body: 'Lena and 2 others added shots from the old town.',
        timeLabel: '1h',
        isRead: true,
      ),
    ],
  ),
  NotificationSection(
    label: 'Earlier this week',
    items: [
      NotificationItem(
        id: 'n4',
        kind: NotificationKind.location,
        title: 'You arrived at Time Out Market',
        body: 'Drop a pin or share your check-in with the group.',
        timeLabel: 'Tue',
        isRead: true,
      ),
      NotificationItem(
        id: 'n5',
        kind: NotificationKind.system,
        title: 'Your trip recap is ready',
        body: 'A little highlight reel from week one is waiting for you.',
        timeLabel: 'Mon',
        isRead: true,
      ),
    ],
  ),
];
