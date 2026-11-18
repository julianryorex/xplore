import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/features/trip/bloc/trip_creation_cubit.dart';
import 'package:xplore/features/trip/bloc/trip_creation_state.dart';
import 'package:xplore/features/trip/bloc/trip_cubit.dart';
import 'package:xplore/features/trip/presentation/create_trip/create_trip_messages.dart';
import 'package:xplore/features/trip/presentation/create_trip/create_trip_widgets.dart';
import 'package:xplore/features/trip/presentation/create_trip/plan_step.dart';
import 'package:xplore/features/trip/presentation/create_trip/route_map.dart';
import 'package:xplore/features/trip/presentation/create_trip/trip_ready_step.dart';
import 'package:xplore/features/trip/presentation/create_trip/when_step.dart';
import 'package:xplore/features/trip/presentation/create_trip/where_step.dart';
import 'package:xplore/features/trip/presentation/create_trip/who_and_vibe_step.dart';

const _stepTransition = Duration(milliseconds: 220);

/// The full-screen create-trip flow (FEAT-007): a header with close/back and
/// progress, the current step, and one primary button that explains itself
/// whenever it is disabled. Driven by the [TripCreationCubit] in context.
class CreateTripFlowPage extends StatelessWidget {
  const CreateTripFlowPage({this.mapSurfaceBuilder, super.key});

  /// Replaces the where step's Google Map in widget tests.
  final RouteMapSurfaceBuilder? mapSurfaceBuilder;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TripCreationCubit, TripCreationState>(
      buildWhen: (previous, current) =>
          previous.currentStep != current.currentStep ||
          previous.hasUnsavedInput != current.hasUnsavedInput ||
          previous.phase != current.phase,
      builder: (context, state) {
        return PopScope(
          // Leaving freely is only safe on the first step with nothing typed,
          // or once the trip exists. Anything else is routed through _onBack,
          // and nothing may pop mid-submit while TripCubit is still awaiting.
          canPop: state.phase == TripCreationPhase.submitted || (state.isFirstStep && !state.hasUnsavedInput),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              _onBack(context);
            }
          },
          child: Scaffold(
            backgroundColor: XploreColors.background,
            resizeToAvoidBottomInset: true,
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _FlowHeader(state: state, onLeading: () => _onBack(context)),
                  Expanded(
                    child: _StepBody(step: state.currentStep, mapSurfaceBuilder: mapSurfaceBuilder),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: state.currentStep == CreateTripStep.invite ? null : const _FlowBottomBar(),
          ),
        );
      },
    );
  }

  /// Back on a later step, close (with confirmation) on the first.
  Future<void> _onBack(BuildContext context) async {
    final cubit = context.read<TripCreationCubit>();
    final state = cubit.state;
    if (state.phase == TripCreationPhase.submitting) {
      return;
    }
    if (state.canGoBack) {
      cubit.back();
      return;
    }
    if (state.currentStep == CreateTripStep.invite || state.phase == TripCreationPhase.submitted) {
      return;
    }
    final navigator = Navigator.of(context);
    if (state.hasUnsavedInput && !await _confirmDiscard(context)) {
      return;
    }
    navigator.pop();
  }
}

Future<bool> _confirmDiscard(BuildContext context) async {
  final discard = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Discard this trip?'),
      content: const Text('The places and details you added will be lost.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Keep editing')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: XploreColors.error),
          child: const Text('Discard'),
        ),
      ],
    ),
  );
  return discard ?? false;
}

/// The steps counted in "STEP n OF 4" and the progress line; the invite step
/// comes after creation and is not part of building the trip.
List<CreateTripStep> _countedSteps(TripCreationState state) =>
    state.steps.where((step) => step != CreateTripStep.invite).toList();

class _FlowHeader extends StatelessWidget {
  const _FlowHeader({required this.state, required this.onLeading});

  final TripCreationState state;
  final VoidCallback onLeading;

  @override
  Widget build(BuildContext context) {
    if (state.currentStep == CreateTripStep.invite) {
      return const SizedBox(height: 14);
    }
    final counted = _countedSteps(state);
    final number = counted.indexOf(state.currentStep) + 1;
    final submitting = state.phase == TripCreationPhase.submitting;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              _CircleButton(
                icon: state.isFirstStep ? Icons.close_rounded : Icons.arrow_back_ios_new_rounded,
                label: state.isFirstStep ? 'Close' : 'Back',
                onTap: submitting ? null : onLeading,
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  'STEP $number OF ${counted.length}',
                  semanticsLabel: 'Step $number of ${counted.length}',
                  style: XploreText.overline.copyWith(color: XploreColors.secondaryLabel),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _ProgressLine(total: counted.length, reached: number),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        shape: const CircleBorder(side: BorderSide(color: XploreColors.raised)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: minTouchTarget,
            child: Icon(icon, size: 18, color: enabled ? XploreColors.white : XploreColors.tertiaryLabel),
          ),
        ),
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.total, required this.reached});

  final int total;
  final int reached;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : _stepTransition;
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: AnimatedContainer(
                duration: duration,
                height: 2,
                color: i < reached ? XploreColors.white : XploreColors.raised,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepBody extends StatelessWidget {
  const _StepBody({required this.step, required this.mapSurfaceBuilder});

  final CreateTripStep step;
  final RouteMapSurfaceBuilder? mapSurfaceBuilder;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : _stepTransition,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.015), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      // The default layout centres a short step vertically, so its title would move as content grows.
      layoutBuilder: (current, previous) =>
          Stack(fit: StackFit.expand, alignment: Alignment.topCenter, children: [...previous, ?current]),
      child: SingleChildScrollView(
        key: ValueKey(step),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(createStepGutter, 30, createStepGutter, 32),
        child: switch (step) {
          CreateTripStep.where => WhereStep(mapSurfaceBuilder: mapSurfaceBuilder),
          CreateTripStep.when => const WhenStep(),
          CreateTripStep.whoAndVibe => const WhoAndVibeStep(),
          CreateTripStep.plan => const PlanStep(),
          CreateTripStep.invite => const TripReadyStep(),
        },
      ),
    );
  }
}

/// The primary button, with the reason it is disabled shown above it.
class _FlowBottomBar extends StatelessWidget {
  const _FlowBottomBar();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TripCreationCubit>().state;
    final reason = advanceBlockerMessage(state);
    final isPlan = state.currentStep == CreateTripStep.plan;
    final submitting = state.phase == TripCreationPhase.submitting;
    final onPressed = !state.canAdvance
        ? null
        : isPlan
        ? () => _createTrip(context)
        : context.read<TripCreationCubit>().next;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : _stepTransition,
              alignment: Alignment.bottomCenter,
              child: reason == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          reason,
                          textAlign: TextAlign.center,
                          style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel),
                        ),
                      ),
                    ),
            ),
            _PrimaryButton(label: isPlan ? 'Create trip' : 'Continue', busy: submitting, onPressed: onPressed),
          ],
        ),
      ),
    );
  }

  /// Persists the draft through [TripCubit] with the plan's days, then moves on
  /// to the invite step; a failure keeps the user on the plan to retry.
  Future<void> _createTrip(BuildContext context) async {
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
      messenger.showSnackBar(const SnackBar(content: Text('Couldn’t create your trip. Please try again.')));
    }
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.busy, required this.onPressed});

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        child: busy
            ? Semantics(
                label: 'Creating your trip',
                child: const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: XploreColors.secondaryLabel),
                ),
              )
            : Text(label, style: XploreText.bodyStrong),
      ),
    );
  }
}
