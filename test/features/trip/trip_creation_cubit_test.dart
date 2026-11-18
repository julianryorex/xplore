import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/features/trip/bloc/trip_creation_cubit.dart';
import 'package:xplore/features/trip/bloc/trip_creation_state.dart';
import 'package:xplore/features/trip/data/place_catalog.dart';
import 'package:xplore/features/trip/models/nights_allocation.dart';
import 'package:xplore/features/trip/models/trip_draft.dart';
import 'package:xplore/features/trip/models/trip_model.dart';
import 'package:xplore/features/trip/services/itinerary_generator.dart';

CatalogPlace _place(String id) => placeCatalog.byId(id)!;

List<int> _nights(TripCreationCubit cubit) => cubit.state.draft.stops.map((stop) => stop.nights).toList();

void main() {
  late TripCreationCubit cubit;

  setUp(() => cubit = TripCreationCubit());
  tearDown(() => cubit.close());

  void addPlaces(List<String> ids) {
    for (final id in ids) {
      cubit.addStop(_place(id));
    }
  }

  void goTo(CreateTripStep step) {
    while (cubit.state.currentStep != step) {
      final before = cubit.state.stepIndex;
      cubit.next();
      expect(cubit.state.stepIndex, isNot(before), reason: 'blocked by ${cubit.state.advanceBlocker}');
    }
  }

  group('steps', () {
    test('walks where, when, who and vibe, plan, then invite', () {
      expect(cubit.state.steps, [
        CreateTripStep.where,
        CreateTripStep.when,
        CreateTripStep.whoAndVibe,
        CreateTripStep.plan,
        CreateTripStep.invite,
      ]);
      expect(cubit.state.currentStep, CreateTripStep.where);
    });

    test('where is blocked until a place is added', () {
      expect(cubit.state.advanceBlocker, CreateTripBlocker.noStops);
      cubit.next();
      expect(cubit.state.currentStep, CreateTripStep.where);

      cubit.addStop(_place('tokyo'));
      expect(cubit.state.canAdvance, isTrue);
    });

    test('when is blocked while the nights do not add up', () {
      addPlaces(['tokyo', 'kyoto']);
      goTo(CreateTripStep.when);
      cubit
        ..setExactDates(DateTime(2026, 4, 1), DateTime(2026, 4, 11))
        ..setStopNights('tokyo', 4);

      expect(cubit.state.advanceBlocker, CreateTripBlocker.nightsInvalid);
      expect(cubit.state.draft.nightsAllocation.issue, NightsIssue.unassigned);

      cubit.splitNightsEvenly();
      expect(cubit.state.canAdvance, isTrue);
    });

    test('who and vibe never blocks', () {
      addPlaces(['tokyo']);
      goTo(CreateTripStep.whoAndVibe);
      expect(cubit.state.canAdvance, isTrue);
      expect(cubit.state.currentStep.isSkippable, isTrue);
    });

    test('plan blocks an over-long title and while submitting', () {
      addPlaces(['tokyo']);
      goTo(CreateTripStep.plan);
      expect(cubit.state.canAdvance, isTrue);

      cubit.setTitle('x' * (maxTripTitleLength + 1));
      expect(cubit.state.advanceBlocker, CreateTripBlocker.titleTooLong);

      cubit
        ..setTitle('Tokyo')
        ..markSubmitting();
      expect(cubit.state.advanceBlocker, CreateTripBlocker.submitting);
    });

    test('leaves the plan step only once the trip is created, and not back again', () {
      addPlaces(['tokyo']);
      goTo(CreateTripStep.plan);
      cubit.next();
      expect(cubit.state.currentStep, CreateTripStep.plan);

      cubit
        ..markSubmitting()
        ..markCreated(const TripModel(id: 't1', title: 'Solo in Tokyo', memberIds: ['u'], createdBy: 'u'))
        ..next();
      expect(cubit.state.currentStep, CreateTripStep.invite);

      cubit.back();
      expect(cubit.state.currentStep, CreateTripStep.invite);
      expect(cubit.state.hasUnsavedInput, isFalse);
    });
  });

  group('stops', () {
    test('ignores duplicates and caps the trip at the maximum', () {
      addPlaces(['tokyo', 'tokyo']);
      expect(cubit.state.draft.stops, hasLength(1));

      final more = placeCatalog.places.where((place) => place.id != 'tokyo').take(maxTripStops);
      more.forEach(cubit.addStop);
      expect(cubit.state.draft.stops, hasLength(maxTripStops));
      expect(cubit.state.canAddStop, isFalse);
    });

    test('reorder follows ReorderableListView indexes and keeps nights', () {
      addPlaces(['tokyo', 'hakone', 'kyoto']);
      cubit
        ..setStopNights('tokyo', 4)
        ..reorderStops(0, 3); // drag Tokyo to the end

      expect(cubit.state.draft.stops.map((stop) => stop.id), ['hakone', 'kyoto', 'tokyo']);
      expect(cubit.state.draft.stops.last.nights, 4);

      cubit.reorderStops(2, 0);
      expect(cubit.state.draft.stops.map((stop) => stop.id), ['tokyo', 'hakone', 'kyoto']);
    });

    test('flexible trips grow by a default stay per added place and shrink on removal', () {
      addPlaces(['lisbon', 'porto']);
      expect(_nights(cubit), [defaultFlexibleNights, defaultFlexibleNights]);

      cubit
        ..setStopNights('lisbon', 5)
        ..removeStop('porto');
      expect(_nights(cubit), [5]);
    });
  });

  group('nights with exact dates', () {
    setUp(() {
      addPlaces(['tokyo', 'hakone', 'kyoto']);
      cubit.setExactDates(DateTime(2026, 4, 1), DateTime(2026, 4, 11)); // 10 nights
    });

    test('setting dates splits the nights evenly', () {
      expect(_nights(cubit), [4, 3, 3]);
      expect(cubit.state.draft.isNightsAllocationValid, isTrue);
    });

    test('changing one stop does not touch the others', () {
      cubit.setStopNights('hakone', 1);
      expect(_nights(cubit), [4, 1, 3]);
      expect(cubit.state.draft.nightsAllocation.assigned, 8);
    });

    test('adding or removing a place re-splits; reordering does not', () {
      cubit
        ..setStopNights('tokyo', 6)
        ..setStopNights('hakone', 1);

      cubit.reorderStops(2, 0);
      expect(_nights(cubit), [3, 6, 1]);

      cubit.addStop(_place('osaka'));
      expect(_nights(cubit), [3, 3, 2, 2]);

      cubit.removeStop('osaka');
      expect(_nights(cubit), [4, 3, 3]);
    });

    test('new dates of a different length re-split; the same length keeps the tuning', () {
      cubit.setStopNights('tokyo', 5);
      cubit.setStopNights('kyoto', 2);
      cubit.setExactDates(DateTime(2026, 5, 1), DateTime(2026, 5, 11));
      expect(_nights(cubit), [5, 3, 2]);

      cubit.setExactDates(DateTime(2026, 5, 1), DateTime(2026, 5, 7));
      expect(_nights(cubit), [2, 2, 2]);
    });

    test('reversed dates are swapped', () {
      cubit.setExactDates(DateTime(2026, 6, 8, 15), DateTime(2026, 6, 2));
      expect(cubit.state.draft.startDate, DateTime(2026, 6, 2));
      expect(cubit.state.draft.endDate, DateTime(2026, 6, 8));
    });

    test('too few nights for the places is reported specifically', () {
      cubit.setExactDates(DateTime(2026, 4, 1), DateTime(2026, 4, 3));
      expect(cubit.state.draft.nightsAllocation.issue, NightsIssue.fewerNightsThanStops);
    });

    test('switching to flexible keeps the nights as the trip length', () {
      cubit
        ..setStopNights('tokyo', 6)
        ..setFlexible();
      expect(_nights(cubit), [6, 3, 3]);
      expect(cubit.state.draft.durationDays, 13);
      expect(cubit.state.draft.isNightsAllocationValid, isTrue);
    });
  });

  test('a single place on a same-day trip is a valid day trip', () {
    addPlaces(['kamakura']);
    cubit.setExactDates(DateTime(2026, 5, 2), DateTime(2026, 5, 2));

    expect(_nights(cubit), [0]);
    goTo(CreateTripStep.plan);
    expect(cubit.state.itinerary, hasLength(1));

    cubit.setFlexible();
    expect(_nights(cubit), [1]);
  });

  group('plan', () {
    test('is built on entering the plan step', () {
      addPlaces(['tokyo', 'kyoto']);
      expect(cubit.state.plan, isNull);

      goTo(CreateTripStep.plan);
      expect(cubit.state.itinerary, hasLength(5)); // 2 + 2 nights + departure day
    });

    test('is dropped by trip-shape edits elsewhere and rebuilt on the next visit', () {
      addPlaces(['tokyo', 'kyoto']);
      goTo(CreateTripStep.plan);
      cubit
        ..back()
        ..setPace(TripPace.packed);
      expect(cubit.state.plan, isNotNull, reason: 'pace does not shape the stub plan');

      cubit
        ..back()
        ..back()
        ..reorderStops(1, 0);
      expect(cubit.state.plan, isNull);

      goTo(CreateTripStep.plan);
      expect(cubit.state.itinerary.first.location, 'Kyoto');
    });

    test('is rebuilt at once when the trip changes on the plan step', () {
      addPlaces(['tokyo']);
      goTo(CreateTripStep.plan);
      cubit.setStopNights('tokyo', 4);
      expect(cubit.state.itinerary, hasLength(5));
    });
  });

  test('hasUnsavedInput turns on with any input but not for seeded notes', () {
    final seeded = TripCreationCubit(initialNotes: 'Cherry blossoms');
    addTearDown(seeded.close);
    expect(seeded.state.hasUnsavedInput, isFalse);
    expect(seeded.state.draft.notes, 'Cherry blossoms');

    seeded.toggleInterest(TripInterest.food);
    expect(seeded.state.hasUnsavedInput, isTrue);
  });

  test('toggleInterest adds then removes', () {
    cubit.toggleInterest(TripInterest.food);
    expect(cubit.state.draft.interests, contains(TripInterest.food));
    cubit.toggleInterest(TripInterest.food);
    expect(cubit.state.draft.interests, isEmpty);
  });

  group('DeterministicItineraryGenerator', () {
    test('produces one day per duration day anchored to the destination, and round-trips through JSON', () async {
      const generator = DeterministicItineraryGenerator();
      final draft = TripDraft(stops: [_place('lisbon').toStop(nights: 2)]);
      final plans = await generator.generate(draft);
      final parsed = plans.map((plan) => DailyPlanModel.fromJson(plan.toJson())).toList();

      expect(parsed, hasLength(3));
      expect(parsed.first.title, 'Day 1');
      expect(parsed.every((plan) => plan.location == 'Lisbon'), isTrue);
    });
  });
}
