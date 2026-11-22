/// A real place as the itinerary stores it on a stop. [id] is the provider's
/// place id; [openingHours] is "HH:MM–HH:MM" or free text such as "Open 24 hours".
class PlaceDetails {
  const PlaceDetails({
    required this.id,
    required this.name,
    required this.category,
    required this.neighbourhood,
    required this.city,
    required this.address,
    this.openingHours = '',
    this.photoReference = '',
  });

  final String id;
  final String name;
  final String category;
  final String neighbourhood;
  final String city;
  final String address;
  final String openingHours;
  final String photoReference;
}

/// Thrown when a place search cannot be completed, e.g. the device is offline.
class PlaceSearchException implements Exception {
  const PlaceSearchException(this.message);

  final String message;

  @override
  String toString() => 'PlaceSearchException: $message';
}

/// Finds real places for itinerary stops. The app never calls Google Places
/// itself: the production implementation will call our own backend, and until
/// then `MockPlaceSearchService` stands in. Swap it where it is provided in `main.dart`.
abstract interface class PlaceSearchService {
  /// Places matching [query], those in or around [near] first. An empty
  /// [query] suggests places around [near]. Throws [PlaceSearchException] on failure.
  Future<List<PlaceDetails>> search(String query, {String near = ''});
}
