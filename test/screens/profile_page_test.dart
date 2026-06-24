import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/constants/theme.dart';
import 'package:xplore/features/auth/bloc/auth_cubit.dart';
import 'package:xplore/features/profile/bloc/profile_cubit.dart';
import 'package:xplore/screens/profile_page.dart';

import '../helpers/auth_fixtures.dart';

class _ProfileHarness {
  _ProfileHarness({required this.authCubit, required this.profileCubit});

  final AuthCubit authCubit;
  final ProfileCubit profileCubit;
}

Future<_ProfileHarness> _pumpProfilePage(WidgetTester tester) async {
  final authService = fakeAuthService(
    signedIn: true,
    user: MockUser(uid: 'abc123', displayName: 'Ada Lovelace', email: 'ada@example.com'),
  );
  final authCubit = AuthCubit(authService);
  final profileCubit = ProfileCubit(authService, loadLocalProfile: false);

  addTearDown(authCubit.close);
  addTearDown(profileCubit.close);

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: authCubit),
        BlocProvider<ProfileCubit>.value(value: profileCubit),
      ],
      child: MaterialApp(debugShowCheckedModeBanner: false, theme: getTheme(), home: const ProfilePage()),
    ),
  );
  await tester.pumpAndSettle();

  return _ProfileHarness(authCubit: authCubit, profileCubit: profileCubit);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ProfilePage shows editable fields and confirms sign-out', (tester) async {
    final harness = await _pumpProfilePage(tester);

    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('ada@example.com'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(find.text('Delete Account'), findsOneWidget);

    await tester.tap(find.text('Delete Account'));
    await tester.pumpAndSettle();

    expect(find.text('Sign out?'), findsOneWidget);
    expect(harness.authCubit.state, isA<AuthAuthenticated>());

    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Sign out')));
    await tester.pumpAndSettle();

    expect(harness.authCubit.state, isA<AuthUnauthenticated>());
  });

  testWidgets('ProfilePage signed-in actions match golden', (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpProfilePage(tester);
    await tester.pumpAndSettle();

    await expectLater(find.byType(ProfilePage), matchesGoldenFile('goldens/profile_page_signed_in.png'));
  });
}
