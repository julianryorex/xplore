import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/auth/bloc/auth_cubit.dart';
import 'package:xplore/features/onboarding/bloc/onboarding_cubit.dart';
import 'package:xplore/features/onboarding/presentation/steps/profile_step.dart';
import 'package:xplore/features/profile/bloc/profile_cubit.dart';
import 'package:xplore/features/trip/data/place_catalog.dart';
import 'package:xplore/features/trip/services/trip_service.dart';

import '../../helpers/auth_fixtures.dart';
import '../../helpers/pump_app.dart';

void main() {
  late OnboardingCubit onboarding;
  late AuthCubit auth;
  late ProfileCubit profile;

  setUp(() {
    // Organizer, signed in and on the profile step.
    onboarding = OnboardingCubit(TripService(firestore: FakeFirebaseFirestore()))
      ..startOrganizer()
      ..setDestination(placeCatalog.byId('lisbon'))
      ..next()
      ..onAuthenticated();
    final authService = fakeAuthService(
      signedIn: true,
      user: MockUser(uid: 'maya', displayName: 'Maya Chen'),
    );
    auth = AuthCubit(authService);
    profile = ProfileCubit(authService, hydrate: false);
  });

  tearDown(() async {
    await onboarding.close();
    await auth.close();
    await profile.close();
  });

  Future<void> pumpStep(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrapApp(
        const ProfileStep(),
        providers: [
          BlocProvider<OnboardingCubit>.value(value: onboarding),
          BlocProvider<AuthCubit>.value(value: auth),
          BlocProvider<ProfileCubit>.value(value: profile),
        ],
      ),
    );
    await tester.pump();
  }

  testWidgets('Continue moves on to the invite step', (tester) async {
    await pumpStep(tester);
    expect(onboarding.state.step, OnboardingStep.profile);
    expect(find.text('Maya Chen'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(onboarding.state.step, OnboardingStep.invite);
  });

  testWidgets('Skip moves on to the invite step', (tester) async {
    await pumpStep(tester);

    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(onboarding.state.step, OnboardingStep.invite);
  });
}
