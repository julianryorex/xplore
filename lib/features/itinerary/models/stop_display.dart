import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/features/itinerary/services/place_search_service.dart';

final _dailyHours = RegExp(r'^\d{1,2}:\d{2}\s*[–-]\s*(\d{1,2}:\d{2})$');

/// How opening hours read in a list: "Open until 17:00" for "09:00–17:00",
/// free text such as "Open 24 hours" unchanged, and null when unknown.
String? openingHoursLabel(String openingHours) {
  final hours = openingHours.trim();
  if (hours.isEmpty) {
    return null;
  }
  final closing = _dailyHours.firstMatch(hours)?.group(1);
  return closing == null ? hours : 'Open until $closing';
}

/// The supporting line under a place name: "Temple · Asakusa", plus the
/// opening hours when [withHours] is set. Empty when nothing is known.
String placeSummary({
  required String category,
  required String neighbourhood,
  String openingHours = '',
  bool withHours = false,
}) {
  final parts = [category.trim(), neighbourhood.trim(), if (withHours) openingHoursLabel(openingHours) ?? ''];
  return parts.where((part) => part.isNotEmpty).join(' · ');
}

/// The supporting line under a stop's name wherever stops are listed. Custom
/// stops are always marked as such; a real place saved before place details
/// existed has nothing to show.
String stopSubtitle(LocationPlanModel stop, {bool withHours = false}) {
  if (stop.isCustom) {
    return 'Custom stop · No map pin';
  }
  return placeSummary(
    category: stop.category,
    neighbourhood: stop.neighbourhood,
    openingHours: stop.openingHours,
    withHours: withHours,
  );
}

/// A new stop for [place] with its details saved on it, carrying [note] for the group.
LocationPlanModel stopFromPlace(PlaceDetails place, {String note = '', bool completed = false}) {
  return LocationPlanModel(
    name: place.name,
    completed: completed,
    placeId: place.id,
    description: note,
    category: place.category,
    neighbourhood: place.neighbourhood,
    address: place.address,
    openingHours: place.openingHours,
    photoReference: place.photoReference,
  );
}

/// A new custom stop: a free-text [name] with no place behind it.
LocationPlanModel customStop(String name, {String note = '', bool completed = false}) {
  return LocationPlanModel(name: name.trim(), completed: completed, description: note);
}
