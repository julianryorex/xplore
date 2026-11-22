import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/onboarding/bloc/onboarding_cubit.dart';
import 'package:xplore/features/trip/data/place_catalog.dart';
import 'package:xplore/features/trip/models/nights_allocation.dart';
import 'package:xplore/features/trip/services/invite_link.dart';
import 'package:xplore/features/trip/services/trip_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late OnboardingCubit cubit;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    cubit = OnboardingCubit(TripService(firestore: firestore));
  });

  tearDown(() => cubit.close());

  Future<InviteLinkData> seedInvite() async {
    final trip = firestore.collection('trips').doc();
    await trip.set(<String, dynamic>{
      'title': 'Lisbon',
      'memberIds': ['owner-1'],
      'createdBy': 'owner-1',
      'lastUpdatedBy': 'owner-1',
      'createdAt': Timestamp.now(),
      'lastUpdatedAt': Timestamp.now(),
    });
    final handle = await TripService(firestore: firestore).createInvite(trip.id, 'owner-1');
    return InviteLink.parse(Uri.parse(handle.link))!;
  }

  /// Advances through every remaining step, signing in at the sign-in step.
  List<OnboardingStep> walkToEnd() {
    final visited = [cubit.state.step];
    while (!cubit.state.completed) {
      if (cubit.state.step == OnboardingStep.signIn) {
        cubit.onAuthenticated();
      } else {
        cubit.next();
      }
      if (!cubit.state.completed) {
        visited.add(cubit.state.step);
      }
    }
    return visited;
  }

  test('the organizer path runs destination, sign-in, profile, invite, then the send-off', () {
    cubit.startOrganizer();

    expect(walkToEnd(), [
      OnboardingStep.destination,
      OnboardingStep.signIn,
      OnboardingStep.profile,
      OnboardingStep.invite,
      OnboardingStep.allSet,
    ]);
    expect(cubit.state.progressTotal, 4, reason: 'the send-off is not a counted step');
  });

  group('the location step', () {
    OnboardingCubit cubitOn(DateTime today) =>
        OnboardingCubit(TripService(firestore: firestore), clock: () => today)..startOrganizer();

    test('is shown when the trip is under way, first and last day included', () async {
      for (final today in [DateTime(2027, 6, 3, 23), DateTime(2027, 6, 6), DateTime(2027, 6, 9, 1)]) {
        final underWay = cubitOn(today)..setDates(DateTime(2027, 6, 3), DateTime(2027, 6, 9));

        expect(underWay.state.steps, contains(OnboardingStep.location), reason: 'on $today');
        await underWay.close();
      }
    });

    test('is left out before the trip starts, after it ends, and without dates', () async {
      final upcoming = cubitOn(DateTime(2027, 6, 2))..setDates(DateTime(2027, 6, 3), DateTime(2027, 6, 9));
      final ended = cubitOn(DateTime(2027, 6, 10))..setDates(DateTime(2027, 6, 3), DateTime(2027, 6, 9));
      final undated = cubitOn(DateTime(2027, 6, 6))
        ..setDates(DateTime(2027, 6, 3), DateTime(2027, 6, 9))
        ..clearDates();

      for (final other in [upcoming, ended, undated]) {
        expect(other.state.steps, isNot(contains(OnboardingStep.location)));
        await other.close();
      }
    });
  });

  test('the send-off is dropped when the trip could not be saved', () {
    cubit
      ..startOrganizer()
      ..tripSetupFailed();

    expect(cubit.state.steps, isNot(contains(OnboardingStep.allSet)));
  });

  test('a replay runs the organizer flow without the sign-in step', () {
    cubit.startReplay();

    expect(walkToEnd(), [
      OnboardingStep.destination,
      OnboardingStep.profile,
      OnboardingStep.invite,
      OnboardingStep.allSet,
    ]);
  });

  test('a replay cannot go back to the destination once its trip is being saved', () {
    cubit
      ..startReplay()
      ..next();

    expect(cubit.state.step, OnboardingStep.profile);
    expect(cubit.state.canGoBack, isFalse);
  });

  test('the returning path completes as soon as the user signs in', () {
    cubit.startReturning();
    expect(cubit.state.step, OnboardingStep.signIn);

    cubit.onAuthenticated();

    expect(cubit.state.completed, isTrue);
    expect(cubit.state.isInProgress, isFalse);
  });

  test('the invitee path skips trip creation and loads the invite preview', () async {
    final link = await seedInvite();

    await cubit.startInvite(link);

    expect(cubit.state.invitePreviewStatus, InvitePreviewStatus.ready);
    expect(cubit.state.invitePreview?.tripTitle, 'Lisbon');
    expect(walkToEnd(), [OnboardingStep.welcome, OnboardingStep.signIn, OnboardingStep.profile]);
    expect(cubit.state.inviteLink, link);
  });

  test('an invite that cannot be found is marked unavailable but stays joinable', () async {
    const link = InviteLinkData(tripId: 'missing-trip', token: 'missing-token');

    await cubit.startInvite(link);

    expect(cubit.state.invitePreviewStatus, InvitePreviewStatus.unavailable);
    expect(cubit.state.inviteLink, link);
  });

  test('an account that has signed in before skips the profile step', () {
    cubit.startOrganizer();
    cubit.next();

    cubit.onAuthenticated(isNewAccount: false);

    expect(cubit.state.step, OnboardingStep.invite);
    expect(cubit.state.progressTotal, 3);
  });

  test('becoming authenticated outside the sign-in step does not move the flow', () {
    cubit.startOrganizer();

    cubit.onAuthenticated();

    expect(cubit.state.step, OnboardingStep.destination);
  });

  test('back is blocked once the user has signed in', () {
    cubit.startOrganizer();
    cubit.next();
    expect(cubit.state.canGoBack, isTrue);

    cubit.onAuthenticated();

    expect(cubit.state.step, OnboardingStep.profile);
    expect(cubit.state.canGoBack, isFalse);
    cubit.back();
    expect(cubit.state.step, OnboardingStep.profile);
  });

  group('tripDraft', () {
    final place = placeCatalog.places.first;

    test('is null until a destination is picked', () {
      expect(cubit.state.tripDraft, isNull);
    });

    test('with exact dates spends every night at the destination', () {
      cubit.setDestination(place);
      // Passed in reverse to cover the swap.
      cubit.setDates(DateTime(2027, 6, 9, 15), DateTime(2027, 6, 3, 8));

      final draft = cubit.state.tripDraft!;

      expect(draft.startDate, DateTime(2027, 6, 3));
      expect(draft.endDate, DateTime(2027, 6, 9));
      expect(draft.stops.single.nights, 6);
      expect(draft.isNightsAllocationValid, isTrue);
      expect(draft.effectiveTitle, place.name);
    });

    test('without dates is a flexible trip with the default nights', () {
      cubit.setDestination(place);
      cubit.setDates(DateTime(2027, 6, 3), DateTime(2027, 6, 9));
      cubit.clearDates();

      final draft = cubit.state.tripDraft!;

      expect(draft.datesAreFlexible, isTrue);
      expect(draft.stops.single.nights, defaultFlexibleNights);
      expect(draft.isNightsAllocationValid, isTrue);
    });
  });
}
