import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

/// Reads a date from Firestore (`Timestamp`), an in-memory `DateTime`, or an
/// ISO-8601 string (demo JSON + Hive cache), and always writes an ISO-8601
/// string so a serialized itinerary stays JSON/Hive friendly for the offline
/// cache. Firestore writes build their own maps with `FieldValue.serverTimestamp()`
/// rather than going through `toJson`, so the lossy ISO write-back is only ever
/// used for the local cache and tests.
class ItineraryDateConverter implements JsonConverter<DateTime?, Object?> {
  const ItineraryDateConverter();

  @override
  DateTime? fromJson(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }

    throw FormatException('Unsupported date value: $value');
  }

  @override
  Object? toJson(DateTime? date) => date?.toIso8601String();
}
