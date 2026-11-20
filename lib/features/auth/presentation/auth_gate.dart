import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/core/ambient_background.dart';
import 'package:xplore/core/root_shell.dart';
import 'package:xplore/features/auth/bloc/auth_cubit.dart';
import 'package:xplore/features/nav/bloc/nav_cubit.dart';
import 'package:xplore/features/onboarding/bloc/onboarding_cubit.dart';
import 'package:xplore/features/onboarding/presentation/onboarding_flow_page.dart';

/// Chooses the app root from [AuthState] and the onboarding flow (FEAT-001
/// hard gate, FEAT-005): `unknown` -> splash, `unauthenticated` -> onboarding,
/// `authenticated` -> Home, except that a user who signed in part-way through
/// onboarding stays in it until they finish. Returning sessions resolve
/// straight to Home.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final isOnboarding = context.select<OnboardingCubit, bool>((cubit) => cubit.state.isInProgress);

    return MultiBlocListener(
      listeners: [
        BlocListener<AuthCubit, AuthState>(
          // Only react when the *kind* of auth state changes (e.g. sign-in / out),
          // not on incidental updates to an authenticated user's fields.
          listenWhen: (previous, current) => previous.runtimeType != current.runtimeType,
          listener: (context, state) {
            // Routes may be pushed on top of this gate. When auth flips, clear
            // them so the gate's base view is what's actually shown.
            if (state is AuthAuthenticated || state is AuthUnauthenticated) {
              context.read<NavbarCubit>().reset();
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          },
        ),
        BlocListener<AuthCubit, AuthState>(
          // A sign-out starts onboarding over. The first resolution to
          // unauthenticated at launch must not, or it would drop an invite
          // link the app was opened with.
          listenWhen: (previous, current) => previous is AuthAuthenticated && current is AuthUnauthenticated,
          listener: (context, _) => context.read<OnboardingCubit>().reset(),
        ),
      ],
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          return switch (state) {
            AuthUnknown() => const _Splash(),
            AuthUnauthenticated() => const OnboardingFlowPage(),
            AuthAuthenticated() => isOnboarding ? const OnboardingFlowPage() : const RootShell(),
          };
        },
      ),
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
        child: Center(child: CircularProgressIndicator(color: XploreColors.alternate)),
      ),
    );
  }
}
