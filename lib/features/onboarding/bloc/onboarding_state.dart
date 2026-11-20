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

enum OnboardingStep { welcome, destination, signIn, profile, invite, location }

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
];

const _inviteeSteps = [OnboardingStep.welcome, OnboardingStep.signIn, OnboardingStep.profile, OnboardingStep.location];

const _returningSteps = [OnboardingStep.welcome, OnboardingStep.signIn];

@freezed
abstract class OnboardingState with _$OnboardingState {
  const factory OnboardingState({
    @Default(OnboardingPath.organizer) OnboardingPath path,
    @Default(0) int stepIndex,
    @Default(false) bool completed,

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

  List<OnboardingStep> get steps => switch (path) {
    OnboardingPath.organizer => _organizerSteps,
    OnboardingPath.invitee => _inviteeSteps,
    OnboardingPath.returning => _returningSteps,
  };

  OnboardingStep get step => steps[stepIndex];

  bool get isLastStep => stepIndex == steps.length - 1;

  /// True from the moment the user leaves the welcome screen until they finish.
  /// The auth gate keeps showing onboarding while this holds, so the steps after
  /// sign-in are not cut short by the user becoming authenticated.
  bool get isInProgress => !completed && stepIndex > 0;

  /// Steps counted by the progress bar: every step after welcome.
  int get progressTotal => steps.length - 1;

  /// 1-based position within [progressTotal]; 0 on the welcome screen.
  int get progressCurrent => stepIndex;

  /// Going back is blocked on welcome and once signed in, since the screens
  /// before sign-in no longer apply to an authenticated user.
  bool get canGoBack => stepIndex > 0 && steps[stepIndex - 1] != OnboardingStep.signIn;

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
