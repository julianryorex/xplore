import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:xplore/features/trip/models/timestamp_converter.dart';

part '../../../generated/features/trip/models/trip_invite.freezed.dart';
part '../../../generated/features/trip/models/trip_invite.g.dart';

/// A shareable invite to a trip, stored at `trips/{tripId}/invites/{token}`.
///
/// `tripTitle` and `memberCount` are denormalised from the parent trip at
/// creation time so the join-confirmation screen can render a preview *before*
/// the invitee is a member — a non-member cannot read the trip document itself
/// (Firestore rules restrict trip reads to members), but they can read this
/// invite doc because possession of the unguessable `token` (the doc id) is the
/// capability.
@freezed
abstract class TripInvite with _$TripInvite {
  const factory TripInvite({
    required String token,
    required String tripId,
    required String createdBy,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? expiresAt,
    @Default(false) bool revoked,
    @Default('') String tripTitle,
    @Default(0) int memberCount,
  }) = _TripInvite;

  factory TripInvite.fromJson(Map<String, Object?> json) => _$TripInviteFromJson(json);
}

extension TripInviteX on TripInvite {
  /// Whether the invite has passed its optional [expiresAt] cutoff. Invites
  /// with a `null` expiry never expire (the FEAT-003 default).
  bool isExpired(DateTime now) {
    final expiry = expiresAt;
    return expiry != null && !now.isBefore(expiry);
  }
}
