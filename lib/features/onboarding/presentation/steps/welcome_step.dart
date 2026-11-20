import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/core/glass.dart';
import 'package:xplore/core/xplore_wordmark.dart';
import 'package:xplore/features/onboarding/bloc/onboarding_cubit.dart';
import 'package:xplore/features/onboarding/presentation/widgets/onboarding_buttons.dart';
import 'package:xplore/features/onboarding/presentation/widgets/onboarding_map_art.dart';
import 'package:xplore/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:xplore/features/trip/presentation/join_by_link_sheet.dart';

// The hero gives up height to the copy and actions on short phones, but never
// shrinks below this; past that the whole screen scrolls instead.
const _minHeroHeight = 240.0;

// Pins sit on the stops of the map art's dotted route.
const _heroPins = [
  MapArtPin(
    alignment: Alignment(-0.6, 0.2),
    label: 'A',
    color: OnboardingAvatarColors.sand,
    labelColor: OnboardingAvatarColors.onSand,
  ),
  MapArtPin(
    alignment: Alignment(0.08, -0.2),
    label: 'S',
    color: OnboardingAvatarColors.blue,
    labelColor: OnboardingAvatarColors.onBlue,
  ),
  MapArtPin(
    alignment: Alignment(0.6, -0.56),
    label: 'P',
    color: OnboardingAvatarColors.coral,
    labelColor: OnboardingAvatarColors.onCoral,
  ),
];

/// The first onboarding screen: an illustrated map of a group on a trip, the
/// pitch, and the three ways in (plan a trip, join by link, sign in).
class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: XploreColors.background,
      body: CustomScrollView(
        // Clamped so the screen stays put when everything fits: the default iOS
        // physics would let it rubber-band even with nothing to scroll.
        physics: ClampingScrollPhysics(),
        slivers: [
          // Fills the screen so the hero can take whatever height the copy leaves,
          // and scrolls only when the copy alone outgrows it (large text sizes).
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _Hero()),
                _Pitch(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _minHeroHeight),
      child: Stack(
        children: [
          // The map art takes an explicit height; infinity lets it fill the hero's tight constraints.
          const Positioned.fill(
            child: OnboardingMapArt(height: double.infinity, borderRadius: 0, showRoute: true, pins: _heroPins),
          ),
          const Positioned.fill(child: _BottomFade()),
          Positioned(
            left: onboardingGutter,
            top: topInset + 14,
            child: Semantics(
              label: 'Xplore',
              child: const ExcludeSemantics(child: XploreWordmark()),
            ),
          ),
          Positioned(left: onboardingGutter, top: topInset + 64, child: const _PhotosCard()),
          const Positioned(right: onboardingGutter, bottom: paddingUnit, child: _UpNextCard()),
        ],
      ),
    );
  }
}

/// Fades the map into the black page over its lower part so the title reads cleanly.
class _BottomFade extends StatelessWidget {
  const _BottomFade();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.6, 1],
            colors: [XploreColors.background.withValues(alpha: 0), XploreColors.background],
          ),
        ),
      ),
    );
  }
}

/// Illustration only: a sample notification about new shared photos.
class _PhotosCard extends StatelessWidget {
  const _PhotosCard();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: 176,
        child: GlassSurface(
          strong: true,
          borderRadius: radiusMd,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: paddingUnit),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: XploreColors.accentSoft, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.photo_outlined, size: 18, color: XploreColors.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('12 new photos', maxLines: 1, style: XploreText.footnoteStrong),
                    Text(
                      'from Sam',
                      maxLines: 1,
                      style: XploreText.caption.copyWith(color: XploreColors.secondaryLabel),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Illustration only: a sample "up next" itinerary item.
class _UpNextCard extends StatelessWidget {
  const _UpNextCard();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: 198,
        child: GlassSurface(
          strong: true,
          borderRadius: radiusMd,
          padding: const EdgeInsets.symmetric(horizontal: paddingUnit + 4, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Text('UP NEXT · 14:30', style: XploreText.overline.copyWith(color: XploreColors.accent)),
              Text('Time Out Market', maxLines: 1, style: XploreText.bodyStrong.copyWith(fontWeight: FontWeight.w600)),
              Text(
                '8 min walk from you',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The title, supporting line and the three entry actions.
class _Pitch extends StatelessWidget {
  const _Pitch();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: paddingUnit * 2),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: onboardingGutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text('Trips are better together.', style: XploreText.display.copyWith(color: XploreColors.white)),
            ),
            const SizedBox(height: 14),
            Text(
              'Plan the days, find each other on the map and keep every photo in one place.',
              style: XploreText.body.copyWith(color: XploreColors.secondaryLabel),
            ),
            const SizedBox(height: 28),
            OnboardingPrimaryButton(label: 'Plan a trip', onPressed: cubit.startOrganizer),
            const SizedBox(height: paddingUnit),
            OnboardingSecondaryButton(
              label: 'I have an invite link',
              icon: Icons.link_rounded,
              onPressed: () => _joinWithLink(context),
            ),
            const SizedBox(height: 6),
            OnboardingTextButton(label: 'I already have an account', onPressed: cubit.startReturning),
          ],
        ),
      ),
    );
  }

  Future<void> _joinWithLink(BuildContext context) async {
    final cubit = context.read<OnboardingCubit>();
    final link = await pickInviteLink(context);
    if (link != null && !cubit.isClosed) {
      unawaited(cubit.startInvite(link));
    }
  }
}
