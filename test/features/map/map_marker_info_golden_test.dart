// Renders a faithful representation of the map member markers + their
// `InfoWindow` content driven by the SAME helpers the live map uses
// (`formatLastSeen` for the label, `isLocationStale` for the fade).
//
// The live `google_maps_flutter` map + native InfoWindow cannot run on the
// Linux CI box (iOS/macOS target), so this golden captures the exact text and
// stale-opacity behavior the change produces, using real `LocationModel` data.
//
//   flutter test --update-goldens test/features/map/map_marker_info_golden_test.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/theme.dart';
import 'package:xplore/features/location/models/location_models.dart';
import 'package:xplore/features/location/utils/last_seen.dart';

Future<void> _loadPoppins() async {
  final loader = FontLoader('Poppins')
    ..addFont(rootBundle.load('assets/fonts/Poppins-Medium.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Poppins-SemiBold.ttf'));
  await loader.load();
}

/// A pin + the `InfoWindow` bubble exactly as the map populates it:
/// `title: 'Last seen ${formatLastSeen(lastUpdated)}'`, faded when stale.
class _MarkerPreview extends StatelessWidget {
  final String initial;
  final Color color;
  final LocationModel location;
  final DateTime now;

  const _MarkerPreview({required this.initial, required this.color, required this.location, required this.now});

  @override
  Widget build(BuildContext context) {
    final stale = isLocationStale(location.lastUpdated, now: now);
    final label = 'Last seen ${formatLastSeen(location.lastUpdated, now: now)}';

    return Opacity(
      opacity: stale ? 0.5 : 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // InfoWindow bubble.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF211D28),
              ),
            ),
          ),
          // Bubble tail.
          CustomPaint(size: const Size(16, 8), painter: _TailPainter()),
          const SizedBox(height: 4),
          // Avatar pin.
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void main() {
  testWidgets('Map marker InfoWindows render relative "last seen" labels', (tester) async {
    await _loadPoppins();

    // Fixed reference clock so the rendered labels are deterministic.
    final now = DateTime(2026, 6, 23, 17, 0, 0);

    final members = <(String, Color, LocationModel)>[
      (
        'J',
        XploreColors.alternate,
        LocationModel(id: 'm1', lat: 40.713, lng: -73.957, lastUpdated: now.subtract(const Duration(seconds: 20))),
      ),
      (
        'S',
        XploreColors.info,
        LocationModel(id: 'm2', lat: 40.714, lng: -73.958, lastUpdated: now.subtract(const Duration(minutes: 4))),
      ),
      (
        'A',
        XploreColors.warning,
        LocationModel(id: 'm3', lat: 40.715, lng: -73.959, lastUpdated: now.subtract(const Duration(minutes: 23))),
      ),
      (
        'M',
        XploreColors.error,
        LocationModel(id: 'm4', lat: 40.716, lng: -73.960, lastUpdated: now.subtract(const Duration(hours: 2))),
      ),
    ];

    tester.view.physicalSize = const Size(900, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: getTheme(),
        home: Scaffold(
          body: Container(
            // Approximate the dark "neon" map backdrop.
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [const Color(0xFF12202B), const Color(0xFF0B1620)],
              ),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final (initial, color, location) in members)
                    _MarkerPreview(initial: initial, color: color, location: location, now: now),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/map_marker_last_seen.png'));
  });
}
