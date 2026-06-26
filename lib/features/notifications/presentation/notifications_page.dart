import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/core/ambient_background.dart';
import 'package:xplore/core/glass.dart';
import 'package:xplore/core/header.dart';
import 'package:xplore/features/notifications/models/notification_item.dart';
import 'package:xplore/features/notifications/presentation/variants/refined_list_view.dart';

/// The notification screen: a pinned liquid-glass header over a scrolling feed
/// of dated, glass notification rows.
///
/// Read state is held locally for now (tap a row, or "mark all read") so the UI
/// feels live; swap [sections] for a `NotificationCubit` stream when the backend
/// (FEAT-012) lands — the widget tree won't need to change.
///
/// [sections] defaults to an empty list so the runtime app shows the polished
/// "all caught up" empty state until that backend exists. Tests pass
/// `sampleNotifications` explicitly to exercise the populated feed.
class NotificationsPage extends StatefulWidget {
  final List<NotificationSection> sections;

  const NotificationsPage({this.sections = const [], super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late List<NotificationSection> _sections = widget.sections;

  void _markRead(NotificationItem target) {
    if (target.isRead) return;
    HapticFeedback.selectionClick();
    setState(() {
      _sections = [
        for (final section in _sections)
          section.copyWith(
            items: [for (final item in section.items) item.id == target.id ? item.copyWith(isRead: true) : item],
          ),
      ];
    });
  }

  void _markAllRead() {
    HapticFeedback.lightImpact();
    setState(() {
      _sections = [
        for (final section in _sections)
          section.copyWith(items: [for (final item in section.items) item.copyWith(isRead: true)]),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final topInset = viewPadding.top;
    const headerTopGap = paddingUnit * 0.75;
    final headerZone = topInset + headerTopGap + Header.padding;
    final listTop = headerZone + paddingUnit;
    final bottomClearance = viewPadding.bottom + paddingUnit * 2;

    final hasUnread = unreadCountFor(_sections) > 0;
    final isEmpty = _sections.every((section) => section.items.isEmpty);

    return Scaffold(
      backgroundColor: XploreColors.primaryBg,
      body: AmbientBackground(
        child: Stack(
          children: [
            // Full-height scroll content so the pinned glass header has
            // something to refract as the feed moves beneath it.
            Positioned.fill(
              child: isEmpty
                  ? _EmptyState(topInset: listTop)
                  : RefinedNotificationList(
                      sections: _sections,
                      onTap: _markRead,
                      padding: EdgeInsets.only(
                        left: paddingUnit * 1.5,
                        right: paddingUnit * 1.5,
                        top: listTop,
                        bottom: bottomClearance,
                      ),
                    ),
            ),
            // Top scrim keeps content legible as it scrolls under the header.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  height: headerZone + paddingUnit * 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        XploreColors.primaryBg,
                        XploreColors.primaryBg,
                        XploreColors.primaryBg.withValues(alpha: 0),
                      ],
                      stops: const [0, 0.6, 1],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: topInset + headerTopGap,
              left: 0,
              right: 0,
              child: Header(
                leadingWidget: GlassIconButton(
                  size: 44,
                  iconSize: 20,
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.maybePop(context),
                ),
                titleWidget: Text('Notifications', style: context.pText.headlineSmall?.copyWith(letterSpacing: -0.3)),
                trailingWidget: GlassIconButton(
                  size: 44,
                  iconSize: 20,
                  icon: Icons.done_all_rounded,
                  tooltip: 'Mark all as read',
                  iconColor: hasUnread ? XploreColors.white : XploreColors.subtleText,
                  onTap: hasUnread ? _markAllRead : () {},
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final double topInset;

  const _EmptyState({required this.topInset});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topInset, left: paddingUnit * 1.5, right: paddingUnit * 1.5),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlassSurface(
              borderRadius: radiusLg,
              strong: true,
              padding: const EdgeInsets.all(paddingUnit * 1.25),
              child: Icon(Icons.notifications_none_rounded, size: 32, color: XploreColors.white.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: paddingUnit),
            Text('You\u2019re all caught up', style: context.pText.labelLarge),
            const SizedBox(height: 4),
            Text(
              'New trip activity will show up here.',
              style: context.pText.bodySmall?.copyWith(color: XploreColors.mutedText),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
