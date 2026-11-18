import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/trip/bloc/trip_creation_cubit.dart';
import 'package:xplore/features/trip/bloc/trip_creation_state.dart';
import 'package:xplore/features/trip/data/place_catalog.dart';
import 'package:xplore/features/trip/models/trip_draft.dart';
import 'package:xplore/features/trip/models/trip_model.dart';
import 'package:xplore/features/trip/presentation/create_trip/plan_step.dart';
import 'package:xplore/features/trip/presentation/create_trip/trip_ready_step.dart';
import 'package:xplore/features/trip/presentation/create_trip/who_and_vibe_step.dart';

import '../../helpers/pump_app.dart';

CatalogPlace _place(String id) => placeCatalog.byId(id)!;

void main() {
  late TripCreationCubit cubit;

  setUp(() => cubit = TripCreationCubit(initialNotes: 'Cherry blossoms in Ueno'));
  tearDown(() => cubit.close());

  Future<void> pump(WidgetTester tester, Widget step) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      wrapApp(
        SingleChildScrollView(child: step),
        providers: [BlocProvider<TripCreationCubit>.value(value: cubit)],
      ),
    );
    await tester.pumpAndSettle();
  }

  void goToPlan() {
    while (cubit.state.currentStep != CreateTripStep.plan) {
      cubit.next();
    }
  }

  group('who and vibe', () {
    testWidgets('the group kind keeps the count coherent', (tester) async {
      await pump(tester, const WhoAndVibeStep());
      expect(find.text('How many of you?'), findsNothing, reason: 'solo is always one');

      await tester.tap(find.text('Couple'));
      await tester.pumpAndSettle();
      expect(cubit.state.draft.groupSize, 2);
      expect(find.text('How many of you?'), findsNothing, reason: 'a couple is always two');

      await tester.tap(find.text('Friends'));
      await tester.pumpAndSettle();
      expect(cubit.state.draft.groupSize, 3);
      await tester.tap(find.bySemanticsLabel('More people'));
      await tester.pumpAndSettle();
      expect(cubit.state.draft.groupSize, 4);

      // A count tuned for friends carries over to family.
      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();
      expect(cubit.state.draft.groupSize, 4);

      for (var i = 0; i < 5; i++) {
        await tester.tap(find.bySemanticsLabel('Fewer people'));
        await tester.pumpAndSettle();
      }
      expect(cubit.state.draft.groupSize, minGroupSize);

      await tester.tap(find.text('Solo'));
      await tester.pumpAndSettle();
      expect(cubit.state.draft.groupSize, 1);
    });

    testWidgets('interests toggle, with a hint while none are picked', (tester) async {
      await pump(tester, const WhoAndVibeStep());
      expect(find.textContaining('a bit of everything'), findsOneWidget);

      await tester.tap(find.text('Culture'));
      await tester.pumpAndSettle();
      expect(cubit.state.draft.interests, {TripInterest.culture});
      expect(find.textContaining('a bit of everything'), findsNothing);

      await tester.tap(find.text('Culture'));
      await tester.pumpAndSettle();
      expect(cubit.state.draft.interests, isEmpty);
    });

    testWidgets('the notes field shows the seeded notes and edits them', (tester) async {
      await pump(tester, const WhoAndVibeStep());
      expect(find.text('Cherry blossoms in Ueno'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Sushi breakfast');
      expect(cubit.state.draft.notes, 'Sushi breakfast');
    });
  });

  group('plan', () {
    testWidgets('shows the suggested name and the days grouped by place, first place open', (tester) async {
      cubit
        ..addStop(_place('tokyo'))
        ..addStop(_place('kyoto'))
        ..setGroup(TripGroupKind.friends);
      goToPlan();
      await pump(tester, const PlanStep());

      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Japan with friends');
      expect(find.text('5 days across 2 places'), findsOneWidget);
      expect(find.text('Tokyo'), findsOneWidget);
      expect(find.text('Kyoto'), findsOneWidget);

      // Tokyo (2 nights) is open: days 1 and 2. Kyoto's days 3 to 5 are not.
      expect(find.text('DAY 2'), findsOneWidget);
      expect(find.text('DAY 3'), findsNothing);

      await tester.tap(find.text('Kyoto'));
      await tester.pumpAndSettle();
      expect(find.text('DAY 5'), findsOneWidget);

      await tester.tap(find.text('Tokyo'));
      await tester.pumpAndSettle();
      expect(find.text('DAY 1'), findsNothing);
    });

    testWidgets('a cleared name falls back to the suggestion', (tester) async {
      cubit.addStop(_place('tokyo'));
      goToPlan();
      await pump(tester, const PlanStep());

      await tester.enterText(find.byType(TextField), 'Spring break');
      expect(cubit.state.draft.effectiveTitle, 'Spring break');

      await tester.enterText(find.byType(TextField), '');
      expect(cubit.state.draft.effectiveTitle, 'Solo in Tokyo');
    });

    testWidgets('a single-place trip lists its days directly', (tester) async {
      cubit.addStop(_place('lisbon'));
      goToPlan();
      await pump(tester, const PlanStep());

      expect(find.text('3 days in Lisbon'), findsOneWidget);
      expect(find.text('01'), findsNothing, reason: 'no grouping row');
      expect(find.text('DAY 1'), findsOneWidget);
      expect(find.text('DAY 3'), findsOneWidget);
    });
  });

  group('trip ready', () {
    TripModel created() =>
        TripModel(id: 'trip-1', title: cubit.state.draft.effectiveTitle, memberIds: const ['me'], createdBy: 'me');

    String primaryLabel(WidgetTester tester) {
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      return (button.child! as Text).data!;
    }

    testWidgets('a group trip leads with sharing the invite', (tester) async {
      cubit
        ..addStop(_place('lisbon'))
        ..setGroup(TripGroupKind.friends)
        ..markCreated(created());
      await pump(tester, const TripReadyStep());

      expect(find.text('Bring your crew'), findsOneWidget);
      expect(primaryLabel(tester), 'Share invite link');
      expect(find.text('Go to trip'), findsOneWidget);
    });

    testWidgets('a solo trip leads with going to the trip', (tester) async {
      cubit
        ..addStop(_place('lisbon'))
        ..markCreated(created());
      await pump(tester, const TripReadyStep());

      expect(find.text('Bring your crew'), findsNothing);
      expect(primaryLabel(tester), 'Go to trip');
      expect(find.text('Share invite link'), findsOneWidget);
    });
  });
}
