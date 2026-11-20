import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/onboarding/bloc/onboarding_cubit.dart';
import 'package:xplore/features/onboarding/presentation/steps/welcome_step.dart';
import 'package:xplore/features/trip/services/trip_service.dart';

import '../../helpers/pump_app.dart';

void main() {
  late OnboardingCubit cubit;

  setUp(() => cubit = OnboardingCubit(TripService(firestore: FakeFirebaseFirestore())));
  tearDown(() => cubit.close());

  Future<void> pumpWelcome(WidgetTester tester) async {
    // A small phone, so the test also catches the layout overflowing.
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapApp(const WelcomeStep(), providers: [BlocProvider<OnboardingCubit>.value(value: cubit)]),
    );
  }

  testWidgets('"Plan a trip" starts the organizer path at the destination step', (tester) async {
    await pumpWelcome(tester);

    await tester.ensureVisible(find.text('Plan a trip'));
    await tester.pump();
    await tester.tap(find.text('Plan a trip'));

    expect(cubit.state.path, OnboardingPath.organizer);
    expect(cubit.state.step, OnboardingStep.destination);
  });

  testWidgets('"I already have an account" starts the returning path at sign-in', (tester) async {
    await pumpWelcome(tester);

    // The test font is wider than the system font, so the screen scrolls here.
    await tester.ensureVisible(find.text('I already have an account'));
    await tester.pump();
    await tester.tap(find.text('I already have an account'));

    expect(cubit.state.path, OnboardingPath.returning);
    expect(cubit.state.step, OnboardingStep.signIn);
  });
}
