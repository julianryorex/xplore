import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/auth/services/auth_service.dart';
import 'package:xplore/features/trip/bloc/trip_cubit.dart';
import 'package:xplore/features/trip/bloc/trip_state.dart';
import 'package:xplore/features/trip/bloc/trip_stream_mixin.dart';
import 'package:xplore/features/trip/services/trip_service.dart';

class _ControllableAuthService extends AuthService {
  _ControllableAuthService({User? initialUser})
    : _user = initialUser,
      super(firebaseAuth: MockFirebaseAuth(), firestore: FakeFirebaseFirestore());

  final StreamController<User?> _controller = StreamController<User?>.broadcast();
  User? _user;

  void emitUser(User? user) {
    _user = user;
    _controller.add(user);
  }

  @override
  Stream<User?> authStateChanges() => _controller.stream;

  @override
  User? get currentUser => _user;

  @override
  String? get currentUid => _user?.uid;

  Future<void> dispose() => _controller.close();
}

class _TripStreamHarness with TripStreamMixin {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _TripStreamHarness().recreateTripStream();
  });

  group('TripCubit', () {
    test('creates a trip and marks it active from the trips stream', () async {
      final firestore = FakeFirebaseFirestore();
      final user = MockUser(uid: 'user-1');
      final authService = _ControllableAuthService(initialUser: user);
      final cubit = TripCubit(TripService(firestore: firestore), authService);

      authService.emitUser(user);
      await pumpEventQueue();

      await cubit.createTrip('Tokyo 2026');
      await pumpEventQueue();

      expect(cubit.state, isA<TripLoaded>());
      final state = cubit.state as TripLoaded;
      expect(state.active.title, 'Tokyo 2026');
      expect(state.active.memberIds, ['user-1']);
      expect(cubit.activeTripId, state.active.id);

      await cubit.close();
      await authService.dispose();
    });

    test('emits empty when an authenticated user has no trips', () async {
      final user = MockUser(uid: 'user-1');
      final authService = _ControllableAuthService(initialUser: user);
      final cubit = TripCubit(TripService(firestore: FakeFirebaseFirestore()), authService);

      authService.emitUser(user);
      await pumpEventQueue();

      expect(cubit.state, isA<TripEmpty>());

      await cubit.close();
      await authService.dispose();
    });

    test('fails fast when creating a trip while unauthenticated', () async {
      final firestore = FakeFirebaseFirestore();
      final authService = _ControllableAuthService();
      final cubit = TripCubit(TripService(firestore: firestore), authService);

      await expectLater(cubit.createTrip('Tokyo 2026'), throwsA(isA<StateError>()));

      final trips = await firestore.collection('trips').get();
      expect(trips.docs, isEmpty);

      await cubit.close();
      await authService.dispose();
    });

    test('loads trips when auth changes from signed out to signed in', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('trips').doc('trip-1').set({
        'title': 'Kyoto',
        'memberIds': ['user-1'],
        'createdBy': 'user-1',
        'lastUpdatedBy': 'user-1',
      });
      final user = MockUser(uid: 'user-1');
      final authService = _ControllableAuthService();
      final cubit = TripCubit(TripService(firestore: firestore), authService);

      authService.emitUser(user);
      await pumpEventQueue();

      expect(cubit.state, isA<TripLoaded>());
      expect((cubit.state as TripLoaded).active.id, 'trip-1');

      await cubit.close();
      await authService.dispose();
    });

    test('clears state on sign-out and ignores old user trip updates', () async {
      final firestore = FakeFirebaseFirestore();
      final user = MockUser(uid: 'user-1');
      final authService = _ControllableAuthService(initialUser: user);
      final cubit = TripCubit(TripService(firestore: firestore), authService);

      authService.emitUser(user);
      await pumpEventQueue();
      await cubit.createTrip('Tokyo 2026');
      await pumpEventQueue();
      expect(cubit.state, isA<TripLoaded>());

      authService.emitUser(null);
      await pumpEventQueue();
      expect(cubit.state, isA<TripEmpty>());

      await firestore.collection('trips').doc('trip-2').set({
        'title': 'Osaka',
        'memberIds': ['user-1'],
        'createdBy': 'user-1',
        'lastUpdatedBy': 'user-1',
      });
      await pumpEventQueue();

      expect(cubit.state, isA<TripEmpty>());

      await cubit.close();
      await authService.dispose();
    });

    test('broadcasts loaded trip state through TripStreamMixin', () async {
      final firestore = FakeFirebaseFirestore();
      final user = MockUser(uid: 'user-1');
      final authService = _ControllableAuthService(initialUser: user);
      final cubit = TripCubit(TripService(firestore: firestore), authService);
      final received = Completer<TripState>();
      final subscription = cubit.listenToTripState((state) {
        if (state is TripLoaded && !received.isCompleted) {
          received.complete(state);
        }
      });

      authService.emitUser(user);
      await pumpEventQueue();
      await cubit.createTrip('Tokyo 2026');

      final state = await received.future.timeout(const Duration(seconds: 1));
      expect((state as TripLoaded).active.title, 'Tokyo 2026');

      await subscription.cancel();
      await cubit.close();
      await authService.dispose();
    });
  });
}
