import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/features/auth/bloc/auth_cubit.dart';
import 'package:xplore/features/onboarding/bloc/onboarding_cubit.dart';
import 'package:xplore/features/onboarding/presentation/steps/destination_step.dart';
import 'package:xplore/features/onboarding/presentation/steps/invite_step.dart';
import 'package:xplore/features/onboarding/presentation/steps/invite_welcome_step.dart';
import 'package:xplore/features/onboarding/presentation/steps/location_step.dart';
import 'package:xplore/features/onboarding/presentation/steps/profile_step.dart';
import 'package:xplore/features/onboarding/presentation/steps/sign_in_step.dart';
import 'package:xplore/features/onboarding/presentation/steps/welcome_step.dart';
import 'package:xplore/features/trip/bloc/trip_cubit.dart';
import 'package:xplore/features/trip/services/stub_plan_builder.dart';

/// Hosts the onboarding flow (FEAT-005) as one page that swaps its step in
/// place, so the auth gate's route reset on sign-in cannot drop the user out
/// of the steps that follow it.
///
/// It also does the cross-cubit wiring the [OnboardingCubit] may not: moving
/// past sign-in once authenticated, and saving the organizer's trip.
class OnboardingFlowPage extends StatefulWidget {
  const OnboardingFlowPage({super.key});

  @override
  State<OnboardingFlowPage> createState() => _OnboardingFlowPageState();
}

class _OnboardingFlowPageState extends State<OnboardingFlowPage> {
  void _onAuthenticated() {
    final onboarding = context.read<OnboardingCubit>();
    final signedInFromFlow = onboarding.state.step == OnboardingStep.signIn;
    onboarding.onAuthenticated();
    if (signedInFromFlow && onboarding.state.path == OnboardingPath.organizer) {
      unawaited(_createTrip());
    }
  }

  /// Saves the trip the organizer described before signing in. Runs while they
  /// are on the profile step, so the invite step usually finds it ready.
  Future<void> _createTrip() async {
    final onboarding = context.read<OnboardingCubit>();
    final draft = onboarding.state.tripDraft;
    if (draft == null || onboarding.state.tripSetup == TripSetupStatus.creating) {
      return;
    }

    final tripCubit = context.read<TripCubit>();
    onboarding.tripSetupStarted();
    try {
      final trip = await tripCubit.createTripFromDraft(draft, itinerary: buildStubPlan(draft).days);
      onboarding.tripCreated(trip);
    } catch (_) {
      onboarding.tripSetupFailed();
    }
  }

  Widget _stepView(OnboardingState state) {
    return switch (state.step) {
      OnboardingStep.welcome => state.path == OnboardingPath.invitee ? const InviteWelcomeStep() : const WelcomeStep(),
      OnboardingStep.destination => const DestinationStep(),
      OnboardingStep.signIn => const SignInStep(),
      OnboardingStep.profile => const ProfileStep(),
      OnboardingStep.invite => InviteStep(onRetryTripSetup: _createTrip),
      OnboardingStep.location => const LocationStep(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (previous, current) => previous is! AuthAuthenticated && current is AuthAuthenticated,
      listener: (_, _) => _onAuthenticated(),
      child: BlocBuilder<OnboardingCubit, OnboardingState>(
        buildWhen: (previous, current) => previous.step != current.step || previous.path != current.path,
        builder: (context, state) {
          return PopScope(
            canPop: !state.canGoBack,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) context.read<OnboardingCubit>().back();
            },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: KeyedSubtree(key: ValueKey((state.path, state.step)), child: _stepView(state)),
            ),
          );
        },
      ),
    );
  }
}
