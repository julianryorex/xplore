import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/auth/bloc/auth_cubit.dart';
import 'package:xplore/features/onboarding/bloc/onboarding_cubit.dart';
import 'package:xplore/features/onboarding/presentation/steps/all_set_step.dart';
import 'package:xplore/features/trip/data/place_catalog.dart';
import 'package:xplore/features/trip/services/trip_service.dart';

import '../../helpers/auth_fixtures.dart';
import '../../helpers/pump_app.dart';

void main() {
  final today = DateTime(2026, 5, 20);
  late OnboardingCubit onboarding;
  late AuthCubit auth;

  setUp(() {
    onboarding = OnboardingCubit(TripService(firestore: FakeFirebaseFirestore()), clock: () => today)
      ..startOrganizer()
      ..setDestination(placeCatalog.byId('lisbon') ?? placeCatalog.places.first);
    auth = AuthCubit(
      fakeAuthService(
        signedIn: true,
        user: MockUser(uid: 'organizer', displayName: 'Maya Lopes'),
      ),
    );
  });

  tearDown(() async {
    await onboarding.close();
    await auth.close();
  });

  Future<void> pumpStep(WidgetTester tester, {Size size = const Size(390, 844)}) async {
    while (onboarding.state.step != OnboardingStep.allSet) {
      onboarding.next();
    }
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrapApp(
        AllSetStep(clock: () => today),
        providers: [
          BlocProvider<OnboardingCubit>.value(value: onboarding),
          BlocProvider<AuthCubit>.value(value: auth),
        ],
      ),
    );
    // Lets the entrance finish; not pumpAndSettle, as the pin's halo pulses for as long as the step shows.
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('an upcoming trip counts down to its first day and says when location sharing starts', (tester) async {
    onboarding.setDates(DateTime(2026, 6, 3), DateTime(2026, 6, 9));
    await pumpStep(tester);

    final place = onboarding.state.destination!.name;
    expect(find.text('See you in $place, Maya.'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.text('days to go'), findsOneWidget);
    expect(find.text('Jun 3 – 9 · 7 days'), findsOneWidget);
    expect(find.text('Location sharing starts Jun 3'), findsOneWidget);
  });

  testWidgets('a trip without dates says so and keeps location off, without overflowing a small phone', (tester) async {
    await pumpStep(tester, size: const Size(375, 667));

    expect(find.text('No dates yet'), findsOneWidget);
    expect(find.text('Location stays off until you set dates'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Open {place}" completes onboarding', (tester) async {
    await pumpStep(tester);

    await tester.tap(find.text('Open ${onboarding.state.destination!.name}'));
    await tester.pump();

    expect(onboarding.state.completed, isTrue);
  });
}
