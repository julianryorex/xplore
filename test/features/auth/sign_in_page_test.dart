import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/constants/theme.dart';
import 'package:xplore/features/auth/bloc/auth_cubit.dart';
import 'package:xplore/features/auth/presentation/sign_in_page.dart';

import '../../helpers/auth_fixtures.dart';

Future<void> _pumpSignInPage(WidgetTester tester) async {
  final authCubit = AuthCubit(fakeAuthService(signedIn: false));
  addTearDown(authCubit.close);

  await tester.pumpWidget(
    BlocProvider<AuthCubit>.value(
      value: authCubit,
      child: MaterialApp(debugShowCheckedModeBanner: false, theme: getTheme(), home: const SignInPage()),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('offers Apple as the primary option alongside Google', (tester) async {
    await _pumpSignInPage(tester);

    expect(find.text('Sign in with Apple'), findsOneWidget);
    expect(find.byIcon(Icons.apple), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });
}
