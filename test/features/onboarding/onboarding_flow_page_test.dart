import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/constants/theme.dart';
import 'package:xplore/features/auth/bloc/auth_cubit.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/features/onboarding/bloc/onboarding_cubit.dart';
import 'package:xplore/features/onboarding/presentation/onboarding_flow_page.dart';
import 'package:xplore/features/profile/bloc/profile_cubit.dart';
import 'package:xplore/features/trip/bloc/trip_cubit.dart';
import 'package:xplore/features/trip/bloc/trip_state.dart';
import 'package:xplore/features/trip/data/place_catalog.dart';
import 'package:xplore/features/trip/models/trip_draft.dart';
import 'package:xplore/features/trip/models/trip_model.dart';
import 'package:xplore/features/trip/services/trip_service.dart';

import '../../helpers/auth_fixtures.dart';

/// An [AuthCubit] driven by the test, so signing in needs no provider.
class _ScriptedAuthCubit extends Cubit<AuthState> implements AuthCubit {
  _ScriptedAuthCubit() : super(const AuthState.unauthenticated());

  void signIn() => emit(const AuthState.authenticated(uid: 'maya', displayName: 'Maya Chen'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A [TripCubit] that records the drafts it is asked to create, so the flow
/// can be pumped without Firestore.
class _RecordingTripCubit extends Cubit<TripState> implements TripCubit {
  _RecordingTripCubit() : super(const TripState.empty());

  final created = <TripDraft>[];

  @override
  Future<TripModel> createTripFromDraft(TripDraft draft, {List<DailyPlanModel> itinerary = const []}) async {
    created.add(draft);
    return TripModel(id: 'trip-1', title: draft.effectiveTitle, memberIds: const ['maya'], createdBy: 'maya');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _ScriptedAuthCubit auth;
  late OnboardingCubit onboarding;
  late ProfileCubit profile;
  late _RecordingTripCubit trips;

  setUp(() {
    auth = _ScriptedAuthCubit();
    onboarding = OnboardingCubit(TripService(firestore: FakeFirebaseFirestore()));
    // Its own signed-out auth service, so the scripted sign-in never sends it to Firebase.
    profile = ProfileCubit(fakeAuthService(), hydrate: false);
    trips = _RecordingTripCubit();
  });

  tearDown(() async {
    await auth.close();
    await onboarding.close();
    await profile.close();
    await trips.close();
  });

  Future<void> pumpFlow(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: auth),
          BlocProvider<OnboardingCubit>.value(value: onboarding),
          BlocProvider<ProfileCubit>.value(value: profile),
          BlocProvider<TripCubit>.value(value: trips),
        ],
        child: MaterialApp(theme: getTheme(), home: const OnboardingFlowPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> signIn(WidgetTester tester) async {
    auth.signIn();
    // Fixed pumps, not pumpAndSettle: the steps after sign-in show spinners
    // that never settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('a returning user is done as soon as they sign in', (tester) async {
    await pumpFlow(tester);
    await tester.ensureVisible(find.text('I already have an account'));
    await tester.tap(find.text('I already have an account'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back.'), findsOneWidget);

    await signIn(tester);

    expect(onboarding.state.completed, isTrue);
    expect(trips.created, isEmpty);
  });

  testWidgets('an organizer who signs in gets their trip saved and moves on to the profile step', (tester) async {
    await pumpFlow(tester);
    onboarding
      ..startOrganizer()
      ..setDestination(placeCatalog.byId('lisbon'))
      ..next();
    await tester.pumpAndSettle();
    expect(find.text('Save your trip'), findsOneWidget);

    await signIn(tester);

    expect(onboarding.state.step, OnboardingStep.profile);
    expect(trips.created.single.effectiveTitle, 'Lisbon');
    expect(onboarding.state.tripSetup, TripSetupStatus.created);
    expect(onboarding.state.createdTrip?.id, 'trip-1');
  });
}
