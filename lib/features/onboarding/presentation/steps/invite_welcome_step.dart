import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/core/xplore_wordmark.dart';
import 'package:xplore/features/onboarding/bloc/onboarding_cubit.dart';
import 'package:xplore/features/onboarding/presentation/widgets/onboarding_buttons.dart';
import 'package:xplore/features/onboarding/presentation/widgets/onboarding_labels.dart';
import 'package:xplore/features/onboarding/presentation/widgets/onboarding_map_art.dart';
import 'package:xplore/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:xplore/features/trip/models/trip_invite.dart';

// Shown when the trip title cannot be loaded before sign-in.
const _fallbackTitle = 'You’re invited to a trip';

const _mapHeight = 170.0;

// Unlabelled: nothing about the members is readable before sign-in, so the
// pins only suggest a group on the route.
const _mapPins = [
  MapArtPin(alignment: Alignment(-0.6, 0.2), color: OnboardingAvatarColors.sand),
  MapArtPin(alignment: Alignment(0.08, -0.2), color: OnboardingAvatarColors.blue),
  MapArtPin(alignment: Alignment(0.6, -0.56), color: OnboardingAvatarColors.coral),
];

/// The invitee's first screen: the trip they were invited to (as far as the
/// invite preview tells before sign-in), with a way to join or back out.
class InviteWelcomeStep extends StatelessWidget {
  const InviteWelcomeStep({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();
    final status = context.select((OnboardingCubit cubit) => cubit.state.invitePreviewStatus);
    final invite = context.select((OnboardingCubit cubit) => cubit.state.invitePreview);

    return Scaffold(
      backgroundColor: XploreColors.background,
      body: SafeArea(
        minimum: const EdgeInsets.only(bottom: paddingUnit * 2),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: onboardingGutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 14, bottom: paddingUnit * 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        label: 'Xplore',
                        child: const ExcludeSemantics(child: XploreWordmark()),
                      ),
                      const SizedBox(height: 44),
                      Text('YOU’RE INVITED', style: XploreText.overline.copyWith(color: XploreColors.accent)),
                      const SizedBox(height: paddingUnit),
                      _TripTitle(status: status, invite: invite),
                      const SizedBox(height: 28),
                      _TripCard(invite: status == InvitePreviewStatus.ready ? invite : null),
                    ],
                  ),
                ),
              ),
              OnboardingPrimaryButton(label: 'Join the trip', onPressed: cubit.next),
              const SizedBox(height: 6),
              OnboardingTextButton(label: 'Not now', onPressed: cubit.reset),
            ],
          ),
        ),
      ),
    );
  }
}

class _TripTitle extends StatelessWidget {
  const _TripTitle({required this.status, required this.invite});

  final InvitePreviewStatus status;
  final TripInvite? invite;

  @override
  Widget build(BuildContext context) {
    if (status == InvitePreviewStatus.loading) {
      return const _TitlePlaceholder();
    }

    final tripTitle = invite?.tripTitle.trim() ?? '';
    final title = status == InvitePreviewStatus.ready && tripTitle.isNotEmpty ? tripTitle : _fallbackTitle;
    return Semantics(
      header: true,
      child: Text(title, style: XploreText.display.copyWith(color: XploreColors.white)),
    );
  }
}

/// A muted bar the height of one title line, held while the preview loads so
/// the layout does not jump when the title arrives.
class _TitlePlaceholder extends StatelessWidget {
  const _TitlePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading trip',
      child: FractionallySizedBox(
        widthFactor: 0.7,
        child: Container(
          // XploreText.display has a line height of 1.
          height: XploreText.display.fontSize,
          decoration: BoxDecoration(color: XploreColors.card, borderRadius: BorderRadius.circular(radiusSm)),
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.invite});

  /// The loaded preview, or null when it is loading or unavailable.
  final TripInvite? invite;

  @override
  Widget build(BuildContext context) {
    final memberCount = invite?.memberCount ?? 0;
    final dates = tripDatesLabel(invite?.startDate, invite?.endDate);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radiusLg),
      child: ColoredBox(
        color: XploreColors.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const OnboardingMapArt(height: _mapHeight, borderRadius: 0, showRoute: true, pins: _mapPins),
            if (memberCount > 0 || dates != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  spacing: 10,
                  children: [
                    if (dates != null) _CardRow(icon: Icons.calendar_today_rounded, label: dates),
                    if (memberCount > 0)
                      _CardRow(
                        icon: Icons.group_rounded,
                        label: memberCount == 1 ? '1 person going' : '$memberCount people going',
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 10,
      children: [
        Icon(icon, size: 20, color: XploreColors.accent),
        Expanded(
          child: Text(label, style: XploreText.bodyStrong.copyWith(color: XploreColors.white)),
        ),
      ],
    );
  }
}
