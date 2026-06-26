import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/auth/services/auth_service.dart';
import 'package:xplore/features/trip/bloc/join_trip_cubit.dart';
import 'package:xplore/features/trip/bloc/join_trip_state.dart';
import 'package:xplore/features/trip/services/invite_results.dart';
import 'package:xplore/features/trip/services/trip_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore firestore;
  late TripService tripService;
  late AuthService authService;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    tripService = TripService(firestore: firestore);
    authService = AuthService(
      firebaseAuth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'joiner-1')),
      firestore: FakeFirebaseFirestore(),
    );
  });

  Future<String> seedTrip({List<String> members = const ['owner-1']}) async {
    final doc = firestore.collection('trips').doc();
    await doc.set(<String, dynamic>{
      'title': 'Tokyo 2026',
      'memberIds': members,
      'createdBy': members.first,
      'lastUpdatedBy': members.first,
      'createdAt': Timestamp.now(),
      'lastUpdatedAt': Timestamp.now(),
    });
    return doc.id;
  }

  JoinTripCubit cubitFor(String tripId, String token) =>
      JoinTripCubit(tripService, authService, tripId: tripId, token: token);

  test('loadPreview emits ready for a valid invite', () async {
    final tripId = await seedTrip();
    final handle = await tripService.createInvite(tripId, 'owner-1');
    final cubit = cubitFor(tripId, handle.invite.token);

    await cubit.loadPreview();

    expect(cubit.state, isA<JoinTripReady>());
    expect((cubit.state as JoinTripReady).invite.tripTitle, 'Tokyo 2026');

    await cubit.close();
  });

  test('loadPreview emits invalid for a revoked invite', () async {
    final tripId = await seedTrip();
    final handle = await tripService.createInvite(tripId, 'owner-1');
    await tripService.revokeInvite(tripId, handle.invite.token);
    final cubit = cubitFor(tripId, handle.invite.token);

    await cubit.loadPreview();

    expect((cubit.state as JoinTripInvalid).reason, InviteFailureReason.revoked);

    await cubit.close();
  });

  test('join emits joined and adds the user to the trip', () async {
    final tripId = await seedTrip();
    final handle = await tripService.createInvite(tripId, 'owner-1');
    final cubit = cubitFor(tripId, handle.invite.token);

    await cubit.loadPreview();
    await cubit.join();

    expect(cubit.state, isA<JoinTripJoined>());
    expect((cubit.state as JoinTripJoined).trip.memberIds, containsAll(['owner-1', 'joiner-1']));

    await cubit.close();
  });

  test('join surfaces the cap as an invalid state', () async {
    final tripId = await seedTrip(members: ['owner-1', 'm2', 'm3', 'm4', 'm5', 'm6']);
    final handle = await tripService.createInvite(tripId, 'owner-1');
    final cubit = cubitFor(tripId, handle.invite.token);

    await cubit.loadPreview();
    await cubit.join();

    expect((cubit.state as JoinTripInvalid).reason, InviteFailureReason.tripFull);

    await cubit.close();
  });
}
