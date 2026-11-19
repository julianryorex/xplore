import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/features/map/models/map_theme.dart';
import 'package:xplore/features/map/services/map_theme_store.dart';
import 'package:xplore/features/trip/models/trip_stop.dart';

/// Height of the route preview on the where step.
const routeMapHeight = 200.0;

/// Builds the surface the route is drawn on. Widget tests pass one that avoids
/// the Google Map platform view, which cannot render there.
typedef RouteMapSurfaceBuilder = Widget Function(BuildContext context, List<TripStop> stops);

/// Where the route map's camera points.
@immutable
class RouteCamera {
  const RouteCamera(this.target, this.zoom);

  final LatLng target;
  final double zoom;

  CameraPosition get position => CameraPosition(target: target, zoom: zoom);

  @override
  bool operator ==(Object other) => other is RouteCamera && other.target == target && other.zoom == zoom;

  @override
  int get hashCode => Object.hash(target, zoom);

  @override
  String toString() => 'RouteCamera($target, zoom: $zoom)';
}

/// The wide view shown before the trip has a place.
const worldRouteCamera = RouteCamera(LatLng(20, 0), 1);

/// Zoom for a single place: the city and its surroundings.
const singleStopZoom = 9.0;

/// Closest a multi-place route zooms in, so two neighbouring places still show
/// some context around them.
const maxRouteZoom = 11.0;

/// Room kept between the outermost pins and the map's edge.
const routeMapPadding = EdgeInsets.symmetric(horizontal: 56, vertical: 44);

// Used when fitting is asked for before the map has been laid out.
const _fallbackViewport = Size(350, routeMapHeight);

// Web-mercator tiles are 256 logical px wide at zoom 0.
const _tileSize = 256.0;

/// The camera that frames [points] in a map of [viewport] size: a world view for
/// none, a city-region zoom for one, and for more the tightest zoom that keeps
/// every point inside [padding]. Spans across the antimeridian use the narrower
/// way round, and an empty [viewport] (map not laid out yet) uses a typical size.
RouteCamera routeCameraFor(List<LatLng> points, {required Size viewport, EdgeInsets padding = routeMapPadding}) {
  if (points.isEmpty) {
    return worldRouteCamera;
  }
  if (points.length == 1) {
    return RouteCamera(points.single, singleStopZoom);
  }

  final longitudes = _narrowestLongitudeSpan(points.map((point) => point.longitude).toList());
  final ys = points.map((point) => _mercatorY(point.latitude)).toList();
  final minY = ys.reduce(math.min);
  final maxY = ys.reduce(math.max);

  final size = viewport.isEmpty ? _fallbackViewport : viewport;
  final width = math.max(size.width - padding.horizontal, 1.0);
  final height = math.max(size.height - padding.vertical, 1.0);

  final zoomForWidth = longitudes.span == 0 ? maxRouteZoom : _log2(width / (longitudes.span / 360 * _tileSize));
  final zoomForHeight = maxY == minY ? maxRouteZoom : _log2(height / ((maxY - minY) * _tileSize));
  final zoom = math.min(zoomForWidth, zoomForHeight).clamp(worldRouteCamera.zoom, maxRouteZoom);

  return RouteCamera(LatLng(_latitudeForMercatorY((minY + maxY) / 2), longitudes.center), zoom);
}

/// The shortest arc of longitude covering every value: the complement of the
/// widest gap between neighbouring longitudes, counting the gap across ±180°.
({double center, double span}) _narrowestLongitudeSpan(List<double> longitudes) {
  final sorted = longitudes.map(_normalizeLongitude).toList()..sort();
  var widestGap = sorted.first + 360 - sorted.last;
  var start = sorted.first;
  for (var i = 1; i < sorted.length; i++) {
    final gap = sorted[i] - sorted[i - 1];
    if (gap > widestGap) {
      widestGap = gap;
      start = sorted[i];
    }
  }
  final span = 360 - widestGap;
  return (center: _normalizeLongitude(start + span / 2), span: span);
}

double _normalizeLongitude(double longitude) => (longitude + 180) % 360 - 180;

/// Web-mercator y in 0..1 (north to south) for [latitude].
double _mercatorY(double latitude) {
  final sinLat = math.sin(latitude.clamp(-85.0, 85.0) * math.pi / 180);
  return 0.5 - math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi);
}

double _latitudeForMercatorY(double y) => (math.atan(_sinh(math.pi * (1 - 2 * y)))) * 180 / math.pi;

double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2;

double _log2(double x) => math.log(x) / math.ln2;

/// The trip's places on a small, non-interactive map: numbered pins in visiting
/// order joined by a line, framed so the whole route is in view. With no places
/// it shows the world and a hint to add the first one.
class RouteMap extends StatelessWidget {
  const RouteMap({required this.stops, this.surfaceBuilder, super.key});

  final List<TripStop> stops;

  /// Replaces the Google Map; see [RouteMapSurfaceBuilder].
  final RouteMapSurfaceBuilder? surfaceBuilder;

  @override
  Widget build(BuildContext context) {
    final names = stops.map((stop) => stop.name).join(', ');
    return Semantics(
      container: true,
      image: true,
      label: stops.isEmpty ? 'Map. No places yet' : 'Map of the route: $names',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radiusLg),
        child: SizedBox(
          height: routeMapHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // A preview only: it must never take drags from the page scroll.
              ExcludeSemantics(
                child: IgnorePointer(child: surfaceBuilder?.call(context, stops) ?? _GoogleRouteMap(stops: stops)),
              ),
              if (stops.isEmpty) const ExcludeSemantics(child: _EmptyRouteHint()),
              if (stops.isNotEmpty)
                Positioned(
                  left: 8,
                  top: 8,
                  child: ExcludeSemantics(child: _PlaceCountBadge(count: stops.length)),
                ),
              // Inset hairline so a dark map still reads as a framed object on black.
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radiusLg),
                    border: Border.all(color: XploreColors.white.withValues(alpha: 0.08)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyRouteHint extends StatelessWidget {
  const _EmptyRouteHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: XploreColors.background.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text('Add your first place', style: XploreText.footnoteStrong.copyWith(color: XploreColors.white)),
        ),
      ),
    );
  }
}

class _PlaceCountBadge extends StatelessWidget {
  const _PlaceCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: XploreColors.background.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        count == 1 ? '1 place' : '$count places',
        style: XploreText.caption.copyWith(color: XploreColors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// The real map surface: styled with the user's saved map theme, pins and a
/// geodesic line in visiting order, re-framed whenever the route changes.
class _GoogleRouteMap extends StatefulWidget {
  const _GoogleRouteMap({required this.stops});

  final List<TripStop> stops;

  @override
  State<_GoogleRouteMap> createState() => _GoogleRouteMapState();
}

class _GoogleRouteMapState extends State<_GoogleRouteMap> {
  GoogleMapController? _controller;
  String? _style;
  Size _viewport = Size.zero;
  double _pixelRatio = 1;
  Map<int, BitmapDescriptor> _pins = const {};

  List<LatLng> get _points => [for (final stop in widget.stops) LatLng(stop.latitude, stop.longitude)];

  @override
  void initState() {
    super.initState();
    _loadStyle();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    if (pixelRatio != _pixelRatio || _pins.isEmpty) {
      _pixelRatio = pixelRatio;
      _pins = const {};
      _loadPins();
    }
  }

  @override
  void didUpdateWidget(_GoogleRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameRoute(oldWidget.stops, widget.stops)) {
      _loadPins();
      _fitCamera();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadStyle() async {
    var theme = MapTheme.fallback;
    try {
      theme = await MapThemeStore().load();
    } catch (_) {
      // No saved preference readable (e.g. storage not ready): keep the default.
    }
    final style = await rootBundle.loadString(theme.asset);
    if (mounted) {
      setState(() => _style = style);
    }
  }

  Future<void> _loadPins() async {
    final pixelRatio = _pixelRatio;
    final count = widget.stops.length;
    final pins = <int, BitmapDescriptor>{};
    for (var number = 1; number <= count; number++) {
      pins[number] = await _routePin(number, pixelRatio);
    }
    if (mounted && pixelRatio == _pixelRatio) {
      setState(() => _pins = {..._pins, ...pins});
    }
  }

  void _fitCamera() {
    final controller = _controller;
    if (controller == null || _viewport.isEmpty) {
      // onMapCreated or the next layout fits it once both exist.
      return;
    }
    final update = CameraUpdate.newCameraPosition(routeCameraFor(_points, viewport: _viewport).position);
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.moveCamera(update);
    } else {
      controller.animateCamera(update);
    }
  }

  void _onViewport(Size size) {
    if (size == _viewport) {
      return;
    }
    _viewport = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fitCamera();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;
    if (style == null) {
      return ColoredBox(color: MapTheme.fallback.land);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        _onViewport(size);
        return GoogleMap(
          style: style,
          initialCameraPosition: routeCameraFor(_points, viewport: size).position,
          onMapCreated: (controller) {
            _controller = controller;
            _fitCamera();
          },
          markers: _markers(),
          polylines: _polylines(),
          compassEnabled: false,
          mapToolbarEnabled: false,
          zoomControlsEnabled: false,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          rotateGesturesEnabled: false,
          scrollGesturesEnabled: false,
          tiltGesturesEnabled: false,
          zoomGesturesEnabled: false,
          buildingsEnabled: false,
          indoorViewEnabled: false,
        );
      },
    );
  }

  Set<Marker> _markers() {
    final stops = widget.stops;
    return {
      for (var i = 0; i < stops.length; i++)
        // Wait for the drawn pin rather than flashing the default red marker.
        if (_pins[i + 1] case final icon?)
          Marker(
            markerId: MarkerId(stops[i].id),
            position: LatLng(stops[i].latitude, stops[i].longitude),
            icon: icon,
            anchor: const Offset(0.5, 0.5),
            // Earlier stops on top, so the start of the route stays readable.
            zIndexInt: stops.length - i,
          ),
    };
  }

  Set<Polyline> _polylines() {
    if (widget.stops.length < 2) {
      return const {};
    }
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: _points,
        color: XploreColors.accent,
        width: 3,
        geodesic: true,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };
  }
}

bool _sameRoute(List<TripStop> a, List<TripStop> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i].id != b[i].id || a[i].latitude != b[i].latitude || a[i].longitude != b[i].longitude) {
      return false;
    }
  }
  return true;
}

// Pins only differ by number and pixel ratio, so each is drawn once per app run.
final _pinCache = <(int, double), Future<BitmapDescriptor>>{};

Future<BitmapDescriptor> _routePin(int number, double pixelRatio) {
  final key = (number, pixelRatio);
  return _pinCache.putIfAbsent(key, () {
    final pin = _drawRoutePin(number, pixelRatio);
    // A failed draw must not stay cached, so the next build retries it.
    pin.then<void>(
      (_) {},
      onError: (Object _) {
        _pinCache.remove(key);
      },
    );
    return pin;
  });
}

/// A Jade disc with a white ring and the stop's number, drawn at [pixelRatio]
/// so it stays sharp; the canvas leaves room for a soft shadow.
Future<BitmapDescriptor> _drawRoutePin(int number, double pixelRatio) async {
  const canvasSize = 30.0;
  const center = Offset(canvasSize / 2, canvasSize / 2);
  const radius = 12.0;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(pixelRatio);
  canvas.drawCircle(
    center.translate(0, 1.5),
    radius,
    Paint()
      ..color = const Color(0x80000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
  );
  canvas.drawCircle(center, radius, Paint()..color = XploreColors.white);
  canvas.drawCircle(center, radius - 2, Paint()..color = XploreColors.accent);

  final label = TextPainter(
    text: TextSpan(
      text: '$number',
      style: XploreText.caption.copyWith(color: XploreColors.onAccent, fontWeight: FontWeight.w800, height: 1),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  label.paint(canvas, center - Offset(label.width / 2, label.height / 2));
  label.dispose();

  final pixels = (canvasSize * pixelRatio).ceil();
  final image = await recorder.endRecording().toImage(pixels, pixels);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), imagePixelRatio: pixelRatio);
}
