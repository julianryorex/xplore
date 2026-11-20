import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/onboarding/bloc/onboarding_cubit.dart';
import 'package:xplore/features/onboarding/presentation/steps/invite_welcome_step.dart';
import 'package:xplore/features/trip/services/invite_link.dart';
import 'package:xplore/features/trip/services/trip_service.dart';

import '../../helpers/pump_app.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late TripService tripService;
  late OnboardingCubit cubit;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    tripService = TripService(firestore: firestore);
    cubit = OnboardingCubit(tripService);
  });
  tearDown(() => cubit.close());

  Future<InviteLinkData> seedInvite() async {
    final trip = firestore.collection('trips').doc();
    await trip.set(<String, dynamic>{
      'title': 'Lisbon with friends',
      'memberIds': ['owner-1', 'friend-1'],
      'createdBy': 'owner-1',
      'lastUpdatedBy': 'owner-1',
      'createdAt': Timestamp.now(),
      'lastUpdatedAt': Timestamp.now(),
    });
    final handle = await tripService.createInvite(trip.id, 'owner-1');
    return InviteLinkData(tripId: trip.id, token: handle.invite.token);
  }

  Future<void> pumpStep(WidgetTester tester) async {
    // A small phone, so the test also catches the layout overflowing.
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapApp(const InviteWelcomeStep(), providers: [BlocProvider<OnboardingCubit>.value(value: cubit)]),
    );
  }

  testWidgets('shows the trip title and group size from a ready preview', (tester) async {
    await tester.runAsync(() async => cubit.startInvite(await seedInvite()));
    expect(cubit.state.invitePreviewStatus, InvitePreviewStatus.ready);

    await pumpStep(tester);

    expect(find.text('Lisbon with friends'), findsOneWidget);
    expect(find.text('2 people going'), findsOneWidget);
  });

  testWidgets('falls back to generic copy when the preview is unavailable', (tester) async {
    await tester.runAsync(() => cubit.startInvite(const InviteLinkData(tripId: 'missing', token: 'nope')));
    expect(cubit.state.invitePreviewStatus, InvitePreviewStatus.unavailable);

    await pumpStep(tester);

    expect(find.text('You’re invited to a trip'), findsOneWidget);
    expect(find.textContaining('going'), findsNothing);
  });
}
