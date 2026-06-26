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
    return Scaffold(
      backgroundColor: XploreColors.primaryBg,
      resizeToAvoidBottomInset: true,
      body: AmbientBackground(
        child: SafeArea(
          child: BlocBuilder<TripCreationCubit, TripCreationState>(
            builder: (context, state) {
              return Column(
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
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _stepBody(CreateTripStep step) {
    return switch (step) {
      CreateTripStep.destination => const DestinationStep(),
      CreateTripStep.dates => const DatesStep(),
      CreateTripStep.group => const GroupStep(),
      CreateTripStep.vibe => const VibeStep(),
      CreateTripStep.generate => const GenerateReviewStep(),
      CreateTripStep.finishing => const FinishingStep(),
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
    final canGoBack = !state.isFirstStep && state.phase != TripCreationPhase.submitted;

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
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.close_rounded, color: XploreColors.white),
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
      case CreateTripStep.generate:
        return _generateActions(context, cubit);
      case CreateTripStep.finishing:
        return _PrimaryButton(
          label: 'Create trip',
          busy: state.phase == TripCreationPhase.submitting,
          onPressed: onSubmit,
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

  Widget _generateActions(BuildContext context, TripCreationCubit cubit) {
    return switch (state.phase) {
      TripCreationPhase.generating => const _PrimaryButton(label: 'Generating…', busy: true, onPressed: null),
      TripCreationPhase.generated || TripCreationPhase.submitting || TripCreationPhase.submitted => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PrimaryButton(label: 'Looks good — continue', onPressed: cubit.next),
          TextButton(
            onPressed: cubit.generate,
            child: Text('Regenerate', style: context.pText.labelMedium?.copyWith(color: XploreColors.subtleText)),
          ),
        ],
      ),
      _ => _PrimaryButton(label: 'Generate itinerary', icon: Icons.auto_awesome_rounded, onPressed: cubit.generate),
    };
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, this.onPressed, this.busy = false, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
        child: busy
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: paddingUnit * 0.5)],
                  Text(label),
                ],
              ),
      ),
    );
  }
}
