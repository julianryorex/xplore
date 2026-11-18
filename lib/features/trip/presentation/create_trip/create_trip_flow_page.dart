import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/core/ambient_background.dart';
import 'package:xplore/features/trip/bloc/trip_creation_cubit.dart';
import 'package:xplore/features/trip/bloc/trip_creation_state.dart';
import 'package:xplore/features/trip/bloc/trip_cubit.dart';
import 'package:xplore/features/trip/presentation/create_trip/create_trip_review_steps.dart';
import 'package:xplore/features/trip/presentation/create_trip/create_trip_steps.dart';

/// Full-screen, onboarding-style trip creation flow (FEAT-007). The flow is
/// driven entirely by [TripCreationCubit]'s ordered step list, so reordering or
/// adding a bucket is a change to that list rather than this page.
class CreateTripFlowPage extends StatelessWidget {
  const CreateTripFlowPage({super.key});

  Future<void> _submit(BuildContext context) async {
    final creation = context.read<TripCreationCubit>();
    final tripCubit = context.read<TripCubit>();
    final messenger = ScaffoldMessenger.of(context);

    creation.markSubmitting();
    try {
      final trip = await tripCubit.createTripFromDraft(creation.state.draft, itinerary: creation.state.itinerary);
      creation.markCreated(trip);
      creation.next();
    } catch (_) {
      creation.markSubmitFailed();
      messenger.showSnackBar(const SnackBar(content: Text('Couldn\u2019t create your trip. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TripCreationCubit, TripCreationState>(
      builder: (context, state) {
        // Block leaving the flow while an itinerary is generating or a trip is
        // being created: popping mid-await would dispose the cubit/context while
        // the in-flight work is still running. This covers the system back
        // gesture and predictive back, not just our close button.
        final isBusy = state.phase == TripCreationPhase.submitting;

        return PopScope(
          canPop: !isBusy,
          child: Scaffold(
            backgroundColor: XploreColors.primaryBg,
            resizeToAvoidBottomInset: true,
            body: AmbientBackground(
              child: SafeArea(
                child: Column(
                  children: [
                    _FlowTopBar(state: state),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero).animate(animation),
                            child: child,
                          ),
                        ),
                        child: SingleChildScrollView(
                          key: ValueKey(state.currentStep),
                          padding: const EdgeInsets.fromLTRB(
                            paddingUnit * 1.5,
                            paddingUnit,
                            paddingUnit * 1.5,
                            paddingUnit * 2,
                          ),
                          child: _stepBody(state.currentStep),
                        ),
                      ),
                    ),
                    _FlowBottomBar(state: state, onSubmit: () => _submit(context)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _stepBody(CreateTripStep step) {
    return switch (step) {
      // TEMPORARY: the old 7-step screens mapped onto the new 4 steps until the
      // redesigned screens replace this folder.
      CreateTripStep.where => const DestinationStep(),
      CreateTripStep.when => const DatesStep(),
      CreateTripStep.whoAndVibe => const Column(
        children: [
          GroupStep(),
          SizedBox(height: paddingUnit * 2),
          VibeStep(),
        ],
      ),
      CreateTripStep.plan => const Column(
        children: [
          GenerateReviewStep(),
          SizedBox(height: paddingUnit * 2),
          FinishingStep(),
        ],
      ),
      CreateTripStep.invite => const InviteStep(),
    };
  }
}

class _FlowTopBar extends StatelessWidget {
  const _FlowTopBar({required this.state});

  final TripCreationState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TripCreationCubit>();
    // Once the trip exists (invite step), there's nothing to go back to.
    final canGoBack = state.canGoBack;
    // Closing mid-generation/submit would dispose the flow while an await is in
    // flight; block it until the in-flight work settles.
    final isBusy = state.phase == TripCreationPhase.submitting;

    return Padding(
      padding: const EdgeInsets.fromLTRB(paddingUnit, paddingUnit * 0.5, paddingUnit, paddingUnit * 0.5),
      child: Row(
        children: [
          IconButton(
            onPressed: canGoBack ? cubit.back : null,
            icon: Icon(Icons.arrow_back_rounded, color: canGoBack ? XploreColors.white : Colors.transparent),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: state.progress),
                duration: const Duration(milliseconds: 300),
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 5,
                  backgroundColor: XploreColors.white.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation(XploreColors.alternate),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: isBusy ? null : () => Navigator.of(context).maybePop(),
            icon: Icon(
              Icons.close_rounded,
              color: isBusy ? XploreColors.white.withValues(alpha: 0.3) : XploreColors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowBottomBar extends StatelessWidget {
  const _FlowBottomBar({required this.state, required this.onSubmit});

  final TripCreationState state;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TripCreationCubit>();

    return Container(
      padding: EdgeInsets.fromLTRB(
        paddingUnit * 1.5,
        paddingUnit,
        paddingUnit * 1.5,
        MediaQuery.viewPaddingOf(context).bottom + paddingUnit,
      ),
      decoration: BoxDecoration(
        color: XploreColors.primaryBg.withValues(alpha: 0.6),
        border: Border(top: BorderSide(color: XploreColors.divider)),
      ),
      child: _buildActions(context, cubit),
    );
  }

  Widget _buildActions(BuildContext context, TripCreationCubit cubit) {
    switch (state.currentStep) {
      case CreateTripStep.plan:
        return _PrimaryButton(
          label: 'Create trip',
          busy: state.phase == TripCreationPhase.submitting,
          onPressed: state.canAdvance ? onSubmit : null,
        );
      case CreateTripStep.invite:
        return _PrimaryButton(label: 'Done', onPressed: () => Navigator.of(context).maybePop());
      default:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PrimaryButton(label: 'Continue', onPressed: state.canAdvance ? cubit.next : null),
            if (state.currentStep.isSkippable)
              TextButton(
                onPressed: cubit.next,
                child: Text('Skip for now', style: context.pText.labelMedium?.copyWith(color: XploreColors.subtleText)),
              ),
          ],
        );
    }
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, this.onPressed, this.busy = false});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
        child: busy
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
            : Text(label),
      ),
    );
  }
}
