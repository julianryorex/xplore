part of 'onboarding_cubit.dart';

/// Who is going through onboarding, which decides the screens they see.
enum OnboardingPath {
  /// Fresh install, planning their own trip.
  organizer,

  /// Arrived with an invite link to someone else's trip.
  invitee,

  /// Already has an account and only needs to sign in.
  returning,
}

enum OnboardingStep { welcome, destination, signIn, profile, invite, location, allSet }

/// Where the invitee welcome screen is with loading the trip preview.
enum InvitePreviewStatus { none, loading, ready, unavailable }

/// Where the organizer's trip is in being saved after sign-in.
enum TripSetupStatus { idle, creating, created, failed }

const _organizerSteps = [
  OnboardingStep.welcome,
  OnboardingStep.destination,
  OnboardingStep.signIn,
  OnboardingStep.profile,
  OnboardingStep.invite,
  OnboardingStep.location,
  OnboardingStep.allSet,
];

const _inviteeSteps = [OnboardingStep.welcome, OnboardingStep.signIn, OnboardingStep.profile, OnboardingStep.location];

const _returningSteps = [OnboardingStep.welcome, OnboardingStep.signIn];

@freezed
abstract class OnboardingState with _$OnboardingState {
  const factory OnboardingState({
    @Default(OnboardingPath.organizer) OnboardingPath path,
    @Default(0) int stepIndex,
    @Default(false) bool completed,

    /// Drops the profile step, for an account that set itself up on an earlier sign-in.
    @Default(false) bool skipsProfile,

    /// Whether the trip is running today. Location is only shared during a
    /// trip, so the location step is only shown when this holds.
    @Default(false) bool tripUnderWay,

    /// Organizer: whether they opened the share sheet on the invite step.
    @Default(false) bool inviteShared,

    /// Organizer: the place picked on the destination step.
    CatalogPlace? destination,

    /// Organizer: optional exact dates, date-only. Both set or both null.
    DateTime? startDate,
    DateTime? endDate,
    TripModel? createdTrip,
    @Default(TripSetupStatus.idle) TripSetupStatus tripSetup,

    /// Invitee: the link they arrived with, joined once onboarding completes.
    InviteLinkData? inviteLink,
    TripInvite? invitePreview,
    @Default(InvitePreviewStatus.none) InvitePreviewStatus invitePreviewStatus,
  }) = _OnboardingState;

  const OnboardingState._();

  List<OnboardingStep> get steps {
    final pathSteps = switch (path) {
      OnboardingPath.organizer => _organizerSteps,
      OnboardingPath.invitee => _inviteeSteps,
      OnboardingPath.returning => _returningSteps,
    };
    return [...pathSteps.where(_isShown)];
  }

  bool _isShown(OnboardingStep step) => switch (step) {
    OnboardingStep.profile => !skipsProfile,
    OnboardingStep.location => tripUnderWay,
    // The send-off celebrates a saved trip, so it is dropped when saving failed.
    OnboardingStep.allSet => tripSetup != TripSetupStatus.failed,
    _ => true,
  };

  OnboardingStep get step => steps[stepIndex];

  bool get isLastStep => stepIndex == steps.length - 1;

  /// True from the moment the user leaves the welcome screen until they finish.
  /// The auth gate keeps showing onboarding while this holds, so the steps after
  /// sign-in are not cut short by the user becoming authenticated.
  bool get isInProgress => !completed && stepIndex > 0;

  /// Steps counted by the progress bar: every step between the welcome screen
  /// and the send-off.
  int get progressTotal =>
      steps.where((step) => step != OnboardingStep.welcome && step != OnboardingStep.allSet).length;

  /// 1-based position within [progressTotal]; 0 on the welcome screen.
  int get progressCurrent => stepIndex;

  /// Going back is blocked on welcome, on the send-off, and once signed in,
  /// since the screens before sign-in no longer apply to an authenticated user.
  bool get canGoBack => stepIndex > 0 && step != OnboardingStep.allSet && steps[stepIndex - 1] != OnboardingStep.signIn;

  bool get hasDates => startDate != null && endDate != null;

  /// The trip to create for the organizer: one stop named after the place, with
  /// every other create-flow input left at its default. Null without a place.
  TripDraft? get tripDraft {
    final place = destination;
    if (place == null) {
      return null;
    }
    final stayNights = hasDates ? nightsBetween(startDate!, endDate!) : defaultFlexibleNights;
    return TripDraft(
      stops: [place.toStop(nights: stayNights)],
      datesAreFlexible: !hasDates,
      startDate: startDate,
      endDate: endDate,
      title: place.name,
    );
  }
}
