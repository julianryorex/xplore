import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/auth/bloc/auth_cubit.dart';
import 'package:xplore/features/onboarding/bloc/onboarding_cubit.dart';
import 'package:xplore/features/onboarding/presentation/steps/invite_step.dart';
import 'package:xplore/features/trip/data/place_catalog.dart';
import 'package:xplore/features/trip/services/trip_service.dart';

import '../../helpers/auth_fixtures.dart';
import '../../helpers/pump_app.dart';

void main() {
  late OnboardingCubit onboarding;
  late AuthCubit auth;

  setUp(() {
    onboarding = OnboardingCubit(TripService(firestore: FakeFirebaseFirestore()))
      ..startOrganizer()
      ..setDestination(placeCatalog.byId('lisbon') ?? placeCatalog.places.first)
      ..next()
      ..next()
      ..next();
    auth = AuthCubit(
      fakeAuthService(
        signedIn: true,
        user: MockUser(uid: 'organizer', displayName: 'Maya'),
      ),
    );
  });

  tearDown(() async {
    await onboarding.close();
    await auth.close();
  });

  Future<void> pumpStep(WidgetTester tester, {Future<void> Function()? onRetry}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrapApp(
        InviteStep(onRetryTripSetup: onRetry ?? () async {}),
        providers: [
          BlocProvider<OnboardingCubit>.value(value: onboarding),
          BlocProvider<AuthCubit>.value(value: auth),
        ],
      ),
    );
    await tester.pump();
  }

  testWidgets('the share action cannot be tapped while the trip is still saving', (tester) async {
    onboarding.tripSetupStarted();
    await pumpStep(tester);

    expect(find.text('Saving your trip…'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
  });

  testWidgets('after a failed save, "Try again" retries the trip setup', (tester) async {
    var retries = 0;
    onboarding.tripSetupFailed();
    await pumpStep(tester, onRetry: () async => retries++);

    expect(find.text('Couldn’t save your trip. Check your connection and try again.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(retries, 1);
  });

  testWidgets('"I\'ll do this later" moves on to the location step', (tester) async {
    onboarding.tripSetupFailed();
    await pumpStep(tester);

    await tester.tap(find.text('I’ll do this later'));
    await tester.pump();

    expect(onboarding.state.step, OnboardingStep.location);
  });
}
