import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/trip/services/invite_results.dart';
import 'package:xplore/features/trip/services/trip_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore firestore;
  late TripService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = TripService(firestore: firestore);
  });

  Future<String> seedTrip({required String owner, List<String> extraMembers = const []}) async {
    final doc = firestore.collection('trips').doc();
    await doc.set(<String, dynamic>{
      'title': 'Tokyo 2026',
      'memberIds': [owner, ...extraMembers],
      'createdBy': owner,
      'lastUpdatedBy': owner,
      'createdAt': Timestamp.now(),
      'lastUpdatedAt': Timestamp.now(),
    });
    return doc.id;
  }

  group('createInvite', () {
    test('writes an invite doc and returns a shareable link', () async {
      final tripId = await seedTrip(owner: 'owner-1');

      final handle = await service.createInvite(tripId, 'owner-1');

      expect(handle.invite.tripId, tripId);
      expect(handle.invite.createdBy, 'owner-1');
      expect(handle.invite.revoked, isFalse);
      expect(handle.invite.tripTitle, 'Tokyo 2026');
      expect(handle.invite.memberCount, 1);
      expect(handle.link, contains('trip=$tripId'));
      expect(handle.link, contains('token=${handle.invite.token}'));

      final stored = await firestore
          .collection('trips')
          .doc(tripId)
          .collection('invites')
          .doc(handle.invite.token)
          .get();
      expect(stored.exists, isTrue);
      expect(stored.data()!['revoked'], false);
    });

    test('throws when the trip does not exist', () async {
      expect(service.createInvite('missing-trip', 'owner-1'), throwsStateError);
    });
  });

  group('lookupInvite', () {
    test('returns valid for a fresh invite', () async {
      final tripId = await seedTrip(owner: 'owner-1');
      final handle = await service.createInvite(tripId, 'owner-1');

      final lookup = await service.lookupInvite(tripId, handle.invite.token);

      expect(lookup, isA<InviteLookupValid>());
      expect((lookup as InviteLookupValid).invite.tripTitle, 'Tokyo 2026');
    });

    test('returns notFound for an unknown token', () async {
      final tripId = await seedTrip(owner: 'owner-1');

      final lookup = await service.lookupInvite(tripId, 'nope');

      expect(lookup, isA<InviteLookupInvalid>());
      expect((lookup as InviteLookupInvalid).reason, InviteFailureReason.notFound);
    });

    test('returns revoked once the invite is revoked', () async {
      final tripId = await seedTrip(owner: 'owner-1');
      final handle = await service.createInvite(tripId, 'owner-1');
      await service.revokeInvite(tripId, handle.invite.token);

      final lookup = await service.lookupInvite(tripId, handle.invite.token);

      expect((lookup as InviteLookupInvalid).reason, InviteFailureReason.revoked);
    });

    test('returns expired for a past expiry', () async {
      final tripId = await seedTrip(owner: 'owner-1');
      final handle = await service.createInvite(
        tripId,
        'owner-1',
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
      );

      final lookup = await service.lookupInvite(tripId, handle.invite.token);

      expect((lookup as InviteLookupInvalid).reason, InviteFailureReason.expired);
    });
  });

  group('acceptInvite', () {
    test('adds the user to memberIds and returns the joined trip', () async {
      final tripId = await seedTrip(owner: 'owner-1');
      final handle = await service.createInvite(tripId, 'owner-1');

      final result = await service.acceptInvite(tripId: tripId, token: handle.invite.token, uid: 'joiner-1');

      expect(result, isA<InviteJoined>());
      expect((result as InviteJoined).trip.memberIds, containsAll(['owner-1', 'joiner-1']));

      final stored = await firestore.collection('trips').doc(tripId).get();
      expect(List<String>.from(stored.data()!['memberIds']), containsAll(['owner-1', 'joiner-1']));
    });

    test('is idempotent for an existing member', () async {
      final tripId = await seedTrip(owner: 'owner-1');
      final handle = await service.createInvite(tripId, 'owner-1');

      final result = await service.acceptInvite(tripId: tripId, token: handle.invite.token, uid: 'owner-1');

      expect(result, isA<InviteJoined>());
      final trip = (result as InviteJoined).trip;
      expect(trip.memberIds.where((id) => id == 'owner-1').length, 1);
    });

    test('rejects a revoked invite', () async {
      final tripId = await seedTrip(owner: 'owner-1');
      final handle = await service.createInvite(tripId, 'owner-1');
      await service.revokeInvite(tripId, handle.invite.token);

      final result = await service.acceptInvite(tripId: tripId, token: handle.invite.token, uid: 'joiner-1');

      expect((result as InviteJoinFailed).reason, InviteFailureReason.revoked);
    });

    test('rejects an expired invite', () async {
      final tripId = await seedTrip(owner: 'owner-1');
      final handle = await service.createInvite(
        tripId,
        'owner-1',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );

      final result = await service.acceptInvite(tripId: tripId, token: handle.invite.token, uid: 'joiner-1');

      expect((result as InviteJoinFailed).reason, InviteFailureReason.expired);
    });

    test('rejects an unknown token', () async {
      final tripId = await seedTrip(owner: 'owner-1');

      final result = await service.acceptInvite(tripId: tripId, token: 'nope', uid: 'joiner-1');

      expect((result as InviteJoinFailed).reason, InviteFailureReason.notFound);
    });

    test('enforces the free-tier member cap', () async {
      // Trip already at the 6-member cap.
      final tripId = await seedTrip(owner: 'owner-1', extraMembers: ['m2', 'm3', 'm4', 'm5', 'm6']);
      final handle = await service.createInvite(tripId, 'owner-1');

      final result = await service.acceptInvite(tripId: tripId, token: handle.invite.token, uid: 'joiner-7');

      expect((result as InviteJoinFailed).reason, InviteFailureReason.tripFull);

      final stored = await firestore.collection('trips').doc(tripId).get();
      expect(List<String>.from(stored.data()!['memberIds']).length, maxFreeTierTripMembers);
    });

    test('allows joining up to exactly the cap', () async {
      final tripId = await seedTrip(owner: 'owner-1', extraMembers: ['m2', 'm3', 'm4', 'm5']);
      final handle = await service.createInvite(tripId, 'owner-1');

      final result = await service.acceptInvite(tripId: tripId, token: handle.invite.token, uid: 'joiner-6');

      expect(result, isA<InviteJoined>());
      expect((result as InviteJoined).trip.memberIds.length, maxFreeTierTripMembers);
    });
  });
}
