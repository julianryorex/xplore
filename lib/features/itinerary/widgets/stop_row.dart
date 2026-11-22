import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/features/itinerary/models/stop_display.dart';

/// Leading inset of a stop row's text: row padding, the 44pt leading target and
/// the gap after it. Hairlines between stop rows start here.
const stopRowTextIndent = 12.0 + minTouchTarget + 12.0;

/// Smallest height of a stop row in the day list and in edit mode.
const stopRowMinHeight = 60.0;

/// A stop's name over its supporting line, as listed on the day page and in
/// edit mode. A [completed] stop is struck through; an [unsaved] one is muted
/// and says "Not saved" in place of its details.
class StopText extends StatelessWidget {
  const StopText({required this.stop, this.completed = false, this.unsaved = false, super.key});

  final LocationPlanModel stop;
  final bool completed;
  final bool unsaved;

  @override
  Widget build(BuildContext context) {
    final subtitle = unsaved ? 'Not saved' : stopSubtitle(stop);
    final muted = completed || unsaved;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stop.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: XploreText.bodyStrong.copyWith(
            color: muted ? XploreColors.secondaryLabel : XploreColors.white,
            decoration: completed ? TextDecoration.lineThrough : null,
            decorationColor: XploreColors.secondaryLabel,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 1),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: XploreText.footnote.copyWith(color: unsaved ? XploreColors.error : XploreColors.secondaryLabel),
          ),
        ],
      ],
    );
  }
}

/// The 26pt circle that shows whether a stop is done: an accent disc with a
/// check when [completed], an outline otherwise, dashed when [unsaved].
/// Purely visual; callers decide whether it is tappable.
class CompletionIndicator extends StatelessWidget {
  const CompletionIndicator({required this.completed, this.unsaved = false, super.key});

  final bool completed;
  final bool unsaved;

  static const _size = 26.0;

  @override
  Widget build(BuildContext context) {
    if (completed) {
      return Container(
        width: _size,
        height: _size,
        decoration: const BoxDecoration(color: XploreColors.accent, shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, size: 17, color: XploreColors.onAccent),
      );
    }
    return CustomPaint(
      size: const Size.square(_size),
      painter: _OutlinedCirclePainter(dashed: unsaved),
    );
  }
}

class _OutlinedCirclePainter extends CustomPainter {
  const _OutlinedCirclePainter({required this.dashed});

  final bool dashed;

  static const _strokeWidth = 1.5;
  static const _dashCount = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = XploreColors.secondaryLabel
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;
    final rect = (Offset.zero & size).deflate(_strokeWidth / 2);
    if (!dashed) {
      canvas.drawOval(rect, paint);
      return;
    }
    const sweep = 2 * math.pi / _dashCount;
    for (var dash = 0; dash < _dashCount; dash++) {
      canvas.drawArc(rect, dash * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_OutlinedCirclePainter oldDelegate) => oldDelegate.dashed != dashed;
}
