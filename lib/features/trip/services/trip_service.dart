import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:xplore/features/auth/services/auth_service.dart';
import 'package:xplore/features/trip/models/trip_model.dart';

class TripService {
  TripService({FirebaseFirestore? firestore})
    : _firestore =
          firestore ?? FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: AuthService.appDatabaseId);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _trips => _firestore.collection('trips');

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
