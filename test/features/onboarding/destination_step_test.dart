import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/onboarding/bloc/onboarding_cubit.dart';
import 'package:xplore/features/onboarding/presentation/steps/destination_step.dart';
import 'package:xplore/features/trip/services/trip_service.dart';

import '../../helpers/pump_app.dart';

void main() {
  late OnboardingCubit cubit;

  setUp(() => cubit = OnboardingCubit(TripService(firestore: FakeFirebaseFirestore()))..startOrganizer());
  tearDown(() => cubit.close());

  FilledButton continueButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'));

  testWidgets('Continue is enabled only once a searched place is picked', (tester) async {
    await tester.pumpWidget(
      wrapApp(const DestinationStep(), providers: [BlocProvider<OnboardingCubit>.value(value: cubit)]),
    );

    expect(continueButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'lisb');
    await tester.pump();
    await tester.tap(find.text('Lisbon'));
    await tester.pump();

    expect(cubit.state.destination?.id, 'lisbon');
    expect(find.text('Lisbon, Portugal'), findsOneWidget);
    expect(continueButton(tester).onPressed, isNotNull);
  });
}
