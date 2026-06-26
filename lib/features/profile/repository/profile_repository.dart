import 'dart:convert';

import 'package:hive_ce/hive.dart';
import 'package:logger/logger.dart';
import 'package:xplore/features/profile/models/profile_models.dart';
import 'package:xplore/utilities/utilities.dart';

/// Offline read cache for the cloud profile, keyed by `uid`.
///
/// Read-through only: the [ProfileCubit] Firestore listener is the sole writer
/// (`cacheProfile`), so the cache always trails the cloud source of truth. Stored
/// as a JSON string (via [UserProfile.toJson]) so no hand-written Hive
/// `TypeAdapter` is needed.
class ProfileRepository {
  late final HiveInterface _hive;
  late final Logger _logger;

  ProfileRepository({HiveInterface? hiveInterface}) {
    _hive = hiveInterface ?? Hive;
    _logger = createLogger('ProfileRepo');
  }

  static const cacheBoxName = 'profile-cache';

  Future<UserProfile?> loadFromCache(String uid) async {
    try {
      final box = await _hive.openBox(cacheBoxName);
      final raw = box.get(uid);
      if (raw is! String) {
        return null;
      }
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return UserProfile.fromJson(json);
    } catch (err) {
      _logger.w('Failed to load cached profile for $uid: $err');
      return null;
    }
  }

  Future<void> cacheProfile(UserProfile profile) async {
    try {
      final box = await _hive.openBox(cacheBoxName);
      await box.put(profile.uid, jsonEncode(profile.toJson()));
    } catch (err) {
      _logger.w('Failed to cache profile for ${profile.uid}: $err');
    }
  }

  Future<void> clear(String uid) async {
    try {
      final box = await _hive.openBox(cacheBoxName);
      await box.delete(uid);
    } catch (err) {
      _logger.w('Failed to clear cached profile for $uid: $err');
    }
  }
}
