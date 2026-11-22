import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/onboarding/bloc/onboarding_cubit.dart';
import 'package:xplore/features/onboarding/presentation/steps/location_step.dart';
import 'package:xplore/features/trip/services/trip_service.dart';

import '../../helpers/pump_app.dart';

void main() {
  late OnboardingCubit onboarding;

  setUp(() {
    // The location step only appears for a trip that is under way.
    onboarding = OnboardingCubit(TripService(firestore: FakeFirebaseFirestore()), clock: () => DateTime(2027, 6, 5))
      ..startOrganizer()
      ..setDates(DateTime(2027, 6, 3), DateTime(2027, 6, 9));
    while (onboarding.state.step != OnboardingStep.location) {
      onboarding.next();
    }
  });

  tearDown(() => onboarding.close());

  Future<void> pumpStep(WidgetTester tester, Future<void> Function() requestPermission) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrapApp(
        LocationStep(requestPermission: requestPermission),
        providers: [BlocProvider<OnboardingCubit>.value(value: onboarding)],
      ),
    );
  }

  testWidgets('"Turn on location" asks for permission, then moves on to the send-off', (tester) async {
    final answer = Completer<void>();
    var requests = 0;
    await pumpStep(tester, () {
      requests++;
      return answer.future;
    });

    await tester.tap(find.text('Turn on location'));
    await tester.pump();
    expect(requests, 1);
    expect(onboarding.state.step, OnboardingStep.location, reason: 'waits for the answer before moving on');

    answer.complete();
    await tester.pump();
    expect(onboarding.state.step, OnboardingStep.allSet);
  });

  testWidgets('a failed permission prompt still moves on', (tester) async {
    await pumpStep(tester, () => Future.error(StateError('no prompt')));

    await tester.tap(find.text('Turn on location'));
    await tester.pump();

    expect(onboarding.state.step, OnboardingStep.allSet);
  });

  testWidgets('"Not now" moves on without asking for permission', (tester) async {
    var requests = 0;
    await pumpStep(tester, () async => requests++);

    await tester.tap(find.text('Not now'));
    await tester.pump();

    expect(requests, 0);
    expect(onboarding.state.step, OnboardingStep.allSet);
  });
}
