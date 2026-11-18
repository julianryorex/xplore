import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:xplore/features/trip/presentation/create_trip/route_map.dart';

void main() {
  const viewport = Size(350, routeMapHeight);
  const tokyo = LatLng(35.6762, 139.6503);
  const kyoto = LatLng(35.0116, 135.7681);
  const osaka = LatLng(34.6937, 135.5023);

  test('no places shows the world', () {
    expect(routeCameraFor(const [], viewport: viewport), worldRouteCamera);
  });

  test('one place is centred at a city-region zoom', () {
    expect(routeCameraFor(const [tokyo], viewport: viewport), const RouteCamera(tokyo, singleStopZoom));
  });

  test('several places are centred on their bounds and zoomed to fit inside the padding', () {
    final camera = routeCameraFor(const [tokyo, kyoto, osaka], viewport: viewport);

    expect(camera.target.longitude, closeTo((139.6503 + 135.5023) / 2, 0.001));
    expect(camera.target.latitude, inInclusiveRange(34.6937, 35.6762));
    // 4.15° of longitude across 350 - 112 px: 256 * 2^z * 4.15 / 360 <= 238.
    expect(camera.zoom, closeTo(6.33, 0.05));
  });

  test('a wider route zooms out further than a tighter one', () {
    const lisbon = LatLng(38.7223, -9.1393);
    final regional = routeCameraFor(const [tokyo, kyoto], viewport: viewport);
    final global = routeCameraFor(const [lisbon, tokyo], viewport: viewport);

    expect(global.zoom, lessThan(regional.zoom));
    expect(global.zoom, greaterThanOrEqualTo(worldRouteCamera.zoom));
  });

  test('places straddling the antimeridian are framed the short way round', () {
    const fiji = LatLng(-17.7134, 178.065);
    const samoa = LatLng(-13.759, -172.1046);
    final camera = routeCameraFor(const [fiji, samoa], viewport: viewport);

    // The short way spans ~9.8°, centred near 177°W, not ~350° centred on 3°E.
    expect(camera.target.longitude.abs(), greaterThan(175));
    expect(camera.zoom, greaterThan(4));
  });

  test('places at the same spot do not zoom past the route maximum', () {
    expect(routeCameraFor(const [tokyo, tokyo], viewport: viewport).zoom, maxRouteZoom);
  });

  test('a map without a size yet still gets a usable camera', () {
    final unsized = routeCameraFor(const [tokyo, kyoto], viewport: Size.zero);
    final sized = routeCameraFor(const [tokyo, kyoto], viewport: viewport);

    expect(unsized.zoom.isFinite, isTrue);
    expect(unsized.target, sized.target);
  });
}
