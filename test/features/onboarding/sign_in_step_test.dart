import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/auth/bloc/auth_cubit.dart';
import 'package:xplore/features/onboarding/bloc/onboarding_cubit.dart';
import 'package:xplore/features/onboarding/presentation/steps/sign_in_step.dart';
import 'package:xplore/features/trip/data/place_catalog.dart';
import 'package:xplore/features/trip/models/trip_invite.dart';
import 'package:xplore/features/trip/services/invite_link.dart';
import 'package:xplore/features/trip/services/invite_results.dart';
import 'package:xplore/features/trip/services/trip_service.dart';

import '../../helpers/auth_fixtures.dart';
import '../../helpers/pump_app.dart';

/// Answers every invite lookup with a fixed preview, so the invitee path can be
/// set up without seeding Firestore.
class _PreviewTripService extends TripService {
  _PreviewTripService() : super(firestore: FakeFirebaseFirestore());

  @override
  Future<InviteLookup> lookupInvite(String tripId, String token, {String? uid, DateTime? now}) async =>
      const InviteLookup.valid(
        TripInvite(token: 'token', tripId: 'trip-1', createdBy: 'owner-1', tripTitle: 'Lisbon', memberCount: 3),
      );
}

void main() {
  late OnboardingCubit onboarding;
  late AuthCubit auth;

  setUp(() {
    onboarding = OnboardingCubit(_PreviewTripService());
    auth = AuthCubit(fakeAuthService(signedIn: false));
  });

  tearDown(() async {
    await onboarding.close();
    await auth.close();
  });

  Future<void> pumpStep(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrapApp(
        const SignInStep(),
        providers: [
          BlocProvider<OnboardingCubit>.value(value: onboarding),
          BlocProvider<AuthCubit>.value(value: auth),
        ],
      ),
    );
    await tester.pump();
  }

  testWidgets('the organizer is asked to save the trip they picked', (tester) async {
    onboarding
      ..startOrganizer()
      ..setDestination(placeCatalog.byId('lisbon'))
      ..next();

    await pumpStep(tester);

    expect(find.text('Save your trip'), findsOneWidget);
    expect(find.text('Ready to save'), findsOneWidget);
    expect(find.text('Sign in with Apple'), findsOneWidget);
  });

  testWidgets('the invitee is asked to join the previewed trip', (tester) async {
    await onboarding.startInvite(const InviteLinkData(tripId: 'trip-1', token: 'token'));
    onboarding.next();

    await pumpStep(tester);

    expect(find.text('Sign in to join Lisbon'), findsOneWidget);
    expect(find.text('3 people are already in. Sign in so they know it’s you.'), findsOneWidget);
  });

  testWidgets('a returning user is welcomed back', (tester) async {
    onboarding.startReturning();

    await pumpStep(tester);

    expect(find.text('Welcome back.'), findsOneWidget);
    expect(find.text('New here? Plan a trip'), findsOneWidget);
  });
}
