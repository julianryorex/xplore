import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/constants/theme.dart';
import 'package:xplore/features/auth/bloc/auth_cubit.dart';
import 'package:xplore/features/auth/services/auth_service.dart';
import 'package:xplore/features/profile/bloc/profile_cubit.dart';
import 'package:xplore/screens/profile_page.dart';

Future<void> _loadPoppins() async {
  final loader = FontLoader('Poppins')
    ..addFont(rootBundle.load('assets/fonts/Poppins-Medium.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Poppins-SemiBold.ttf'));
  await loader.load();
}

class _ProfileHarness {
  _ProfileHarness({required this.authCubit, required this.profileCubit});

  final AuthCubit authCubit;
  final ProfileCubit profileCubit;
}

Future<_ProfileHarness> _pumpProfilePage(WidgetTester tester) async {
  final authService = AuthService(
    firebaseAuth: MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(
        uid: 'abc123',
        displayName: 'Ada Lovelace',
        email: 'ada@example.com',
      ),
    ),
    firestore: FakeFirebaseFirestore(),
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
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: getTheme(),
        home: const ProfilePage(),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return _ProfileHarness(authCubit: authCubit, profileCubit: profileCubit);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadPoppins);

  testWidgets('ProfilePage shows signed-in account and confirms sign-out', (
    tester,
  ) async {
    final harness = await _pumpProfilePage(tester);

    expect(find.text('Signed in as ada@example.com'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Sign out'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Sign out?'), findsOneWidget);
    expect(
      find.text(
        'You will return to the sign-in screen and can choose another Google account.',
      ),
      findsOneWidget,
    );
    expect(harness.authCubit.state, isA<AuthAuthenticated>());

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Sign out'),
      ),
    );
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

    await expectLater(
      find.byType(ProfilePage),
      matchesGoldenFile('goldens/profile_page_signed_in.png'),
    );
  });
}
