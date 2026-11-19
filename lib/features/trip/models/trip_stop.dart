import 'package:freezed_annotation/freezed_annotation.dart';

part '../../../generated/features/trip/models/trip_stop.freezed.dart';
part '../../../generated/features/trip/models/trip_stop.g.dart';

/// One place on a trip, in visiting order. [id] is the stable place-catalog id
/// so a stop can be matched back to its catalog entry (themes, colours).
@freezed
abstract class TripStop with _$TripStop {
  const factory TripStop({
    required String id,
    required String name,
    required String country,
    required double latitude,
    required double longitude,
    @Default(1) int nights,
  }) = _TripStop;

  factory TripStop.fromJson(Map<String, Object?> json) => _$TripStopFromJson(json);
}

/// The short place label for a list of stops: the place name for one stop, the
/// shared country when every stop is in one country (e.g. "Japan"), otherwise
/// `<first> + N more`. Empty for no stops.
String stopsHeadline(List<TripStop> stops) {
  if (stops.isEmpty) {
    return '';
  }
  if (stops.length == 1) {
    return stops.single.name;
  }
  final country = _sharedCountry(stops);
  if (country != null) {
    return country;
  }
  return '${stops.first.name} + ${stops.length - 1} more';
}

/// The countries of [stops] in visiting order, without duplicates or blanks.
List<String> stopCountries(List<TripStop> stops) =>
    stops.map((stop) => stop.country.trim()).where((country) => country.isNotEmpty).toSet().toList();

String? _sharedCountry(List<TripStop> stops) {
  final first = stops.first.country.trim();
  if (first.isEmpty) {
    return null;
  }
  return stops.every((stop) => stop.country.trim() == first) ? first : null;
}
