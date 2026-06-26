import 'package:freezed_annotation/freezed_annotation.dart';

part '../../../generated/features/profile/models/profile_models.freezed.dart';
part '../../../generated/features/profile/models/profile_models.g.dart';

/// The cloud user profile stored at Firestore `users/{uid}` (FEAT-015).
///
/// Only the fields the app renders/syncs are modelled; other doc fields
/// (`usernameLower`, `providers`, `createdAt`, `lastSeenAt`) are ignored by
/// `fromJson`. `markerUrl` is reserved for the cross-device avatar fetch
/// (FEAT-015 PR 2 / FEAT-046) and is not yet written here.
@freezed
abstract class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String uid,
    @Default('') String displayName,
    String? email,
    String? photoUrl,
    String? username,
    String? markerUrl,
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, Object?> json) => _$UserProfileFromJson(json);
}
