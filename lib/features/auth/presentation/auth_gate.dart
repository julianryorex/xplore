import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/core/ambient_background.dart';
import 'package:xplore/core/root_shell.dart';
import 'package:xplore/features/auth/bloc/auth_cubit.dart';
import 'package:xplore/features/auth/presentation/onboarding_page.dart';

/// Chooses the app root based on [AuthState] (FEAT-001 hard gate):
/// `unknown` -> splash, `unauthenticated` -> onboarding/sign-in,
/// `authenticated` -> Home. Returning sessions resolve straight to Home.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      // Only react when the *kind* of auth state changes (e.g. sign-in / out),
      // not on incidental updates to an authenticated user's fields.
      listenWhen: (previous, current) =>
          previous.runtimeType != current.runtimeType,
      listener: (context, state) {
        // The onboarding/sign-in screens are pushed on top of this gate. When
        // auth flips, clear those pushed routes so the gate's base view (Home
        // when authenticated, Onboarding when not) is what's actually shown.
        if (state is AuthAuthenticated || state is AuthUnauthenticated) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      builder: (context, state) {
        return switch (state) {
          AuthUnknown() => const _Splash(),
          AuthUnauthenticated() => const OnboardingPage(),
          AuthAuthenticated() => const RootShell(),
        };
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XploreColors.primaryBg,
      body: AmbientBackground(
        child: Center(
          child: CircularProgressIndicator(color: XploreColors.alternate),
        ),
      ),
    );
  }
}
