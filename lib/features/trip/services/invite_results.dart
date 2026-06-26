import 'package:xplore/features/trip/models/trip_invite.dart';
import 'package:xplore/features/trip/models/trip_model.dart';

/// Max members allowed on a trip for the free tier. Plus (20) waits on the
/// paywall (FEAT-020); enforce 6 everywhere until then. Mirrored by the
/// Firestore `validTripJoin` rule, which is the authoritative server-side
/// guard — this constant powers the client-side pre-check and messaging.
const maxFreeTierTripMembers = 6;

/// Why an invite could not be used. Shared by lookup (preview) and accept.
enum InviteFailureReason {
  /// No invite document exists for the given trip + token.
  notFound,

  /// The organizer revoked the invite.
  revoked,

  /// The invite is past its `expiresAt` cutoff.
  expired,

  /// The trip is already at its member cap.
  tripFull,

  /// Any other failure (network, permission, malformed data).
  unavailable,
}

extension InviteFailureReasonX on InviteFailureReason {
  /// Human-readable copy for the join-confirmation screen's error states.
  String get title => switch (this) {
    InviteFailureReason.notFound => 'Invite not found',
    InviteFailureReason.revoked => 'Invite revoked',
    InviteFailureReason.expired => 'Invite expired',
    InviteFailureReason.tripFull => 'Trip is full',
    InviteFailureReason.unavailable => 'Invite unavailable',
  };

  String get message => switch (this) {
    InviteFailureReason.notFound => 'This invite link is invalid. Ask the organizer to send a new one.',
    InviteFailureReason.revoked => 'The organizer turned off this invite link. Ask them for a fresh one.',
    InviteFailureReason.expired => 'This invite link has expired. Ask the organizer for a new one.',
    InviteFailureReason.tripFull =>
      'This trip has reached its $maxFreeTierTripMembers-member limit. The organizer can upgrade to add more.',
    InviteFailureReason.unavailable => 'We couldn\u2019t open this invite. Please check your connection and try again.',
  };
}

/// The output of [createInvite]: the stored invite plus its shareable link.
class TripInviteHandle {
  const TripInviteHandle({required this.invite, required this.link});

  final TripInvite invite;
  final String link;
}

/// Result of looking up an invite for the preview screen.
sealed class InviteLookup {
  const InviteLookup();

  const factory InviteLookup.valid(TripInvite invite) = InviteLookupValid;

  const factory InviteLookup.invalid(InviteFailureReason reason) = InviteLookupInvalid;
}

class InviteLookupValid extends InviteLookup {
  const InviteLookupValid(this.invite);

  final TripInvite invite;
}

class InviteLookupInvalid extends InviteLookup {
  const InviteLookupInvalid(this.reason);

  final InviteFailureReason reason;
}

/// Result of attempting to accept (join via) an invite.
sealed class InviteAcceptResult {
  const InviteAcceptResult();

  const factory InviteAcceptResult.joined(TripModel trip) = InviteJoined;

  const factory InviteAcceptResult.failed(InviteFailureReason reason) = InviteJoinFailed;
}

class InviteJoined extends InviteAcceptResult {
  const InviteJoined(this.trip);

  final TripModel trip;
}

class InviteJoinFailed extends InviteAcceptResult {
  const InviteJoinFailed(this.reason);

  final InviteFailureReason reason;
}
