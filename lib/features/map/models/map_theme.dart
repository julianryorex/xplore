import 'dart:ui';

/// Colour schemes the live map can be drawn in. [land], [water] and [park]
/// mirror the style's main colours for the picker's preview swatch.
enum MapTheme {
  dusk(
    label: 'Dusk',
    description: 'Deep teal land, blue water',
    asset: 'assets/maps/dusk.json',
    land: Color(0xFF1F2D2E),
    water: Color(0xFF14505C),
    park: Color(0xFF1F4A3A),
  ),
  midnight(
    label: 'Midnight',
    description: 'Neutral greys, near-black water',
    asset: 'assets/maps/midnight.json',
    land: Color(0xFF1C1C1E),
    water: Color(0xFF08090A),
    park: Color(0xFF1B2A24),
  ),
  daylight(
    label: 'Daylight',
    description: 'Light and soft',
    asset: 'assets/maps/daylight.json',
    land: Color(0xFFF2EFE9),
    water: Color(0xFFA8D8E0),
    park: Color(0xFFC9E6CF),
  );

  const MapTheme({
    required this.label,
    required this.description,
    required this.asset,
    required this.land,
    required this.water,
    required this.park,
  });

  final String label;
  final String description;
  final String asset;
  final Color land;
  final Color water;
  final Color park;

  static const fallback = MapTheme.dusk;
}
