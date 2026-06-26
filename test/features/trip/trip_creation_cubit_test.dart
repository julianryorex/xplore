import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/features/trip/bloc/trip_creation_cubit.dart';
import 'package:xplore/features/trip/bloc/trip_creation_state.dart';
import 'package:xplore/features/trip/models/trip_draft.dart';
import 'package:xplore/features/trip/services/itinerary_generator.dart';

void main() {
  group('TripDraft', () {
    test('durationDays uses the exact range when dates are fixed', () {
      final draft = TripDraft(datesAreFlexible: false, startDate: DateTime(2026, 6, 1), endDate: DateTime(2026, 6, 5));
      expect(draft.durationDays, 5);
    });

    test('durationDays falls back to flexible duration', () {
      const draft = TripDraft(flexibleDurationDays: 7);
      expect(draft.durationDays, 7);
    });

    test('suggestedTitle adapts to the group kind', () {
      const solo = TripDraft(destination: 'Tokyo', groupKind: TripGroupKind.solo);
      const friends = TripDraft(destination: 'Tokyo', groupKind: TripGroupKind.friends);
      expect(solo.suggestedTitle, 'Tokyo getaway');
      expect(friends.suggestedTitle, 'Tokyo with friends');
    });
  });

  group('DeterministicItineraryGenerator', () {
    test('produces one day per duration day, anchored to the destination', () async {
      const generator = DeterministicItineraryGenerator();
      final plans = await generator.generate(const TripDraft(destination: 'Lisbon', flexibleDurationDays: 3));

      expect(plans, hasLength(3));
      expect(plans.first.title, 'Day 1');
      expect(plans.every((p) => p.location == 'Lisbon'), isTrue);
    });
  });

  group('TripCreationCubit', () {
    late TripCreationCubit cubit;

    setUp(() => cubit = TripCreationCubit(const DeterministicItineraryGenerator()));
    tearDown(() => cubit.close());

    test('starts on the destination step and gates Continue until set', () {
      expect(cubit.state.currentStep, CreateTripStep.destination);
      expect(cubit.state.canAdvance, isFalse);

      cubit.setDestination('Tokyo');
      expect(cubit.state.canAdvance, isTrue);
    });

    test('next/back walk the step list', () {
      cubit
        ..setDestination('Tokyo')
        ..next();
      expect(cubit.state.currentStep, CreateTripStep.dates);
      cubit.back();
      expect(cubit.state.currentStep, CreateTripStep.destination);
    });

    test('generate produces a skeleton and gates the generate step', () async {
      cubit.setDestination('Tokyo');
      // Jump to the generate step.
      while (cubit.state.currentStep != CreateTripStep.generate) {
        cubit.next();
      }
      expect(cubit.state.canAdvance, isFalse);

      await cubit.generate();

      expect(cubit.state.phase, TripCreationPhase.generated);
      expect(cubit.state.itinerary, isNotEmpty);
      expect(cubit.state.canAdvance, isTrue);
    });

    test('editing a generation input invalidates an existing skeleton', () async {
      cubit.setDestination('Tokyo');
      while (cubit.state.currentStep != CreateTripStep.generate) {
        cubit.next();
      }
      await cubit.generate();
      expect(cubit.state.phase, TripCreationPhase.generated);

      cubit.setFlexibleDuration(9);
      expect(cubit.state.phase, TripCreationPhase.editing);
      expect(cubit.state.itinerary, isEmpty);
    });

    test('toggleInterest adds then removes', () {
      cubit.toggleInterest(TripInterest.food);
      expect(cubit.state.draft.interests, contains(TripInterest.food));
      cubit.toggleInterest(TripInterest.food);
      expect(cubit.state.draft.interests, isEmpty);
    });
  });

  group('ItineraryModel round-trip', () {
    test('a generated skeleton serializes through DailyPlanModel.toJson', () async {
      const generator = DeterministicItineraryGenerator();
      final plans = await generator.generate(const TripDraft(destination: 'Oslo', flexibleDurationDays: 2));
      final json = plans.map((p) => p.toJson()).toList();
      final parsed = json.map((j) => DailyPlanModel.fromJson(j)).toList();

      expect(parsed, hasLength(2));
      expect(parsed.first.title, 'Day 1');
      expect(parsed.first.location, 'Oslo');
    });
  });
}
