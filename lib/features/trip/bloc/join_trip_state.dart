import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:xplore/features/trip/models/trip_invite.dart';
import 'package:xplore/features/trip/models/trip_model.dart';
import 'package:xplore/features/trip/services/invite_results.dart';

part '../../../generated/features/trip/bloc/join_trip_state.freezed.dart';

@freezed
sealed class JoinTripState with _$JoinTripState {
  /// Fetching the invite preview.
  const factory JoinTripState.looking() = JoinTripLooking;

  /// Invite is valid; show the confirmation screen with [invite] preview.
  const factory JoinTripState.ready(TripInvite invite) = JoinTripReady;

  /// Accept is in flight; keep the [invite] preview on screen.
  const factory JoinTripState.joining(TripInvite invite) = JoinTripJoining;

  /// Successfully joined [trip].
  const factory JoinTripState.joined(TripModel trip) = JoinTripJoined;

  /// Invite cannot be used (not found / revoked / expired / full / unavailable).
  const factory JoinTripState.invalid(InviteFailureReason reason) = JoinTripInvalid;
}
