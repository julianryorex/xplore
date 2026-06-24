import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/auth/services/auth_service.dart';
import 'package:xplore/features/location/bloc/location_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    dotenv.loadFromString(
      mergeWith: {'DISABLE_REALTIME_LOCATIONS': 'true'},
      isOptional: true,
    );
  });

  tearDown(dotenv.clean);

  test('close() completes when realtime updates are disabled', () async {
    // Unauthenticated auth service so the eager updateMyLocation() short-circuits
    // before touching Geolocator/Firebase Database.
    final service = AuthService(
      firebaseAuth: MockFirebaseAuth(signedIn: false),
      firestore: FakeFirebaseFirestore(),
    );

    final cubit = LocationCubit(service);

    // With realtime disabled the timer is never started; close() must not throw
    // a LateInitializationError cancelling an uninitialized timer.
    await expectLater(cubit.close(), completes);
  });
}
