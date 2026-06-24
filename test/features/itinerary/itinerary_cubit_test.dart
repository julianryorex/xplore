// Headless tests for the FEAT-006 itinerary read path (no Firebase / GUI).
//
// They drive `ItineraryCubit` off the global `TripStreamMixin` broadcast (the
// same channel `TripCubit` publishes on) with a `FakeFirebaseFirestore`-backed
// `ItineraryService` and a temp-dir Hive cache, covering: load-by-active-trip,
// real-time updates, lazy-seeding a missing document, the empty state, and the
// offline cache round-trip.

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:xplore/features/itinerary/bloc/itinerary_cubit.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/features/itinerary/repository/itinerary_repository.dart';
import 'package:xplore/features/itinerary/services/itinerary_service.dart';
import 'package:xplore/features/trip/bloc/trip_state.dart';
import 'package:xplore/features/trip/bloc/trip_stream_mixin.dart';
import 'package:xplore/features/trip/models/trip_model.dart';

import '../../helpers/auth_fixtures.dart';

class _TripStreamHarness with TripStreamMixin {}

TripModel _trip(String id, {List<String> memberIds = const ['user-1']}) {
  return TripModel(id: id, title: 'Trip $id', memberIds: memberIds, createdBy: memberIds.first);
}

Map<String, dynamic> _dayPlan({required String title}) {
  return {
    'title': title,
    'location': 'Tokyo',
    'plan': {
      'favorited': <String>[],
      'locations': [
        {'name': 'Tsukiji Fish Market', 'completed': true, 'place_id': 'place-1', 'description': 'Sushi.'},
      ],
    },
  };
}

Future<T> _waitFor<T extends ItineraryStates>(ItineraryCubit cubit, {bool Function(T state)? where}) {
  return cubit.stream
      .firstWhere((state) => state is T && (where == null || where(state)))
      .timeout(const Duration(seconds: 2))
      .then((state) => state as T);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late FakeFirebaseFirestore firestore;
  late ItineraryService service;

  setUp(() {
    _TripStreamHarness().recreateTripStream();
    tempDir = Directory.systemTemp.createTempSync('xplore_itinerary_test');
    Hive.init(tempDir.path);
    firestore = FakeFirebaseFirestore();
    service = ItineraryService(firestore: firestore);
  });

  tearDown(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  ItineraryCubit buildCubit({MockUser? user}) {
    final cubit = ItineraryCubit(service, fakeAuthService(signedIn: user != null, user: user), ItineraryRepository());
    addTearDown(cubit.close);
    return cubit;
  }

  group('ItineraryCubit', () {
    test('loads the cloud itinerary for the active trip and caches it', () async {
      await firestore.collection('itineraries').doc('trip-1').set({
        'invitees': ['user-1'],
        'daily_plans': [_dayPlan(title: 'SkyTree Day')],
        'pins': <dynamic>[],
        'last_updated': Timestamp.fromDate(DateTime.utc(2023, 6, 15, 8, 30)),
      });

      final cubit = buildCubit(user: MockUser(uid: 'user-1'));
      final loaded = _waitFor<LoadedItineraryState>(cubit);

      _TripStreamHarness().pushTripEvent(TripState.loaded(active: _trip('trip-1'), all: [_trip('trip-1')]));

      final itinerary = (await loaded).itinerary;
      expect(itinerary.id, 'trip-1');
      expect(itinerary.dailyPlans.single.title, 'SkyTree Day');

      // Cache was populated for offline reads.
      final cached = await ItineraryRepository().loadFromCache('trip-1');
      expect(cached?.dailyPlans.single.title, 'SkyTree Day');
    });

    test('reflects real-time updates to the active itinerary', () async {
      final doc = firestore.collection('itineraries').doc('trip-1');
      await doc.set({
        'invitees': ['user-1'],
        'daily_plans': [_dayPlan(title: 'SkyTree Day')],
        'pins': <dynamic>[],
        'last_updated': Timestamp.fromDate(DateTime.utc(2023, 6, 15, 8, 30)),
      });

      final cubit = buildCubit(user: MockUser(uid: 'user-1'));
      final firstLoad = _waitFor<LoadedItineraryState>(cubit);
      _TripStreamHarness().pushTripEvent(TripState.loaded(active: _trip('trip-1'), all: [_trip('trip-1')]));
      await firstLoad;

      final updated = _waitFor<LoadedItineraryState>(cubit, where: (s) => s.itinerary.dailyPlans.length == 2);
      await doc.update({
        'daily_plans': [_dayPlan(title: 'SkyTree Day'), _dayPlan(title: 'Shinjuku Day')],
      });

      expect((await updated).itinerary.dailyPlans.map((d) => d.title), ['SkyTree Day', 'Shinjuku Day']);
    });

    test('lazily seeds a starter itinerary when the document is missing', () async {
      final cubit = buildCubit(user: MockUser(uid: 'user-1'));
      final loaded = _waitFor<LoadedItineraryState>(cubit);

      _TripStreamHarness().pushTripEvent(TripState.loaded(active: _trip('trip-2'), all: [_trip('trip-2')]));

      expect((await loaded).itinerary.dailyPlans, isEmpty);

      final seeded = await firestore.collection('itineraries').doc('trip-2').get();
      expect(seeded.exists, isTrue);
      expect(seeded.data()!['invitees'], ['user-1']);
      expect(seeded.data()!['daily_plans'], isEmpty);
    });

    test('emits empty when the active trip clears', () async {
      final cubit = buildCubit(user: MockUser(uid: 'user-1'));
      final empty = _waitFor<EmptyItineraryState>(cubit);

      _TripStreamHarness().pushTripEvent(const TripState.empty());

      await empty;
      expect(cubit.state, isA<EmptyItineraryState>());
    });

    test('retry forces a fresh load for the active trip', () async {
      await firestore.collection('itineraries').doc('trip-1').set({
        'invitees': ['user-1'],
        'daily_plans': [_dayPlan(title: 'SkyTree Day')],
        'pins': <dynamic>[],
        'last_updated': Timestamp.fromDate(DateTime.utc(2023, 6, 15, 8, 30)),
      });

      final cubit = buildCubit(user: MockUser(uid: 'user-1'));
      final firstLoad = _waitFor<LoadedItineraryState>(cubit);
      _TripStreamHarness().pushTripEvent(TripState.loaded(active: _trip('trip-1'), all: [_trip('trip-1')]));
      await firstLoad;

      final reloading = _waitFor<LoadingItineraryState>(cubit);
      final reloaded = _waitFor<LoadedItineraryState>(cubit);
      await cubit.retry();

      await reloading;
      expect((await reloaded).itinerary.id, 'trip-1');
    });

    test('retry is a no-op when no trip is active', () async {
      final cubit = buildCubit(user: MockUser(uid: 'user-1'));

      await cubit.retry();

      expect(cubit.state, isA<InitialItineraryState>());
    });

    test('offline cache round-trips an itinerary through Hive', () async {
      const itinerary = ItineraryModel(id: 'trip-3', invitees: ['user-1'], dailyPlans: [], pins: [], lastUpdated: null);

      await ItineraryRepository().cacheItinerary('trip-3', itinerary);

      final loaded = await ItineraryRepository().loadFromCache('trip-3');
      expect(loaded?.id, 'trip-3');
      expect(loaded?.invitees, ['user-1']);
    });
  });
}
