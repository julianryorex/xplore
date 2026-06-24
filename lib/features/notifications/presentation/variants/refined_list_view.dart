import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/core/glass.dart';
import 'package:xplore/features/notifications/models/notification_item.dart';

/// The notification feed: dated groups of liquid-glass rows.
///
/// Each row is a [GlassSurface] (the same primitive used across Home) so the
/// screen stays inside the design system. Read state is driven by the parent —
/// tapping a row reports back via [onTap]; unread rows carry a leading accent
/// rail + dot and slightly stronger type for a clear, restrained hierarchy.
class RefinedNotificationList extends StatelessWidget {
  final List<NotificationSection> sections;
  final EdgeInsets padding;
  final ValueChanged<NotificationItem>? onTap;

  const RefinedNotificationList({required this.sections, this.padding = EdgeInsets.zero, this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding,
      children: [
        for (var s = 0; s < sections.length; s++) ...[
          if (s > 0) const SizedBox(height: paddingUnit * 1.5),
          _GroupHeader(section: sections[s]),
          const SizedBox(height: paddingUnit * 0.75),
          for (final item in sections[s].items) ...[
            _NotificationRow(item: item, onTap: onTap == null ? null : () => onTap!(item)),
            const SizedBox(height: paddingUnit * 0.75),
          ],
        ],
      ],
    );
  }
}

/// A lightweight date caption (e.g. "TODAY") with an unread count, kept smaller
/// than a content `SectionHeader` so grouping reads as metadata, not a heading.
class _GroupHeader extends StatelessWidget {
  final NotificationSection section;

  const _GroupHeader({required this.section});

  @override
  Widget build(BuildContext context) {
    final unread = section.unreadCount;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: paddingUnit * 0.5),
      child: Row(
        children: [
          Text(
            section.label.toUpperCase(),
            style: context.pText.labelSmall?.copyWith(
              color: XploreColors.subtleText,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (unread > 0) ...[
            const SizedBox(width: paddingUnit * 0.75),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: XploreColors.alternate.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(radiusSm),
              ),
              child: Text(
                '$unread new',
                style: context.pText.labelSmall?.copyWith(
                  color: XploreColors.alternate,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback? onTap;

  const _NotificationRow({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final unread = !item.isRead;
    final titleColor = unread ? XploreColors.white : XploreColors.white.withValues(alpha: 0.78);

    return GlassSurface(
      borderRadius: radiusMd,
      // Unread rows get a touch more fill so they sit slightly forward.
      tint: unread ? XploreColors.glassFillStrong : XploreColors.glassFill,
      padding: const EdgeInsets.fromLTRB(paddingUnit, paddingUnit, paddingUnit, paddingUnit),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconChip(item: item),
          const SizedBox(width: paddingUnit),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: context.pText.labelLarge?.copyWith(
                          color: titleColor,
                          fontWeight: unread ? FontWeight.w600 : FontWeight.w500,
                          letterSpacing: -0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: paddingUnit * 0.5),
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        item.timeLabel,
                        style: context.pText.labelSmall?.copyWith(color: XploreColors.subtleText),
                      ),
                    ),
                    if (unread) ...[
                      const SizedBox(width: paddingUnit * 0.5),
                      Container(
                        margin: const EdgeInsets.only(top: 5),
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: XploreColors.alternate),
                      ),
                    ] else
                      const SizedBox(width: paddingUnit * 0.5 + 7),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  item.body,
                  style: context.pText.bodySmall?.copyWith(
                    color: unread ? XploreColors.mutedText : XploreColors.subtleText,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  final NotificationItem item;

  const _IconChip({required this.item});

  @override
  Widget build(BuildContext context) {
    final accent = item.kind.accent;
    final faded = item.isRead;
    final initials = item.avatarInitials;

    // People events read as circular avatars; system/content events as rounded
    // square tiles — a small, familiar distinction that aids scanning.
    final isAvatar = initials != null;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: faded ? 0.12 : 0.18),
        shape: isAvatar ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isAvatar ? null : BorderRadius.circular(radiusSm),
        border: Border.all(color: accent.withValues(alpha: faded ? 0.22 : 0.34)),
      ),
      alignment: Alignment.center,
      child: isAvatar
          ? Text(
              initials,
              style: context.pText.labelLarge?.copyWith(color: accent, fontWeight: FontWeight.w600),
            )
          : Icon(item.kind.icon, size: 19, color: accent.withValues(alpha: faded ? 0.85 : 1)),
    );
  }
}
