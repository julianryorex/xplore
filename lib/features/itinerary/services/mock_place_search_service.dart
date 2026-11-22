import 'package:xplore/features/itinerary/data/mock_places.dart';
import 'package:xplore/features/itinerary/services/place_search_service.dart';
import 'package:xplore/utilities/fold_for_search.dart';

/// [PlaceSearchService] over a bundled list of real places, standing in for
/// the backend place search. Makes no network calls.
class MockPlaceSearchService implements PlaceSearchService {
  const MockPlaceSearchService({
    this.places = mockPlaces,
    this.latency = const Duration(milliseconds: 350),
    this.maxResults = 8,
  });

  final List<PlaceDetails> places;

  /// Simulated round trip, so the loading state is visible while developing.
  final Duration latency;
  final int maxResults;

  @override
  Future<List<PlaceDetails>> search(String query, {String near = ''}) async {
    if (latency > Duration.zero) {
      await Future<void>.delayed(latency);
    }
    final needle = foldForSearch(query.trim());
    final area = foldForSearch(near.trim());

    final ranked = <(int, PlaceDetails)>[];
    for (final place in places) {
      final rank = _rank(place, needle, area);
      if (rank != null) {
        ranked.add((rank, place));
      }
    }
    // A stable sort keeps catalog order within a rank.
    final sorted = [...ranked]..sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final (_, place) in sorted.take(maxResults)) place];
  }

  /// Lower is better; null leaves the place out. Nearby places always outrank
  /// the rest, and a name match outranks a category or neighbourhood match.
  int? _rank(PlaceDetails place, String needle, String area) {
    final nearby = area.isNotEmpty && _isNear(place, area);
    if (needle.isEmpty) {
      // Suggestions: only nearby places, or anything when the area is unknown.
      return nearby || area.isEmpty ? 0 : null;
    }
    final name = foldForSearch(place.name);
    final int match;
    if (name.startsWith(needle)) {
      match = 0;
    } else if (name.contains(needle)) {
      match = 1;
    } else if (foldForSearch(place.category).contains(needle) ||
        foldForSearch(place.neighbourhood).contains(needle) ||
        foldForSearch(place.city).contains(needle)) {
      match = 2;
    } else {
      return null;
    }
    return (nearby ? 0 : 10) + match;
  }

  static bool _isNear(PlaceDetails place, String area) {
    final city = foldForSearch(place.city);
    final neighbourhood = foldForSearch(place.neighbourhood);
    return area.contains(city) || city.contains(area) || area.contains(neighbourhood);
  }
}
