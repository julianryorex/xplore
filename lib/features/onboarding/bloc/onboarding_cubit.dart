import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:xplore/features/onboarding/services/onboarding_analytics.dart';
import 'package:xplore/features/trip/data/place_catalog.dart';
import 'package:xplore/features/trip/models/nights_allocation.dart';
import 'package:xplore/features/trip/models/trip_draft.dart';
import 'package:xplore/features/trip/models/trip_invite.dart';
import 'package:xplore/features/trip/models/trip_model.dart';
import 'package:xplore/features/trip/models/trip_window.dart';
import 'package:xplore/features/trip/services/invite_link.dart';
import 'package:xplore/features/trip/services/invite_results.dart';
import 'package:xplore/features/trip/services/trip_service.dart';

part '../../../generated/features/onboarding/bloc/onboarding_cubit.freezed.dart';
part 'onboarding_state.dart';

/// Drives the onboarding flow (FEAT-005): which path the user is on, which
/// step is showing, and what they entered before signing in. Held in memory
/// only, so a signed-in user who relaunches the app goes straight to Home.
/// Imports no other cubit, per the architecture rule.
class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit(this._tripService, {this.analytics = const OnboardingAnalytics(), DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      super(const OnboardingState());

  final TripService _tripService;
  final OnboardingAnalytics analytics;

  /// Today's date, injectable so tests can pin where a trip's dates fall.
  final DateTime Function() _clock;

  /// Welcome -> destination, for someone planning their own trip.
  void startOrganizer() => _start(OnboardingPath.organizer);

  /// Welcome -> sign-in, for someone who already has an account.
  void startReturning() => _start(OnboardingPath.returning);

  /// Shows the invitee welcome for [link] and loads the trip preview for it.
  /// The preview is readable before sign-in; when it cannot be loaded the
  /// screen falls back to generic copy and the join screen reports why later.
  Future<void> startInvite(InviteLinkData link) async {
    emit(
      OnboardingState(path: OnboardingPath.invitee, inviteLink: link, invitePreviewStatus: InvitePreviewStatus.loading),
    );
    _logViewed();

    TripInvite? preview;
    try {
      final lookup = await _tripService.lookupInvite(link.tripId, link.token);
      if (lookup case InviteLookupValid(:final invite)) {
        preview = invite;
      }
    } catch (_) {
      // Leave the preview null; handled as unavailable below.
    }

    // The user may have dismissed the invite or opened another one meanwhile.
    if (isClosed || state.inviteLink != link) {
      return;
    }
    emit(
      state.copyWith(
        invitePreview: preview,
        invitePreviewStatus: preview == null ? InvitePreviewStatus.unavailable : InvitePreviewStatus.ready,
        tripUnderWay: _isUnderWay(preview?.startDate, preview?.endDate),
      ),
    );
  }

  void setDestination(CatalogPlace? place) => emit(state.copyWith(destination: place));

  /// Sets exact trip dates (date-only; swapped if reversed).
  void setDates(DateTime start, DateTime end) {
    var from = dateOnly(start);
    var to = dateOnly(end);
    if (to.isBefore(from)) {
      (from, to) = (to, from);
    }
    emit(state.copyWith(startDate: from, endDate: to, tripUnderWay: _isUnderWay(from, to)));
  }

  void clearDates() => emit(state.copyWith(startDate: null, endDate: null, tripUnderWay: false));

  /// Records that the organizer opened the share sheet for their invite link.
  void inviteShared() => emit(state.copyWith(inviteShared: true));

  /// Advances one step, or completes onboarding from the last one.
  void next() {
    if (state.completed) {
      return;
    }
    if (state.isLastStep) {
      analytics.completed(path: state.path.name);
      emit(state.copyWith(completed: true));
      return;
    }
    emit(state.copyWith(stepIndex: state.stepIndex + 1));
    _logViewed();
  }

  /// Like [next], recording that the user chose not to do the current step.
  void skip() {
    analytics.stepSkipped(path: state.path.name, step: state.step.name);
    next();
  }

  void back() {
    if (!state.canGoBack) {
      return;
    }
    emit(state.copyWith(stepIndex: state.stepIndex - 1));
  }

  /// Call when the user becomes authenticated. Moves past the sign-in step;
  /// ignored on any other step. An account that is not new ([isNewAccount]
  /// false) has a profile already, so its profile step is dropped.
  void onAuthenticated({bool isNewAccount = true}) {
    if (state.step != OnboardingStep.signIn) {
      return;
    }
    emit(state.copyWith(skipsProfile: !isNewAccount));
    next();
  }

  void tripSetupStarted() => emit(state.copyWith(tripSetup: TripSetupStatus.creating));

  void tripCreated(TripModel trip) => emit(state.copyWith(createdTrip: trip, tripSetup: TripSetupStatus.created));

  void tripSetupFailed() => emit(state.copyWith(tripSetup: TripSetupStatus.failed));

  /// Returns to a blank welcome screen, dropping everything entered so far.
  void reset() => emit(const OnboardingState());

  void _start(OnboardingPath path) {
    emit(OnboardingState(path: path, stepIndex: 1));
    _logViewed();
  }

  bool _isUnderWay(DateTime? start, DateTime? end) =>
      tripWindowOn(_clock(), start: start, end: end) == TripWindow.underWay;

  void _logViewed() => analytics.stepViewed(path: state.path.name, step: state.step.name);
}
