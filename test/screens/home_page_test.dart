import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/constants/theme.dart';
import 'package:xplore/core/error_state.dart';
import 'package:xplore/features/gallery/bloc/gallery_cubit.dart';
import 'package:xplore/features/gallery/models/image_models.dart';
import 'package:xplore/features/gallery/repository/gallery_repository.dart';
import 'package:xplore/features/home/presentation/empty_home.dart';
import 'package:xplore/features/home/presentation/trip_home.dart';
import 'package:xplore/features/itinerary/bloc/itinerary_cubit.dart';
import 'package:xplore/features/profile/bloc/profile_cubit.dart';
import 'package:xplore/features/trip/bloc/trip_cubit.dart';
import 'package:xplore/features/trip/bloc/trip_state.dart';
import 'package:xplore/features/trip/models/trip_model.dart';
import 'package:xplore/screens/home_page.dart';

import '../helpers/auth_fixtures.dart';

/// A [TripCubit] pinned to one state, so Home can be pumped without Firestore.
class _FixedTripCubit extends Cubit<TripState> implements TripCubit {
  _FixedTripCubit(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Repository that skips Hive so the gallery cubit can be built in a test.
class _EmptyGalleryRepository extends GalleryRepository {
  @override
  Future<Map<String, ImageModel>> loadImgFromCache(String tripId) async => {};
}

Future<void> _pumpHome(WidgetTester tester, TripState tripState) async {
  final authService = fakeAuthService(signedIn: true);
  final tripCubit = _FixedTripCubit(tripState);
  final itineraryCubit = ItineraryCubit();
  final galleryCubit = GalleryCubit(authService, repo: _EmptyGalleryRepository());
  final profileCubit = ProfileCubit(authService, hydrate: false);

  addTearDown(tripCubit.close);
  addTearDown(itineraryCubit.close);
  addTearDown(galleryCubit.close);
  addTearDown(profileCubit.close);

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<TripCubit>.value(value: tripCubit),
        BlocProvider<ItineraryCubit>.value(value: itineraryCubit),
        BlocProvider<GalleryCubit>.value(value: galleryCubit),
        BlocProvider<ProfileCubit>.value(value: profileCubit),
      ],
      child: MaterialApp(
        theme: getTheme(),
        home: const Scaffold(body: HomePage()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  const trip = TripModel(id: 't1', title: 'Tokyo with the crew', memberIds: ['me', 'friend'], createdBy: 'me');

  testWidgets('shows the first-trip prompt when the user has no trips', (tester) async {
    await _pumpHome(tester, const TripState.empty());

    expect(find.byType(EmptyHome), findsOneWidget);
    expect(find.byType(TripHome), findsNothing);
  });

  testWidgets('shows the active trip when one is loaded', (tester) async {
    await _pumpHome(tester, const TripState.loaded(active: trip, all: [trip]));

    expect(find.byType(TripHome), findsOneWidget);
    expect(find.byType(EmptyHome), findsNothing);
    expect(find.text('Tokyo with the crew'), findsOneWidget);
  });

  testWidgets('offers a retry instead of either body when trips fail to load', (tester) async {
    await _pumpHome(tester, const TripState.error('offline'));

    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.byType(EmptyHome), findsNothing);
    expect(find.byType(TripHome), findsNothing);
  });
}
