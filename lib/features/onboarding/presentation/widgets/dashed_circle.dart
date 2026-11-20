import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';

/// A circle with a dashed outline, used across onboarding for a seat in the
/// group that nobody has taken yet. [child] is centred inside it.
class DashedCircle extends StatelessWidget {
  const DashedCircle({
    required this.size,
    this.color = XploreColors.accent,
    this.fillColor,
    this.strokeWidth = 2,
    this.child,
    super.key,
  });

  final double size;

  /// The outline's colour.
  final Color color;

  /// Painted behind the outline when set; otherwise the circle is see-through.
  final Color? fillColor;
  final double strokeWidth;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedCirclePainter(color: color, fillColor: fillColor, strokeWidth: strokeWidth),
      child: SizedBox.square(
        dimension: size,
        child: Center(child: child),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({required this.color, required this.fillColor, required this.strokeWidth});

  final Color color;
  final Color? fillColor;
  final double strokeWidth;

  static const _dashCount = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final fill = fillColor;
    if (fill != null) {
      canvas.drawOval(rect, Paint()..color = fill);
    }

    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    const sweep = 2 * math.pi / _dashCount;
    for (var dash = 0; dash < _dashCount; dash++) {
      canvas.drawArc(rect, dash * sweep, sweep * 0.55, false, outline);
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.fillColor != fillColor || oldDelegate.strokeWidth != strokeWidth;
}
