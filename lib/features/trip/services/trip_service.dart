import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:uuid/uuid.dart';
import 'package:xplore/features/auth/services/auth_service.dart';
import 'package:xplore/features/trip/models/trip_invite.dart';
import 'package:xplore/features/trip/models/trip_model.dart';
import 'package:xplore/features/trip/services/invite_link.dart';
import 'package:xplore/features/trip/services/invite_results.dart';

class TripService {
  TripService({FirebaseFirestore? firestore})
    : _firestore =
          firestore ?? FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: AuthService.appDatabaseId);

  final FirebaseFirestore _firestore;

  static const _uuid = Uuid();

  CollectionReference<Map<String, dynamic>> get _trips => _firestore.collection('trips');

  CollectionReference<Map<String, dynamic>> _invites(String tripId) => _trips.doc(tripId).collection('invites');

  Future<TripModel> createTrip(String title, String uid) async {
    final doc = _trips.doc();
    final data = <String, dynamic>{
      'title': title,
      'memberIds': [uid],
      ..._auditFields(uid, isCreate: true),
    };

    await doc.set(data);

    return TripModel(id: doc.id, title: title, memberIds: [uid], createdBy: uid, lastUpdatedBy: uid);
  }

  Stream<List<TripModel>> fetchTrips(String uid) {
    return _trips.where('memberIds', arrayContains: uid).snapshots().map((snapshot) {
      final trips = snapshot.docs.map(_tripFromDoc).toList();
      trips.sort(_sortNewestFirst);
      return trips;
    });
  }

  Stream<TripModel?> fetchTrip(String tripId) {
    return _trips.doc(tripId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return _tripFromDoc(snapshot);
    });
  }

  /// Creates a fresh invite for [tripId] and returns it alongside the
  /// shareable universal link (see [InviteLink]). The caller ([uid]) must be a
  /// trip member; `tripTitle` / `memberCount` are denormalised from the live
  /// trip so the join screen can preview without a (blocked) trip read.
  ///
  /// [expiresAt] is optional — the FEAT-003 default is no expiry.
  Future<TripInviteHandle> createInvite(String tripId, String uid, {DateTime? expiresAt}) async {
    final tripSnapshot = await _trips.doc(tripId).get();
    if (!tripSnapshot.exists || tripSnapshot.data() == null) {
      throw StateError('Cannot create an invite for a trip that does not exist: $tripId');
    }
    final trip = _tripFromDoc(tripSnapshot);

    final token = _uuid.v4().replaceAll('-', '');
    final inviteRef = _invites(tripId).doc(token);

    await inviteRef.set(<String, dynamic>{
      'token': token,
      'tripId': tripId,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': expiresAt == null ? null : Timestamp.fromDate(expiresAt),
      'revoked': false,
      'tripTitle': trip.title,
      'memberCount': trip.memberIds.length,
    });

    final invite = TripInvite(
      token: token,
      tripId: tripId,
      createdBy: uid,
      expiresAt: expiresAt,
      tripTitle: trip.title,
      memberCount: trip.memberIds.length,
    );

    return TripInviteHandle(
      invite: invite,
      link: InviteLink.build(tripId: tripId, token: token),
    );
  }

  /// Marks an invite as revoked so it can no longer be accepted. Caller must be
  /// a trip member (enforced by rules).
  Future<void> revokeInvite(String tripId, String token) async {
    await _invites(tripId).doc(token).update(<String, dynamic>{'revoked': true});
  }

  /// Fetches an invite for the join-confirmation preview and classifies it as
  /// valid or invalid (not found / revoked / expired). Does not touch the trip
  /// document, so it works for not-yet-members.
  Future<InviteLookup> lookupInvite(String tripId, String token, {DateTime? now}) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await _invites(tripId).doc(token).get();
    } on FirebaseException {
      return const InviteLookup.invalid(InviteFailureReason.unavailable);
    }

    final reason = _validateInvite(snapshot, now: now ?? DateTime.now());
    if (reason != null) {
      return InviteLookup.invalid(reason);
    }

    return InviteLookup.valid(_inviteFromDoc(snapshot));
  }

  /// Adds [uid] to `trips/{tripId}.memberIds` after validating the invite.
  ///
  /// Validation order: invite existence/revoked/expiry first (the invite doc is
  /// readable by token holders), then the member cap. A non-member cannot read
  /// the trip document, so the optional pre-read below is best-effort: in
  /// production it is denied and we fall through to the `arrayUnion` write,
  /// where the `validTripJoin` Firestore rule enforces the cap authoritatively.
  /// In tests (fake Firestore applies no rules) the pre-read runs and yields
  /// precise typed failures.
  Future<InviteAcceptResult> acceptInvite({required String tripId, required String token, required String uid}) async {
    final tripRef = _trips.doc(tripId);

    final DocumentSnapshot<Map<String, dynamic>> inviteSnapshot;
    try {
      inviteSnapshot = await _invites(tripId).doc(token).get();
    } on FirebaseException {
      return const InviteAcceptResult.failed(InviteFailureReason.unavailable);
    }

    final inviteReason = _validateInvite(inviteSnapshot, now: DateTime.now());
    if (inviteReason != null) {
      return InviteAcceptResult.failed(inviteReason);
    }

    // Best-effort pre-check (see doc comment): detect already-a-member and cap.
    try {
      final tripSnapshot = await tripRef.get();
      if (!tripSnapshot.exists || tripSnapshot.data() == null) {
        return const InviteAcceptResult.failed(InviteFailureReason.notFound);
      }
      final trip = _tripFromDoc(tripSnapshot);
      if (trip.memberIds.contains(uid)) {
        return InviteAcceptResult.joined(trip);
      }
      if (trip.memberIds.length >= maxFreeTierTripMembers) {
        return const InviteAcceptResult.failed(InviteFailureReason.tripFull);
      }
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') {
        rethrow;
      }
      // Non-member read denied in production; rules guard the write below.
    }

    try {
      await tripRef.update(<String, dynamic>{
        'memberIds': FieldValue.arrayUnion(<String>[uid]),
        'lastUpdatedBy': uid,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        // Invite was valid, so the most likely cause is the member cap.
        return const InviteAcceptResult.failed(InviteFailureReason.tripFull);
      }
      return const InviteAcceptResult.failed(InviteFailureReason.unavailable);
    }

    // Now a member: the read is permitted and returns the joined trip.
    final joinedSnapshot = await tripRef.get();
    return InviteAcceptResult.joined(_tripFromDoc(joinedSnapshot));
  }

  /// Returns the failure reason for [snapshot], or `null` when the invite is
  /// usable. Centralises the not-found / revoked / expired checks.
  InviteFailureReason? _validateInvite(DocumentSnapshot<Map<String, dynamic>> snapshot, {required DateTime now}) {
    if (!snapshot.exists || snapshot.data() == null) {
      return InviteFailureReason.notFound;
    }
    final invite = _inviteFromDoc(snapshot);
    if (invite.revoked) {
      return InviteFailureReason.revoked;
    }
    if (invite.isExpired(now)) {
      return InviteFailureReason.expired;
    }
    return null;
  }

  TripInvite _inviteFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return TripInvite.fromJson({...doc.data()!, 'token': doc.id});
  }

  TripModel _tripFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return TripModel.fromJson({...doc.data()!, 'id': doc.id});
  }

  Map<String, dynamic> _auditFields(String uid, {required bool isCreate}) {
    final fields = <String, dynamic>{'lastUpdatedBy': uid, 'lastUpdatedAt': FieldValue.serverTimestamp()};

    if (isCreate) {
      fields['createdBy'] = uid;
      fields['createdAt'] = FieldValue.serverTimestamp();
    }

    return fields;
  }

  int _sortNewestFirst(TripModel a, TripModel b) {
    final aCreated = a.createdAt;
    final bCreated = b.createdAt;
    if (aCreated == null && bCreated == null) {
      return 0;
    }
    if (aCreated == null) {
      return -1;
    }
    if (bCreated == null) {
      return 1;
    }
    return bCreated.compareTo(aCreated);
  }
}
