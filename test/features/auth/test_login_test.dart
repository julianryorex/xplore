import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/auth/bloc/auth_cubit.dart';
import 'package:xplore/features/auth/presentation/sign_in_page.dart';
import 'package:xplore/features/auth/presentation/test_login.dart';
import 'package:xplore/features/auth/services/auth_service.dart';

import '../../helpers/auth_fixtures.dart';
import '../../helpers/pump_app.dart';

const _email = 'tester@example.com';

AuthCubit _cubit(WidgetTester tester, {MockFirebaseAuth? firebaseAuth}) {
  final cubit = AuthCubit(
    AuthService(
      firebaseAuth:
          firebaseAuth ??
          MockFirebaseAuth(
            mockUser: MockUser(uid: 'test-user', email: _email),
          ),
      firestore: FakeFirebaseFirestore(),
    ),
  );
  addTearDown(cubit.close);
  return cubit;
}

Future<void> _pump(WidgetTester tester, AuthCubit cubit, Widget child) async {
  await tester.pumpWidget(wrapApp(child, providers: [BlocProvider<AuthCubit>.value(value: cubit)]));
  await tester.pump();
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('Test login'));
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester, {required String email, required String password}) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
  await tester.enterText(find.widgetWithText(TextFormField, 'Password'), password);
  await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the sign-in page has no test login when the build flag is off', (tester) async {
    await _pump(tester, _cubit(tester), const SignInPage());

    expect(find.text('Sign in with Apple'), findsOneWidget);
    expect(find.text('Test login'), findsNothing);
  });

  testWidgets('submitting the form signs the test user in and closes the sheet', (tester) async {
    final cubit = _cubit(tester);
    await _pump(tester, cubit, const TestLoginEntry(enabled: true));
    await _openSheet(tester);

    await _submit(tester, email: _email, password: 'correct-password');

    expect(cubit.state, isA<AuthAuthenticated>());
    expect((cubit.state as AuthAuthenticated).uid, 'test-user');
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsNothing);
  });

  testWidgets('a failed sign-in shows the error inline and keeps the sheet open', (tester) async {
    final cubit = _cubit(tester, firebaseAuth: RejectingEmailPasswordAuth());
    await _pump(tester, cubit, const TestLoginEntry(enabled: true));
    await _openSheet(tester);

    await _submit(tester, email: _email, password: 'wrong-password');

    expect(find.text('Wrong credentials.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    expect(cubit.state, isA<AuthUnauthenticated>());
  });

  testWidgets('empty fields are rejected without attempting a sign-in', (tester) async {
    final cubit = _cubit(tester);
    await _pump(tester, cubit, const TestLoginEntry(enabled: true));
    await _openSheet(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter the test user’s email.'), findsOneWidget);
    expect(find.text('Enter the test user’s password.'), findsOneWidget);
    expect(cubit.state, isA<AuthUnauthenticated>());
  });

  testWidgets('the password can be revealed to check what was typed', (tester) async {
    await _pump(tester, _cubit(tester), const TestLoginEntry(enabled: true));
    await _openSheet(tester);

    EditableText passwordText() => tester.widget<EditableText>(
      find.descendant(of: find.widgetWithText(TextFormField, 'Password'), matching: find.byType(EditableText)),
    );
    expect(passwordText().obscureText, isTrue);

    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();

    expect(passwordText().obscureText, isFalse);
  });
}
