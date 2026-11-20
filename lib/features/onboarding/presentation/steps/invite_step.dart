import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/features/auth/bloc/auth_cubit.dart';
import 'package:xplore/features/home/models/trip_overview.dart';
import 'package:xplore/features/onboarding/bloc/onboarding_cubit.dart';
import 'package:xplore/features/onboarding/presentation/widgets/dashed_circle.dart';
import 'package:xplore/features/onboarding/presentation/widgets/onboarding_buttons.dart';
import 'package:xplore/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:xplore/features/trip/presentation/trip_invite_sharer.dart';

/// Organizer step: asks the user to share an invite link to the trip that was
/// saved in the background after sign-in. Shows that save's progress, and a
/// retry through [onRetryTripSetup] when it failed.
class InviteStep extends StatefulWidget {
  const InviteStep({required this.onRetryTripSetup, super.key});

  /// Saves the organizer's trip again after a failed attempt.
  final Future<void> Function() onRetryTripSetup;

  @override
  State<InviteStep> createState() => _InviteStepState();
}

class _InviteStepState extends State<InviteStep> {
  bool _sharing = false;

  Future<void> _share(OnboardingState state) async {
    final cubit = context.read<OnboardingCubit>();
    setState(() => _sharing = true);
    try {
      await shareTripInvite(context, state.createdTrip!);
    } finally {
      if (mounted) {
        setState(() => _sharing = false);
      }
    }
    cubit.next();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();
    final state = context.watch<OnboardingCubit>().state;
    final failed = state.tripSetup == TripSetupStatus.failed;
    final saving = state.tripSetup == TripSetupStatus.idle || state.tripSetup == TripSetupStatus.creating;
    final placeName = state.destination?.name ?? 'Your trip';

    return OnboardingStepScaffold(
      skippable: true,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          if (failed)
            OnboardingPrimaryButton(label: 'Try again', onPressed: widget.onRetryTripSetup)
          else
            OnboardingPrimaryButton(
              label: 'Share invite link',
              icon: Icons.ios_share_rounded,
              loading: saving || _sharing,
              onPressed: () => _share(state),
            ),
          OnboardingTextButton(label: 'I’ll do this later', onPressed: _sharing ? null : cubit.skip),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          switch (state.tripSetup) {
            TripSetupStatus.failed => const _SaveFailedLine(),
            TripSetupStatus.created => _StatusPill(label: '$placeName is saved', saved: true),
            TripSetupStatus.idle || TripSetupStatus.creating => const _StatusPill(label: 'Saving your trip…'),
          },
          const SizedBox(height: 14),
          const OnboardingHeading(
            title: 'Now bring your group',
            subtitle: 'Send one link. Friends tap it and they’re in the trip with you.',
          ),
          const SizedBox(height: 28),
          _TripCard(title: state.createdTrip?.title ?? placeName, dates: _datesLabel(state.startDate, state.endDate)),
          const SizedBox(height: 20),
          const _CheckRow(label: 'Everyone sees the same plan'),
          const SizedBox(height: 14),
          const _CheckRow(label: 'Photos from every phone in one gallery'),
        ],
      ),
    );
  }
}

/// "Jun 3 – 9", "Jun 28 – Jul 3", or "Dates flexible" without exact dates.
String _datesLabel(DateTime? start, DateTime? end) {
  if (start == null || end == null) {
    return 'Dates flexible';
  }
  if (start == end) {
    return formatMonthDay(start);
  }
  final sameMonth = start.year == end.year && start.month == end.month;
  return '${formatMonthDay(start)} – ${sameMonth ? end.day : formatMonthDay(end)}';
}

/// The soft Jade pill above the title: a check once saved, a spinner while saving.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, this.saved = false});

  final String label;
  final bool saved;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        height: 28,
        padding: const EdgeInsets.only(left: 8, right: 12),
        decoration: BoxDecoration(color: XploreColors.accentSoft, borderRadius: BorderRadius.circular(14)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            if (saved)
              const Icon(Icons.check_rounded, size: 16, color: XploreColors.accent)
            else
              const SizedBox.square(
                dimension: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: XploreColors.accent),
              ),
            Text(label, style: XploreText.footnoteStrong.copyWith(color: XploreColors.accent)),
          ],
        ),
      ),
    );
  }
}

class _SaveFailedLine extends StatelessWidget {
  const _SaveFailedLine();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.error_outline_rounded, size: 16, color: XploreColors.error),
          ),
          Expanded(
            child: Text(
              'Couldn’t save your trip. Check your connection and try again.',
              style: XploreText.footnote.copyWith(color: XploreColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

/// The trip as the group will see it: name, dates, head count and member slots.
class _TripCard extends StatelessWidget {
  const _TripCard({required this.title, required this.dates});

  final String title;
  final String dates;

  // Bespoke size: the card's trip name sits between the step title and a row title.
  static const _titleStyle = TextStyle(
    fontFamily: systemFontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -0.5,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: XploreColors.card, borderRadius: BorderRadius.circular(radiusLg)),
      child: Row(
        spacing: paddingUnit,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 3,
              children: [
                Text(title, style: _titleStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('$dates · 1 going', style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel)),
              ],
            ),
          ),
          const _MemberSlots(),
        ],
      ),
    );
  }
}

/// The user's avatar overlapping three dashed slots for the friends to come.
class _MemberSlots extends StatelessWidget {
  const _MemberSlots();

  static const _size = 40.0;
  static const _overlap = 8.0;
  static const _emptySlots = 3;

  @override
  Widget build(BuildContext context) {
    final name = context.select(
      (AuthCubit cubit) => switch (cubit.state) {
        AuthAuthenticated(:final displayName) => displayName.trim(),
        _ => '',
      },
    );

    const step = _size - _overlap;
    return SizedBox(
      width: _size + step * _emptySlots,
      height: _size,
      child: Stack(
        children: [
          Semantics(
            label: 'You',
            child: ExcludeSemantics(
              child: _OwnAvatar(name: name, size: _size),
            ),
          ),
          for (var slot = 1; slot <= _emptySlots; slot++)
            Positioned(
              left: step * slot,
              child: _EmptySlot(size: _size, showPlus: slot == _emptySlots),
            ),
        ],
      ),
    );
  }
}

class _OwnAvatar extends StatelessWidget {
  const _OwnAvatar({required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: XploreColors.raised,
        shape: BoxShape.circle,
        border: Border.all(color: XploreColors.accent, width: 2),
      ),
      child: name.isEmpty
          ? const Icon(Icons.person_rounded, size: 20, color: XploreColors.white)
          : Text(
              name.characters.first.toUpperCase(),
              style: XploreText.bodyStrong.copyWith(fontWeight: FontWeight.w600),
            ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.size, required this.showPlus});

  final double size;
  final bool showPlus;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: DashedCircle(
        size: size,
        color: XploreColors.tertiaryLabel,
        fillColor: XploreColors.card,
        strokeWidth: 1.5,
        child: showPlus ? const Icon(Icons.add_rounded, size: 16, color: XploreColors.secondaryLabel) : null,
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: paddingUnit,
      children: [
        const Icon(Icons.check_rounded, size: 20, color: XploreColors.accent),
        Expanded(
          child: Text(label, style: XploreText.body.copyWith(color: XploreColors.inactiveControl)),
        ),
      ],
    );
  }
}
