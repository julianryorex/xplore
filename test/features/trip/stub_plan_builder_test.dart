import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/home/models/trip_overview.dart';
import 'package:xplore/features/trip/data/place_catalog.dart';
import 'package:xplore/features/trip/models/nights_allocation.dart';
import 'package:xplore/features/trip/models/trip_draft.dart';
import 'package:xplore/features/trip/models/trip_model.dart';
import 'package:xplore/features/trip/models/trip_stop.dart';
import 'package:xplore/features/trip/services/stub_plan_builder.dart';

TripStop _stop(String id, {int nights = 1}) => placeCatalog.byId(id)!.toStop(nights: nights);

void main() {
  test('gives each stop a day per night and the last stop the departure day', () {
    final draft = TripDraft(stops: [_stop('tokyo', nights: 3), _stop('hakone', nights: 1), _stop('kyoto', nights: 2)]);
    final plan = buildStubPlan(draft);

    expect(plan.days, hasLength(7)); // 6 nights + 1
    expect(plan.days.map((day) => day.location), ['Tokyo', 'Tokyo', 'Tokyo', 'Hakone', 'Kyoto', 'Kyoto', 'Kyoto']);
    expect(plan.stops.map((group) => group.dayIndexes), [
      [0, 1, 2],
      [3],
      [4, 5, 6],
    ]);
    expect(plan.stops.map((group) => group.nights), [3, 1, 2]);
    expect(plan.stops.every((group) => group.stay == null), isTrue);
  });

  test('a single-place day trip has one day', () {
    final day = DateTime(2026, 5, 2);
    final draft = TripDraft(
      stops: [_stop('kamakura', nights: 0)],
      datesAreFlexible: false,
      startDate: day,
      endDate: day,
    );
    final plan = buildStubPlan(draft);

    expect(plan.days, hasLength(1));
    expect(plan.stops.single.dayIndexes, [0]);
    expect(plan.stops.single.stay, StayRange(start: day, end: day));
  });

  test('titles cycle through the place themes and fall back for unknown places', () {
    final themes = placeCatalog.byId('hakone')!.dayThemes;
    const custom = TripStop(id: 'custom:atlantis', name: 'Atlantis', country: '', latitude: 0, longitude: 0);
    final draft = TripDraft(
      stops: [
        _stop('hakone', nights: themes.length + 1),
        custom,
      ],
    );
    final plan = buildStubPlan(draft);

    expect(plan.days.first.title, themes.first);
    expect(plan.days[themes.length].title, themes.first);
    expect(plan.days.last.title, 'Exploring Atlantis');
  });

  test('exact-date groups carry their stay dates', () {
    final draft = TripDraft(
      stops: [_stop('lisbon', nights: 2), _stop('porto', nights: 3)],
      datesAreFlexible: false,
      startDate: DateTime(2026, 9, 1),
      endDate: DateTime(2026, 9, 6),
    );
    final plan = buildStubPlan(draft);

    expect(plan.stops[1].stay, StayRange(start: DateTime(2026, 9, 3), end: DateTime(2026, 9, 6)));
  });

  test('stub days stay unplanned so the home does not claim stops', () {
    final plan = buildStubPlan(TripDraft(stops: [_stop('tokyo', nights: 2)]));
    final overview = TripOverview(
      trip: const TripModel(id: 't', title: 'Tokyo', memberIds: ['u'], createdBy: 'u'),
      dailyPlans: plan.days,
    );

    expect(plan.days.every((day) => day.plan.locations.isEmpty), isTrue);
    expect(overview.plannedDays, 0);
    expect(overview.openDays, 3);
  });
}
