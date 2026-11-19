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
import 'package:hive_ce/hive.dart';
import 'package:xplore/features/itinerary/bloc/itinerary_cubit.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/features/itinerary/repository/itinerary_repository.dart';
import 'package:xplore/features/itinerary/services/itinerary_service.dart';
import 'package:xplore/features/trip/bloc/trip_state.dart';
import 'package:xplore/features/trip/bloc/trip_stream_mixin.dart';
import 'package:xplore/features/trip/models/trip_model.dart';

import '../../helpers/auth_fixtures.dart';

class _TripStreamHarness with TripStreamMixin {}

/// Records every listen and lets each test script what the n-th listen (1-based, per trip) returns.
class _ScriptedItineraryService extends ItineraryService {
  _ScriptedItineraryService(FakeFirebaseFirestore firestore, this._onListen) : super(firestore: firestore);

  final Stream<ItineraryModel?> Function(String tripId, int listen) _onListen;
  final listens = <String>[];

  @override
  Stream<ItineraryModel?> watchItinerary(String tripId) {
    listens.add(tripId);
    return _onListen(tripId, listens.where((id) => id == tripId).length);
  }
}

/// What Firestore raises for a trip the server has not committed yet.
FirebaseException _denied() => FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');

Future<void> _seedItinerary(FakeFirebaseFirestore firestore, String tripId) {
  return firestore.collection('itineraries').doc(tripId).set({
    'invitees': ['user-1'],
    'daily_plans': [_dayPlan(title: 'Day of $tripId')],
    'pins': <dynamic>[],
    'last_updated': Timestamp.fromDate(DateTime.utc(2023, 6, 15, 8, 30)),
  });
}

void _activate(String tripId) {
  _TripStreamHarness().pushTripEvent(TripState.loaded(active: _trip(tripId), all: [_trip(tripId)]));
}

TripModel _trip(String id, {List<String> memberIds = const ['user-1']}) {
  return TripModel(id: id, title: 'Trip $id', memberIds: memberIds, createdBy: memberIds.first);
}

Map<String, dynamic> _dayPlan({required String title, bool completed = true}) {
  return {
    'title': title,
    'location': 'Tokyo',
    'plan': {
      'favorited': <String>[],
      'locations': [
        {'name': 'Tsukiji Fish Market', 'completed': completed, 'place_id': 'place-1', 'description': 'Sushi.'},
      ],
    },
  };
}

bool _firstStopCompleted(DocumentSnapshot<Map<String, dynamic>> snap) {
  final locations = ((snap.data()!['daily_plans'] as List).first as Map)['plan']['locations'] as List;
  return (locations.first as Map)['completed'] as bool;
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

    group('auto retry', () {
      ItineraryCubit buildScriptedCubit(ItineraryService scripted, {Duration backoff = Duration.zero}) {
        final cubit = ItineraryCubit(scripted, fakeAuthService(), ItineraryRepository(), backoff);
        addTearDown(cubit.close);
        return cubit;
      }

      test('a listen denied while the trip is still being committed is retried', () async {
        await _seedItinerary(firestore, 'trip-1');
        final flaky = _ScriptedItineraryService(
          firestore,
          (tripId, listen) => listen == 1 ? Stream.error(_denied()) : service.watchItinerary(tripId),
        );
        final cubit = buildScriptedCubit(flaky);
        final states = <ItineraryStates>[];
        final subscription = cubit.stream.listen(states.add);
        addTearDown(subscription.cancel);
        final loaded = _waitFor<LoadedItineraryState>(cubit);

        _activate('trip-1');

        expect((await loaded).itinerary.dailyPlans.single.title, 'Day of trip-1');
        expect(flaky.listens, ['trip-1', 'trip-1']);
        expect(states.whereType<ErrorItineraryState>(), isEmpty);
      });

      test('a cached snapshot before each denial does not refill the retry budget', () async {
        const cachedCopy = ItineraryModel(id: 'trip-1', invitees: [], dailyPlans: [], pins: [], lastUpdated: null);
        final denied = _ScriptedItineraryService(
          firestore,
          (_, _) => Stream.multi((controller) {
            controller
              ..add(cachedCopy)
              ..addError(_denied());
          }),
        );
        final cubit = buildScriptedCubit(denied);
        final states = <ItineraryStates>[];
        final subscription = cubit.stream.listen(states.add);
        addTearDown(subscription.cancel);
        final error = _waitFor<ErrorItineraryState>(cubit);

        _activate('trip-1');
        await error;
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(denied.listens, hasLength(3));
        // The shown cached copy is not replaced by Loading on an auto retry.
        expect(states.skipWhile((s) => s is! LoadedItineraryState).whereType<LoadingItineraryState>(), isEmpty);
      });

      test('a non-transient error surfaces at once without retrying', () async {
        final broken = _ScriptedItineraryService(
          firestore,
          (_, _) => Stream.error(FirebaseException(plugin: 'cloud_firestore', code: 'failed-precondition')),
        );
        final cubit = buildScriptedCubit(broken);
        final error = _waitFor<ErrorItineraryState>(cubit);

        _activate('trip-1');
        await error;
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(broken.listens, ['trip-1']);
      });

      test('switching trips during the backoff cancels the pending retry', () async {
        await _seedItinerary(firestore, 'trip-a');
        await _seedItinerary(firestore, 'trip-b');
        final scripted = _ScriptedItineraryService(firestore, (tripId, listen) {
          final deniedFirstListen = tripId == 'trip-a' && listen == 1;
          return deniedFirstListen ? Stream.error(_denied()) : service.watchItinerary(tripId);
        });
        final cubit = buildScriptedCubit(scripted, backoff: const Duration(milliseconds: 100));

        _activate('trip-a');
        await Future<void>.delayed(const Duration(milliseconds: 20));
        final loadedB = _waitFor<LoadedItineraryState>(cubit, where: (s) => s.itinerary.id == 'trip-b');
        _activate('trip-b');
        await loadedB;
        final loadedA = _waitFor<LoadedItineraryState>(cubit, where: (s) => s.itinerary.id == 'trip-a');
        _activate('trip-a');
        await loadedA;

        final states = <ItineraryStates>[];
        final subscription = cubit.stream.listen(states.add);
        addTearDown(subscription.cancel);
        await Future<void>.delayed(const Duration(milliseconds: 200));

        expect(scripted.listens, ['trip-a', 'trip-b', 'trip-a']);
        expect(states, isEmpty);
        expect((cubit.state as LoadedItineraryState).itinerary.id, 'trip-a');
      });

      test('closing during the backoff stops the pending retry', () async {
        final denied = _ScriptedItineraryService(firestore, (_, _) => Stream.error(_denied()));
        final cubit = buildScriptedCubit(denied, backoff: const Duration(milliseconds: 50));

        _activate('trip-1');
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await cubit.close();
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(denied.listens, ['trip-1']);
        expect(cubit.state, isA<LoadingItineraryState>());
      });
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

  group('ItineraryCubit editing (owner-only)', () {
    Future<DocumentReference<Map<String, dynamic>>> seedIncompleteTrip() async {
      final doc = firestore.collection('itineraries').doc('trip-1');
      await doc.set({
        'invitees': ['user-1'],
        'daily_plans': [_dayPlan(title: 'SkyTree Day', completed: false)],
        'pins': <dynamic>[],
        'last_updated': Timestamp.fromDate(DateTime.utc(2023, 6, 15, 8, 30)),
      });
      return doc;
    }

    test('the trip owner can toggle a stop; it persists and echoes back', () async {
      final doc = await seedIncompleteTrip();

      final cubit = buildCubit(user: MockUser(uid: 'user-1'));
      final loaded = _waitFor<LoadedItineraryState>(cubit);
      // _trip()'s createdBy defaults to memberIds.first ('user-1') — the owner.
      _TripStreamHarness().pushTripEvent(TripState.loaded(active: _trip('trip-1'), all: [_trip('trip-1')]));
      final loadedState = await loaded;

      expect(loadedState.canEdit, isTrue);
      expect(loadedState.itinerary.dailyPlans.first.plan.locations.first.completed, isFalse);

      final toggled = _waitFor<LoadedItineraryState>(
        cubit,
        where: (s) => s.itinerary.dailyPlans.first.plan.locations.first.completed,
      );
      await cubit.toggleLocationCompleted(0, 0);
      await toggled;

      expect(_firstStopCompleted(await doc.get()), isTrue);
    });

    test('a non-owner member cannot edit: canEdit is false and toggle is a no-op', () async {
      final doc = await seedIncompleteTrip();

      final cubit = buildCubit(user: MockUser(uid: 'user-1'));
      final loaded = _waitFor<LoadedItineraryState>(cubit);
      // Trip owned by user-2; user-1 is a member but not the owner.
      final trip = _trip('trip-1', memberIds: ['user-2', 'user-1']);
      _TripStreamHarness().pushTripEvent(TripState.loaded(active: trip, all: [trip]));
      final loadedState = await loaded;

      expect(loadedState.canEdit, isFalse);

      await cubit.toggleLocationCompleted(0, 0);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(_firstStopCompleted(await doc.get()), isFalse);
    });

    test('toggle is a no-op for an out-of-range index', () async {
      final doc = await seedIncompleteTrip();

      final cubit = buildCubit(user: MockUser(uid: 'user-1'));
      final loaded = _waitFor<LoadedItineraryState>(cubit);
      _TripStreamHarness().pushTripEvent(TripState.loaded(active: _trip('trip-1'), all: [_trip('trip-1')]));
      await loaded;

      await cubit.toggleLocationCompleted(5, 0);
      await cubit.toggleLocationCompleted(0, 9);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(_firstStopCompleted(await doc.get()), isFalse);
    });
  });
}
