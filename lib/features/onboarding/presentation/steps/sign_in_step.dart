import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/core/xplore_wordmark.dart';
import 'package:xplore/features/auth/presentation/sign_in_buttons.dart';
import 'package:xplore/features/home/models/trip_overview.dart';
import 'package:xplore/features/onboarding/bloc/onboarding_cubit.dart';
import 'package:xplore/features/onboarding/presentation/widgets/dashed_circle.dart';
import 'package:xplore/features/onboarding/presentation/widgets/onboarding_buttons.dart';
import 'package:xplore/features/onboarding/presentation/widgets/onboarding_map_art.dart';
import 'package:xplore/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:xplore/features/trip/data/place_catalog.dart';
import 'package:xplore/features/trip/models/nights_allocation.dart';
import 'package:xplore/features/trip/models/trip_invite.dart';

/// The onboarding sign-in screen. Its header depends on the path: the
/// organizer sees the trip they are about to save, the invitee the trip they
/// are joining, and a returning user a plain welcome back. It never navigates
/// on success; the flow page moves on once [AuthCubit] reports a user.
class SignInStep extends StatelessWidget {
  const SignInStep({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<OnboardingCubit>().state;
    final isReturning = state.path == OnboardingPath.returning;
    final startOrganizer = context.read<OnboardingCubit>().startOrganizer;

    return OnboardingStepScaffold(
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SignInButtons(),
          if (isReturning) ...[
            const SizedBox(height: 6),
            OnboardingTextButton(label: 'New here? Plan a trip', onPressed: startOrganizer),
          ],
        ],
      ),
      child: switch (state.path) {
        OnboardingPath.organizer => _OrganizerHeader(state: state),
        OnboardingPath.invitee => _InviteeHeader(preview: state.invitePreview),
        OnboardingPath.returning => const _ReturningHeader(),
      },
    );
  }
}

class _OrganizerHeader extends StatelessWidget {
  const _OrganizerHeader({required this.state});

  final OnboardingState state;

  @override
  Widget build(BuildContext context) {
    final place = state.destination;
    final placeName = place?.name ?? 'your trip';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (place != null) ...[
          const SizedBox(height: paddingUnit + 4),
          _TripCard(place: place, dateLine: _dateLine(state)),
          const SizedBox(height: paddingUnit * 8 / 3),
        ],
        OnboardingHeading(
          title: 'Save your trip',
          subtitle: 'Sign in to keep $placeName and invite your group. It takes a few seconds.',
        ),
      ],
    );
  }

  /// "Jun 3 – 9 · 7 days", "Jun 30 – Jul 2 · 3 days" or "Dates flexible".
  static String _dateLine(OnboardingState state) {
    final start = state.startDate;
    final end = state.endDate;
    if (start == null || end == null) {
      return 'Dates flexible';
    }
    final sameMonth = start.year == end.year && start.month == end.month;
    final rangeEnd = sameMonth ? '${end.day}' : formatMonthDay(end);
    final range = '${formatMonthDay(start)} – $rangeEnd';
    final days = nightsBetween(start, end) + 1;
    return '$range · $days ${days == 1 ? 'day' : 'days'}';
  }
}

/// The trip the organizer described, shown as the thing sign-in will save.
class _TripCard extends StatelessWidget {
  const _TripCard({required this.place, required this.dateLine});

  final CatalogPlace place;
  final String dateLine;

  static const _mapHeight = 150.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: XploreColors.card, borderRadius: BorderRadius.circular(radiusLg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Stack(
            alignment: Alignment.center,
            children: [
              OnboardingMapArt(height: _mapHeight, highlight: Alignment.center, borderRadius: 0),
              _DestinationDot(),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, paddingUnit + 4, 18, 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        // Bespoke size: a card title sits between the step title and section headings.
                        style: XploreText.title.copyWith(fontSize: 24, letterSpacing: -0.7, color: XploreColors.white),
                      ),
                      const SizedBox(height: 3),
                      Text(dateLine, style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel)),
                    ],
                  ),
                ),
                const SizedBox(width: paddingUnit),
                const _ReadyPill(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The solid Jade pin at the centre of the map's highlight halo.
class _DestinationDot extends StatelessWidget {
  const _DestinationDot();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 18,
        height: 18,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: XploreColors.accent, shape: BoxShape.circle),
        child: Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(color: XploreColors.onAccent, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _ReadyPill extends StatelessWidget {
  const _ReadyPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: paddingUnit),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: XploreColors.accentSoft, borderRadius: BorderRadius.circular(14)),
      child: Text('Ready to save', style: XploreText.footnoteStrong.copyWith(color: XploreColors.accent)),
    );
  }
}

class _InviteeHeader extends StatelessWidget {
  const _InviteeHeader({required this.preview});

  final TripInvite? preview;

  @override
  Widget build(BuildContext context) {
    final tripTitle = preview?.tripTitle.trim() ?? '';
    final memberCount = preview?.memberCount ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: paddingUnit * 8 / 3),
        const _YourSlot(),
        const SizedBox(height: 28),
        OnboardingHeading(
          title: tripTitle.isEmpty ? 'Sign in to join the trip' : 'Sign in to join $tripTitle',
          subtitle: _subtitle(memberCount),
        ),
      ],
    );
  }

  static String _subtitle(int memberCount) {
    if (memberCount <= 0) {
      return 'Sign in so the group knows it’s you.';
    }
    final people = memberCount == 1 ? '1 person is' : '$memberCount people are';
    return '$people already in. Sign in so they know it’s you.';
  }
}

/// The empty, dashed "You" spot waiting for the invitee in the group. The
/// members' own avatars are not readable before sign-in, so only this shows.
class _YourSlot extends StatelessWidget {
  const _YourSlot();

  static const _size = 64.0;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: DashedCircle(
        size: _size,
        child: Text('You', style: XploreText.footnoteStrong.copyWith(color: XploreColors.accent)),
      ),
    );
  }
}

class _ReturningHeader extends StatelessWidget {
  const _ReturningHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: paddingUnit * 8),
        const XploreWordmark(),
        const SizedBox(height: 20),
        Text('Welcome back.', style: XploreText.display.copyWith(color: XploreColors.white)),
        const SizedBox(height: 14),
        Text(
          'Sign in the same way as before and your trips, photos and group will be right where you left them.',
          style: XploreText.body.copyWith(color: XploreColors.secondaryLabel),
        ),
      ],
    );
  }
}
