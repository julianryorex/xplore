import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/features/onboarding/bloc/onboarding_cubit.dart';

/// Horizontal page margin shared by every onboarding screen.
const onboardingGutter = paddingUnit * 2;

/// The page frame for an onboarding step: a top bar (back, progress, skip), a
/// scrolling body and a footer pinned above the bottom safe area.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    required this.child,
    this.footer,
    this.onBack,
    this.onSkip,
    this.progressCurrent = 0,
    this.progressTotal = 0,
    super.key,
  });

  final Widget child;

  /// The step's actions, pinned to the bottom.
  final Widget? footer;

  /// Shows the back button when set.
  final VoidCallback? onBack;

  /// Shows "Skip" when set.
  final VoidCallback? onSkip;

  /// The progress bar fills [progressCurrent] of [progressTotal] segments; it
  /// is hidden when there are fewer than two.
  final int progressCurrent;
  final int progressTotal;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XploreColors.background,
      body: SafeArea(
        minimum: const EdgeInsets.only(bottom: paddingUnit * 2),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: onboardingGutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(onBack: onBack, onSkip: onSkip, current: progressCurrent, total: progressTotal),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: paddingUnit * 2),
                  child: child,
                ),
              ),
              ?footer,
            ],
          ),
        ),
      ),
    );
  }
}

/// An [OnboardingScaffold] wired to the [OnboardingCubit]: back and progress
/// follow the flow's state, and [skippable] adds a "Skip" that moves on.
class OnboardingStepScaffold extends StatelessWidget {
  const OnboardingStepScaffold({required this.child, this.footer, this.skippable = false, super.key});

  final Widget child;
  final Widget? footer;
  final bool skippable;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();
    final state = context.watch<OnboardingCubit>().state;

    return OnboardingScaffold(
      onBack: state.canGoBack ? cubit.back : null,
      onSkip: skippable ? cubit.skip : null,
      progressCurrent: state.progressCurrent,
      progressTotal: state.progressTotal,
      footer: footer,
      child: child,
    );
  }
}

/// A step's title with an optional supporting line under it.
class OnboardingHeading extends StatelessWidget {
  const OnboardingHeading({required this.title, this.subtitle, super.key});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: XploreText.title.copyWith(color: XploreColors.white)),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 10),
          Text(subtitle!, style: XploreText.body.copyWith(color: XploreColors.secondaryLabel)),
        ],
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack, required this.onSkip, required this.current, required this.total});

  final VoidCallback? onBack;
  final VoidCallback? onSkip;
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: minTouchTarget,
      child: Row(
        children: [
          // Pulled into the gutter so the chevron's glyph, not its tap target, aligns with the content.
          Transform.translate(
            offset: const Offset(-paddingUnit, 0),
            child: SizedBox.square(
              dimension: minTouchTarget,
              child: onBack == null
                  ? null
                  : IconButton(
                      onPressed: onBack,
                      tooltip: 'Back',
                      icon: const Icon(Icons.chevron_left_rounded, size: 28, color: XploreColors.white),
                    ),
            ),
          ),
          Expanded(
            // A single step has no progress to show.
            child: total < 2 ? const SizedBox.shrink() : _ProgressBar(current: current, total: total),
          ),
          SizedBox(
            width: minTouchTarget + paddingUnit,
            height: minTouchTarget,
            child: onSkip == null
                ? null
                : TextButton(
                    onPressed: onSkip,
                    style: TextButton.styleFrom(
                      foregroundColor: XploreColors.secondaryLabel,
                      padding: EdgeInsets.zero,
                      textStyle: XploreText.body,
                    ),
                    child: const Text('Skip'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step $current of $total',
      child: Row(
        spacing: 6,
        children: [
          for (var segment = 1; segment <= total; segment++)
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 4,
                decoration: BoxDecoration(
                  color: segment <= current ? XploreColors.accent : XploreColors.raised,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
