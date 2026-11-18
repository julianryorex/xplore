import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/constants/theme.dart';
import 'package:xplore/core/app_tab.dart';
import 'package:xplore/core/navbar.dart';
import 'package:xplore/core/root_shell.dart';
import 'package:xplore/features/itinerary/bloc/itinerary_cubit.dart';
import 'package:xplore/features/nav/bloc/nav_cubit.dart';
import 'package:xplore/features/trip/bloc/trip_cubit.dart';
import 'package:xplore/features/trip/bloc/trip_state.dart';
import 'package:xplore/features/trip/models/trip_model.dart';

/// A [TripCubit] driven by the test, so the shell can be pumped without Firestore.
class _ScriptedTripCubit extends Cubit<TripState> implements TripCubit {
  _ScriptedTripCubit(super.initialState);

  void push(TripState state) => emit(state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _trip = TripModel(id: 't1', title: 'Tokyo with the crew', memberIds: ['me'], createdBy: 'me');
const _loaded = TripState.loaded(active: _trip, all: [_trip]);

final _menuEntry = find.text('Ask anything');
final _agentButton = find.bySemanticsLabel('Ask xplore');

Future<({_ScriptedTripCubit trips, NavbarCubit nav})> _pumpShell(WidgetTester tester, TripState tripState) async {
  final tripCubit = _ScriptedTripCubit(tripState);
  final itineraryCubit = ItineraryCubit();
  final navCubit = NavbarCubit();
  addTearDown(tripCubit.close);
  addTearDown(itineraryCubit.close);
  addTearDown(navCubit.close);

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<TripCubit>.value(value: tripCubit),
        BlocProvider<ItineraryCubit>.value(value: itineraryCubit),
        BlocProvider<NavbarCubit>.value(value: navCubit),
      ],
      child: MaterialApp(
        theme: getTheme(),
        home: RootShell(destinationBuilder: (tab) => Text('${tab.label} screen')),
      ),
    ),
  );
  await tester.pump();
  return (trips: tripCubit, nav: navCubit);
}

void main() {
  testWidgets('hides the tab bar while trips are loading', (tester) async {
    await _pumpShell(tester, const TripState.loading());

    expect(find.byType(Navbar), findsNothing);
    expect(find.text('Home screen'), findsOneWidget);
  });

  testWidgets('closes the quick menu when another tab is selected', (tester) async {
    final cubits = await _pumpShell(tester, _loaded);

    await tester.tap(_agentButton);
    await tester.pumpAndSettle();
    expect(_menuEntry, findsOneWidget);

    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();

    expect(cubits.nav.state, AppTab.map.index);
    expect(_menuEntry, findsNothing);
  });

  testWidgets('losing every trip closes the menu, hides the tab bar and resets to Home', (tester) async {
    final cubits = await _pumpShell(tester, _loaded);
    cubits.nav.setTab(AppTab.map);
    await tester.pumpAndSettle();

    await tester.tap(_agentButton);
    await tester.pumpAndSettle();
    expect(_menuEntry, findsOneWidget);

    cubits.trips.push(const TripState.empty());
    await tester.pumpAndSettle();

    expect(_menuEntry, findsNothing);
    expect(find.byType(Navbar), findsNothing);
    expect(cubits.nav.state, AppTab.home.index);
  });
}
