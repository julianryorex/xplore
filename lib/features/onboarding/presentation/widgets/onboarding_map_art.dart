import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/features/onboarding/presentation/widgets/dashed_circle.dart';

/// Avatar fills for the illustrated group members. They differ in lightness as
/// well as hue so they stay distinguishable without colour vision.
abstract final class OnboardingAvatarColors {
  static const sand = Color(0xFFE8C27A);
  static const onSand = Color(0xFF2A1F08);
  static const blue = Color(0xFF9DBBFF);
  static const onBlue = Color(0xFF0B1B3D);
  static const coral = Color(0xFFF2A084);
  static const onCoral = Color(0xFF3A1206);
}

/// One marker on [OnboardingMapArt], placed by [alignment] within the map.
class MapArtPin {
  const MapArtPin({
    required this.alignment,
    this.label = '',
    this.color = XploreColors.raised,
    this.labelColor = XploreColors.white,
    this.isPlaceholder = false,
  });

  final Alignment alignment;

  /// Short text inside the pin: an initial or "You".
  final String label;
  final Color color;
  final Color labelColor;

  /// Draws a dashed empty slot instead of a filled avatar, for someone who
  /// has not joined yet.
  final bool isPlaceholder;
}

/// A drawn, dark map (grid, roads, water) with optional avatar [pins] and a
/// dotted Jade [showRoute] line. Purely decorative: it stands in for the live
/// map on screens shown before the user has a trip or has granted location.
class OnboardingMapArt extends StatelessWidget {
  const OnboardingMapArt({
    required this.height,
    this.pins = const [],
    this.showRoute = false,
    this.highlight,
    this.borderRadius = radiusLg,
    super.key,
  });

  final double height;
  final List<MapArtPin> pins;
  final bool showRoute;

  /// Centre of a soft Jade "you are here" halo, when set.
  final Alignment? highlight;
  final double borderRadius;

  static const _pinSize = 44.0;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _MapPainter(showRoute: showRoute, highlight: highlight),
              ),
              for (final pin in pins)
                Align(
                  alignment: pin.alignment,
                  child: _Pin(pin: pin, size: _pinSize),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.pin, required this.size});

  final MapArtPin pin;
  final double size;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      pin.label,
      style: XploreText.footnoteStrong.copyWith(color: pin.isPlaceholder ? XploreColors.accent : pin.labelColor),
    );

    if (pin.isPlaceholder) {
      return DashedCircle(size: size, fillColor: _MapPainter.ground, child: label);
    }

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: pin.color,
        shape: BoxShape.circle,
        border: Border.all(color: XploreColors.accent, width: 2.5),
      ),
      child: label,
    );
  }
}

class _MapPainter extends CustomPainter {
  const _MapPainter({required this.showRoute, required this.highlight});

  final bool showRoute;
  final Alignment? highlight;

  static const ground = Color(0xFF0A0A0B);
  static const _grid = Color(0xFF151517);
  static const _water = Color(0xFF0C1D17);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = ground);

    final grid = Paint()
      ..color = _grid
      ..strokeWidth = 1.5;
    for (final fraction in const [0.2, 0.48, 0.76]) {
      canvas.drawLine(Offset(0, h * fraction), Offset(w, h * fraction), grid);
    }
    for (final fraction in const [0.18, 0.44, 0.7, 0.9]) {
      canvas.drawLine(Offset(w * fraction, 0), Offset(w * fraction, h), grid);
    }

    final water = Path()
      ..moveTo(0, h * 0.84)
      ..cubicTo(w * 0.25, h * 0.72, w * 0.42, h * 0.9, w * 0.64, h * 0.8)
      ..cubicTo(w * 0.8, h * 0.73, w * 0.9, h * 0.76, w, h * 0.82)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(water, Paint()..color = _water);

    final road = Paint()
      ..color = XploreColors.raised
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(-10, h * 0.62)
        ..cubicTo(w * 0.2, h * 0.52, w * 0.34, h * 0.38, w * 0.54, h * 0.36)
        ..cubicTo(w * 0.72, h * 0.34, w * 0.86, h * 0.2, w + 10, h * 0.16),
      road,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.32, -10)
        ..cubicTo(w * 0.36, h * 0.25, w * 0.26, h * 0.55, w * 0.34, h + 10),
      road,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.78, -10)
        ..cubicTo(w * 0.73, h * 0.25, w * 0.83, h * 0.5, w * 0.79, h + 10),
      road,
    );

    final halo = highlight;
    if (halo != null) {
      final centre = halo.alongSize(size);
      canvas.drawCircle(centre, 46, Paint()..color = XploreColors.accent.withValues(alpha: 0.12));
      canvas.drawCircle(centre, 28, Paint()..color = XploreColors.accent.withValues(alpha: 0.17));
    }

    if (showRoute) {
      _paintRoute(canvas, w, h);
    }
  }

  void _paintRoute(Canvas canvas, double w, double h) {
    final route = Path()
      ..moveTo(w * 0.2, h * 0.6)
      ..cubicTo(w * 0.32, h * 0.5, w * 0.44, h * 0.42, w * 0.54, h * 0.4)
      ..cubicTo(w * 0.66, h * 0.37, w * 0.74, h * 0.3, w * 0.8, h * 0.22);
    final dot = Paint()..color = XploreColors.accent;
    for (final metric in route.computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += 10) {
        final position = metric.getTangentForOffset(distance)?.position;
        if (position != null) {
          canvas.drawCircle(position, 1.5, dot);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_MapPainter oldDelegate) =>
      oldDelegate.showRoute != showRoute || oldDelegate.highlight != highlight;
}
