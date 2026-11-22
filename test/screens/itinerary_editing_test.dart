// The itinerary screens show edit controls to the trip owner only, and keep
// the plan on screen when a save fails. Goldens are Apple-only (`make test-gold`).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/home/models/trip_overview.dart';
import 'package:xplore/features/home/widgets/itinerary_preview.dart';
import 'package:xplore/features/itinerary/bloc/itinerary_cubit.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/features/itinerary/widgets/save_status.dart';
import 'package:xplore/features/trip/models/trip_model.dart';
import 'package:xplore/screens/itinerary_focus_page.dart';
import 'package:xplore/screens/itinerary_overview_page.dart';

import '../helpers/pump_app.dart';

const _day = DailyPlanModel(
  title: 'Asakusa and the river',
  location: 'Tokyo',
  plan: PlanModel(
    favorited: [],
    locations: [
      LocationPlanModel(
        name: 'Kappabashi Kitchen Street',
        completed: true,
        placeId: 'mock:tokyo-kappabashi',
        category: 'Shopping street',
        neighbourhood: 'Kappabashi',
      ),
      LocationPlanModel(
        name: 'Sensō-ji',
        placeId: 'mock:tokyo-sensoji',
        description: 'Meet by the big lantern.',
        category: 'Temple',
        neighbourhood: 'Asakusa',
        openingHours: '06:00–17:00',
      ),
      LocationPlanModel(name: 'Back to the hotel lobby'),
    ],
  ),
);

const _itinerary = ItineraryModel(id: 'trip-1', invitees: ['user-1'], dailyPlans: [_day], pins: []);

LoadedItineraryState _state({required bool canEdit, ItinerarySaveFailure? saveFailure}) {
  return LoadedItineraryState(itinerary: _itinerary, canEdit: canEdit, saveFailure: saveFailure);
}

/// Pumps [page] over an [ItineraryCubit] pinned to [state], at phone size.
Future<void> _pump(WidgetTester tester, Widget page, LoadedItineraryState state) async {
  final cubit = ItineraryCubit()..emit(state);
  addTearDown(cubit.close);
  await pumpForGolden(
    tester,
    page,
    size: const Size(390, 844),
    providers: [BlocProvider<ItineraryCubit>.value(value: cubit)],
  );
}

void main() {
  group('day page', () {
    testWidgets('the owner gets Edit, Add stop and completion toggles', (tester) async {
      await _pump(tester, const ItineraryOverviewPage(dayIndex: 0), _state(canEdit: true));

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Add stop'), findsOneWidget);
      expect(find.bySemanticsLabel('Mark Sensō-ji done'), findsOneWidget);
      expect(find.text('Custom stop · No map pin'), findsOneWidget);
      await expectLater(find.byType(ItineraryOverviewPage), matchesGoldenFile('goldens/itinerary_day_owner.png'));
    });

    testWidgets('a member sees the same plan with no edit controls', (tester) async {
      await _pump(tester, const ItineraryOverviewPage(dayIndex: 0), _state(canEdit: false));

      expect(find.text('Sensō-ji'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Add stop'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('^Mark ')), findsNothing);
      await expectLater(find.byType(ItineraryOverviewPage), matchesGoldenFile('goldens/itinerary_day_member.png'));
    });

    testWidgets('a failed save keeps the plan and marks the unsaved stop', (tester) async {
      const failure = ItinerarySaveFailure(edit: ItineraryEdit.addStop, dayIndex: 0, stopIndex: 2);
      await _pump(tester, const ItineraryOverviewPage(dayIndex: 0), _state(canEdit: true, saveFailure: failure));

      expect(find.byType(SaveFailedBanner), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Not saved'), findsOneWidget);
      expect(find.text('Back to the hotel lobby'), findsOneWidget);
      expect(find.text('Sensō-ji'), findsOneWidget);
      await expectLater(find.byType(ItineraryOverviewPage), matchesGoldenFile('goldens/itinerary_day_save_failed.png'));
    });
  });

  group('stop detail page', () {
    testWidgets('only the owner gets an Edit button', (tester) async {
      await _pump(tester, const ItineraryFocusPage(dayIndex: 0, stopIndex: 1), _state(canEdit: true));
      expect(find.text('Temple · Asakusa · Open until 17:00'), findsOneWidget);
      expect(find.text('Meet by the big lantern.'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);

      await _pump(tester, const ItineraryFocusPage(dayIndex: 0, stopIndex: 1), _state(canEdit: false));
      expect(find.text('Sensō-ji'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
    });
  });

  group("Home's itinerary card", () {
    Future<void> pumpPreview(WidgetTester tester, {required bool canEdit}) {
      final state = _state(canEdit: canEdit);
      const trip = TripModel(id: 'trip-1', title: 'Tokyo', memberIds: ['user-1'], createdBy: 'user-1');
      final overview = TripOverview(trip: trip, dailyPlans: state.itinerary.dailyPlans);
      return _pump(
        tester,
        SingleChildScrollView(
          child: ItineraryPreview(state: state, overview: overview),
        ),
        state,
      );
    }

    testWidgets('shows "Edit days" to the owner only', (tester) async {
      await pumpPreview(tester, canEdit: true);
      expect(find.text('Edit days'), findsOneWidget);

      await pumpPreview(tester, canEdit: false);
      expect(find.text('Asakusa and the river'), findsOneWidget);
      expect(find.text('Edit days'), findsNothing);
    });
  });
}
