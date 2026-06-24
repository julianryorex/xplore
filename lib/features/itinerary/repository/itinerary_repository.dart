import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:logger/logger.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/utilities/utilities.dart';

/// Offline read cache for itineraries, keyed by `tripId`.
///
/// Stores the itinerary as a JSON string (via [ItineraryModel.toJson], which
/// emits ISO-8601 dates) rather than typed objects, so no hand-written Hive
/// `TypeAdapter`s are needed and the box round-trips cleanly through
/// `jsonDecode`.
class ItineraryRepository {
  late final HiveInterface _hive;
  late final Logger _logger;

  ItineraryRepository({HiveInterface? hiveInterface}) {
    _hive = hiveInterface ?? Hive;
    _logger = createLogger('ItineraryRepo');
  }

  static const cacheBoxName = 'itinerary-cache';

  Future<ItineraryModel?> loadFromCache(String tripId) async {
    try {
      final box = await _hive.openBox(cacheBoxName);
      final raw = box.get(tripId);
      if (raw is! String) {
        return null;
      }
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return ItineraryModel.fromJson(json);
    } catch (err) {
      _logger.w('Failed to load cached itinerary for $tripId: $err');
      return null;
    }
  }

  Future<void> cacheItinerary(String tripId, ItineraryModel itinerary) async {
    try {
      final box = await _hive.openBox(cacheBoxName);
      await box.put(tripId, jsonEncode(itinerary.toJson()));
    } catch (err) {
      _logger.w('Failed to cache itinerary for $tripId: $err');
    }
  }

  Future<void> reset() async {
    try {
      final box = await _hive.openBox(cacheBoxName);
      await box.deleteFromDisk();
      _logger.d('Cleared itinerary cache box');
    } catch (err) {
      _logger.w('Failed to reset itinerary cache: $err');
    }
  }
}
