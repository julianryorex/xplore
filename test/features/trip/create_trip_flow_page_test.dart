import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/constants/theme.dart';
import 'package:xplore/features/trip/bloc/trip_creation_cubit.dart';
import 'package:xplore/features/trip/bloc/trip_creation_state.dart';
import 'package:xplore/features/trip/data/place_catalog.dart';
import 'package:xplore/features/trip/presentation/create_trip/create_trip_flow_page.dart';

void main() {
  late TripCreationCubit cubit;

  setUp(() => cubit = TripCreationCubit());
  tearDown(() => cubit.close());

  List<String> stopIds() => cubit.state.draft.stops.map((stop) => stop.id).toList();

  /// Opens the flow from a home screen, so closing it can be observed.
  Future<void> pumpFlow(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: getTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BlocProvider.value(
                      value: cubit,
                      // Platform views cannot render in widget tests.
                      child: CreateTripFlowPage(mapSurfaceBuilder: (_, _) => const SizedBox()),
                    ),
                  ),
                ),
                child: const Text('Open flow'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open flow'));
    await tester.pumpAndSettle();
  }

  FilledButton primaryButton(WidgetTester tester) => tester.widget<FilledButton>(find.byType(FilledButton));

  group('where', () {
    testWidgets('starts disabled with a reason, and a place added through search enables it', (tester) async {
      await pumpFlow(tester);

      expect(find.text('STEP 1 OF 4'), findsOneWidget);
      expect(find.text('Add your first place'), findsOneWidget);
      expect(find.text('Add a place to continue'), findsOneWidget);
      expect(primaryButton(tester).onPressed, isNull);

      await tester.tap(find.text('Add a place'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('POPULAR'), findsNWidgets(2));

      await tester.enterText(find.byType(TextField), 'kyo');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kyoto').last);
      await tester.pumpAndSettle();

      expect(stopIds(), ['kyoto']);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Kyoto'), findsOneWidget);
      expect(find.text('Add a place to continue'), findsNothing);
      expect(primaryButton(tester).onPressed, isNotNull);
    });

    testWidgets('a search without matches says so', (tester) async {
      await pumpFlow(tester);
      await tester.tap(find.text('Add a place'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'atlantis');
      await tester.pumpAndSettle();

      expect(find.text('No matches'), findsOneWidget);
    });

    testWidgets('swiping a place away removes it and undo puts it back in place', (tester) async {
      for (final id in ['tokyo', 'kyoto', 'osaka']) {
        cubit.addStop(placeCatalog.byId(id)!);
      }
      await pumpFlow(tester);

      await tester.drag(find.byKey(const ValueKey('kyoto')), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(stopIds(), ['tokyo', 'osaka']);
      expect(find.text('Kyoto removed'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(stopIds(), ['tokyo', 'kyoto', 'osaka']);
    });

    testWidgets('reordering moves the place to the dropped slot', (tester) async {
      for (final id in ['tokyo', 'kyoto', 'osaka']) {
        cubit.addStop(placeCatalog.byId(id)!);
      }
      await pumpFlow(tester);

      final list = tester.widget<ReorderableListView>(find.byType(ReorderableListView));
      list.onReorderItem!(0, 2);
      expect(stopIds(), ['kyoto', 'osaka', 'tokyo']);

      list.onReorderItem!(2, 0);
      expect(stopIds(), ['tokyo', 'kyoto', 'osaka']);
    });

    testWidgets('the add row is disabled at the place limit', (tester) async {
      for (final place in placeCatalog.places.take(maxTripStops)) {
        cubit.addStop(place);
      }
      await pumpFlow(tester);

      expect(find.text('Up to $maxTripStops places'), findsOneWidget);
      await tester.tap(find.text('Add a place'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('when', () {
    testWidgets('unassigned nights disable the button until they add up', (tester) async {
      cubit
        ..addStop(placeCatalog.byId('tokyo')!)
        ..addStop(placeCatalog.byId('kyoto')!)
        ..next()
        ..setExactDates(DateTime(2030, 4, 3), DateTime(2030, 4, 13));
      await pumpFlow(tester);

      expect(find.text('STEP 2 OF 4'), findsOneWidget);
      expect(find.text('10 of 10 nights assigned'), findsOneWidget);
      expect(primaryButton(tester).onPressed, isNotNull);

      await tester.tap(find.bySemanticsLabel('Fewer nights in Kyoto'));
      await tester.pumpAndSettle();
      expect(find.text('Assign 1 more night'), findsOneWidget);
      expect(primaryButton(tester).onPressed, isNull);

      await tester.tap(find.bySemanticsLabel('More nights in Tokyo'));
      await tester.pumpAndSettle();
      expect(find.text('Assign 1 more night'), findsNothing);
      expect(primaryButton(tester).onPressed, isNotNull);
    });

    testWidgets('back keeps the input and returns to the places', (tester) async {
      cubit
        ..addStop(placeCatalog.byId('tokyo')!)
        ..next();
      await pumpFlow(tester);

      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();

      expect(cubit.state.currentStep, CreateTripStep.where);
      expect(stopIds(), ['tokyo']);
    });
  });

  group('leaving', () {
    testWidgets('closing with unsaved input asks first', (tester) async {
      cubit.addStop(placeCatalog.byId('tokyo')!);
      await pumpFlow(tester);

      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Discard this trip?'), findsOneWidget);

      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Where to?'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('Open flow'), findsOneWidget);
    });

    testWidgets('closing an untouched flow leaves straight away', (tester) async {
      await pumpFlow(tester);

      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Discard this trip?'), findsNothing);
      expect(find.text('Open flow'), findsOneWidget);
    });
  });
}
