import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:xplore/features/auth/services/auth_service.dart';
import 'package:xplore/features/trip/bloc/join_trip_state.dart';
import 'package:xplore/features/trip/services/invite_results.dart';
import 'package:xplore/features/trip/services/trip_service.dart';
import 'package:xplore/utilities/utilities.dart';

/// Drives the join-confirmation screen for a single invite ([tripId] +
/// [token]): looks up the preview, then accepts on user confirmation. Composes
/// [TripService] + [AuthService] via constructor injection and imports no other
/// cubit (per the architecture rule) — the screen wires the joined trip into
/// `TripCubit.setActiveTrip` itself.
class JoinTripCubit extends Cubit<JoinTripState> {
  JoinTripCubit(this._tripService, this._authService, {required this.tripId, required this.token})
    : super(const JoinTripState.looking());

  final TripService _tripService;
  final AuthService _authService;
  final String tripId;
  final String token;

  final Logger _logger = createLogger('JoinTripCubit');

  /// Fetches the invite preview. Safe to call again to retry after a failure.
  Future<void> loadPreview() async {
    emit(const JoinTripState.looking());
    try {
      final lookup = await _tripService.lookupInvite(tripId, token);
      switch (lookup) {
        case InviteLookupValid(:final invite):
          emit(JoinTripState.ready(invite));
        case InviteLookupInvalid(:final reason):
          emit(JoinTripState.invalid(reason));
      }
    } catch (error, stackTrace) {
      _logger.e('Invite lookup failed', error: error, stackTrace: stackTrace);
      emit(const JoinTripState.invalid(InviteFailureReason.unavailable));
    }
  }

  /// Accepts the invite for the signed-in user. Emits [JoinTripJoined] on
  /// success so the screen can activate the trip and navigate Home.
  Future<void> join() async {
    final current = state;
    if (current is! JoinTripReady) {
      return;
    }

    final uid = _authService.currentUid;
    if (uid == null) {
      // The deep-link handler should route through auth first; guard anyway.
      emit(const JoinTripState.invalid(InviteFailureReason.unavailable));
      return;
    }

    emit(JoinTripState.joining(current.invite));
    try {
      final result = await _tripService.acceptInvite(tripId: tripId, token: token, uid: uid);
      switch (result) {
        case InviteJoined(:final trip):
          emit(JoinTripState.joined(trip));
        case InviteJoinFailed(:final reason):
          emit(JoinTripState.invalid(reason));
      }
    } catch (error, stackTrace) {
      _logger.e('Invite accept failed', error: error, stackTrace: stackTrace);
      emit(const JoinTripState.invalid(InviteFailureReason.unavailable));
    }
  }
}
