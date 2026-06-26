import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/core/ambient_background.dart';
import 'package:xplore/core/error_state.dart';
import 'package:xplore/core/glass.dart';
import 'package:xplore/core/header.dart';
import 'package:xplore/core/section_header.dart';
import 'package:xplore/features/auth/services/auth_service.dart';
import 'package:xplore/features/itinerary/bloc/itinerary_cubit.dart';
import 'package:xplore/features/itinerary/widgets/itinerary_card.dart';
import 'package:xplore/features/profile/bloc/profile_cubit.dart';
import 'package:xplore/features/trip/bloc/trip_cubit.dart';
import 'package:xplore/features/trip/bloc/trip_state.dart';
import 'package:xplore/features/trip/models/trip_model.dart';
import 'package:xplore/features/trip/services/trip_service.dart';
import 'package:xplore/routes.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _openCreateTripFlow(BuildContext context) => context.push(Paths.createTrip);

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final topInset = viewPadding.top;
    final bottomClearance = viewPadding.bottom + navBarHeight;
    const headerTopGap = paddingUnit * 0.75;
    final headerZone = topInset + headerTopGap + Header.padding;

    return AmbientBackground(
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.only(
              left: paddingUnit * 1.5,
              right: paddingUnit * 1.5,
              top: headerZone + paddingUnit * 0.5,
              bottom: bottomClearance,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(title: 'Your trip', actionLabel: 'New', onAction: () => _openCreateTripFlow(context)),
                const SizedBox(height: paddingUnit),
                _TripHero(onCreateTrip: () => _openCreateTripFlow(context)),
                const SizedBox(height: paddingUnit * 2),

                //! Daily Plans Section
                const SectionHeader(title: 'Daily plans'),
                const SizedBox(height: paddingUnit),
                BlocBuilder<ItineraryCubit, ItineraryStates>(
                  builder: (context, state) {
                    return switch (state) {
                      InitialItineraryState() || LoadingItineraryState() => const SizedBox(
                        height: 300,
                        width: 230,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      EmptyItineraryState() => const _ItineraryPlaceholder(
                        message: 'Create or open a trip to see its daily plans here.',
                      ),
                      ErrorItineraryState() => ErrorState(
                        title: 'Unable to load itinerary',
                        message: 'Something went wrong. Please try again later',
                        onRetry: () => context.read<ItineraryCubit>().retry(),
                      ),
                      LoadedItineraryState(:final itinerary) when itinerary.dailyPlans.isEmpty =>
                        const _ItineraryPlaceholder(
                          message: 'No plans yet. Days and stops will appear here once added.',
                        ),
                      LoadedItineraryState(:final itinerary) => SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ...itinerary.dailyPlans.map(
                              (dailyPlan) => Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: SizedBox(
                                  width: ItineraryCard.width,
                                  height: ItineraryCard.height,
                                  child: ItineraryCard(dailyPlan: dailyPlan),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    };
                  },
                ),
                const SizedBox(height: paddingUnit * 2),

                //! Gallery Section
                const SectionHeader(title: 'Gallery'),
                const SizedBox(height: paddingUnit),
                GlassSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(paddingUnit * 0.75),
                            decoration: BoxDecoration(
                              color: XploreColors.alternate.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(radiusSm),
                              border: Border.all(color: XploreColors.alternate.withValues(alpha: 0.32)),
                            ),
                            child: Icon(Icons.photo_library_outlined, size: 22, color: XploreColors.alternate),
                          ),
                          const SizedBox(width: paddingUnit),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Shared gallery', style: context.pText.labelLarge),
                                const SizedBox(height: 2),
                                Text(
                                  'Keep every trip moment in one place.',
                                  style: context.pText.bodySmall?.copyWith(color: XploreColors.mutedText),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: paddingUnit * 1.25),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => context.push(Paths.gallery),
                          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                          label: const Text('View gallery'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: headerZone + paddingUnit * 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      XploreColors.primaryBg,
                      XploreColors.primaryBg,
                      XploreColors.primaryBg.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.6, 1],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: topInset + headerTopGap,
            left: 0,
            right: 0,
            child: Header(
              leadingWidget: const _ProfileAvatarButton(),
              titleWidget: const _HomeGreeting(),
              trailingWidget: GlassIconButton(
                size: 44,
                iconSize: 22,
                icon: Icons.notifications_none_rounded,
                onTap: () => context.push(Paths.notifications),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItineraryPlaceholder extends StatelessWidget {
  const _ItineraryPlaceholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      child: Row(
        children: [
          Icon(Icons.event_note_outlined, color: XploreColors.alternate),
          const SizedBox(width: paddingUnit),
          Expanded(
            child: Text(message, style: context.pText.bodySmall?.copyWith(color: XploreColors.mutedText)),
          ),
        ],
      ),
    );
  }
}

/// Switches between the empty-state "plan a trip" prompt and the hero card for
/// the active trip.
class _TripHero extends StatelessWidget {
  const _TripHero({required this.onCreateTrip});

  final VoidCallback onCreateTrip;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TripCubit, TripState>(
      builder: (context, state) {
        return switch (state) {
          TripEmpty() => _CreateTripPrompt(onCreateTrip: onCreateTrip),
          TripError() => ErrorState(
            title: 'Unable to load trips',
            message: 'Something went wrong while loading your trips. Please try again.',
            onRetry: () => context.read<TripCubit>().retry(),
          ),
          TripLoaded(:final active) => _ActiveTripCard(trip: active),
          _ => const SizedBox(height: 180, child: Center(child: CircularProgressIndicator())),
        };
      },
    );
  }
}

/// First-run / no-trips prompt. The primary CTA launches the FEAT-007 flow.
class _CreateTripPrompt extends StatelessWidget {
  const _CreateTripPrompt({required this.onCreateTrip});

  final VoidCallback onCreateTrip;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      strong: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(paddingUnit * 0.75),
            decoration: BoxDecoration(
              color: XploreColors.alternate.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(radiusSm),
              border: Border.all(color: XploreColors.alternate.withValues(alpha: 0.32)),
            ),
            child: Icon(Icons.travel_explore_rounded, size: 24, color: XploreColors.alternate),
          ),
          const SizedBox(height: paddingUnit),
          Text('Plan your next trip', style: context.pText.headlineSmall?.copyWith(letterSpacing: -0.3)),
          const SizedBox(height: paddingUnit * 0.5),
          Text(
            'Tell us where you\u2019re headed and we\u2019ll generate a day-by-day starting point — solo or with your crew.',
            style: context.pText.bodyMedium?.copyWith(color: XploreColors.mutedText),
          ),
          const SizedBox(height: paddingUnit * 1.25),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onCreateTrip,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('Start planning'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hero card for the active trip: gradient cover, title, destination, dates,
/// group size, and an *available* invite action (never a nag — a solo trip is
/// complete on its own).
class _ActiveTripCard extends StatefulWidget {
  const _ActiveTripCard({required this.trip});

  final TripModel trip;

  @override
  State<_ActiveTripCard> createState() => _ActiveTripCardState();
}

class _ActiveTripCardState extends State<_ActiveTripCard> {
  bool _isCreating = false;

  static const _monthAbbr = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  String? get _dateLabel {
    final start = widget.trip.startDate;
    final end = widget.trip.endDate;
    if (start == null || end == null) {
      return null;
    }
    String fmt(DateTime d) => '${_monthAbbr[d.month - 1]} ${d.day}';
    return '${fmt(start)} – ${fmt(end)}';
  }

  Future<void> _share() async {
    if (_isCreating) {
      return;
    }
    setState(() => _isCreating = true);

    final messenger = ScaffoldMessenger.of(context);
    final tripService = context.read<TripService>();
    final uid = context.read<AuthService>().currentUid;
    if (uid == null) {
      setState(() => _isCreating = false);
      return;
    }

    try {
      final handle = await tripService.createInvite(widget.trip.id, uid);
      HapticFeedback.lightImpact();
      await SharePlus.instance.share(
        ShareParams(text: 'Join "${widget.trip.title}" on Xplore:\n${handle.link}', subject: 'Join my trip on Xplore'),
      );
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Couldn\u2019t create an invite link. Please try again.')));
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final memberCount = trip.memberIds.length;
    final dateLabel = _dateLabel;
    final radius = BorderRadius.circular(radiusLg);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(XploreColors.alternate, XploreColors.primary, 0.12)!,
            Color.lerp(XploreColors.secondary, XploreColors.primary, 0.3)!,
            XploreColors.primary,
          ],
          stops: const [0, 0.5, 1],
        ),
        border: Border.all(color: XploreColors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: XploreColors.alternate.withValues(alpha: 0.16),
            blurRadius: 32,
            spreadRadius: -6,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(paddingUnit * 1.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _HeroChip(icon: Icons.flight_takeoff_rounded, label: 'Active trip'),
                const Spacer(),
                if (dateLabel != null) _HeroChip(icon: Icons.event_rounded, label: dateLabel),
              ],
            ),
            const SizedBox(height: paddingUnit * 1.5),
            Text(
              trip.title,
              style: context.pText.headlineMedium?.copyWith(letterSpacing: -0.4, height: 1.05),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: paddingUnit * 0.5),
            Row(
              children: [
                Icon(Icons.place_outlined, size: 16, color: XploreColors.white.withValues(alpha: 0.82)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    trip.destination?.trim().isNotEmpty == true ? trip.destination! : 'Destination not set',
                    style: context.pText.bodyMedium?.copyWith(color: XploreColors.white.withValues(alpha: 0.82)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: paddingUnit * 1.25),
            Row(
              children: [
                Icon(
                  memberCount > 1 ? Icons.groups_rounded : Icons.person_rounded,
                  size: 16,
                  color: XploreColors.white.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 5),
                Text(
                  memberCount > 1 ? '$memberCount travelers' : 'Solo trip',
                  style: context.pText.bodySmall?.copyWith(color: XploreColors.white.withValues(alpha: 0.7)),
                ),
                const Spacer(),
                _HeroInviteButton(busy: _isCreating, onTap: _share),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: paddingUnit * 0.75, vertical: paddingUnit / 2),
      decoration: BoxDecoration(
        color: XploreColors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(radiusSm),
        border: Border.all(color: XploreColors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: XploreColors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: context.pText.labelSmall?.copyWith(color: XploreColors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _HeroInviteButton extends StatelessWidget {
  const _HeroInviteButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: XploreColors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(radiusSm),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: paddingUnit * 0.85, vertical: paddingUnit / 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              busy
                  ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.ios_share_rounded, size: 15, color: XploreColors.white),
              const SizedBox(width: 6),
              Text(
                'Invite',
                style: context.pText.labelSmall?.copyWith(color: XploreColors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatarButton extends StatelessWidget {
  const _ProfileAvatarButton();

  static const _size = 44.0;

  @override
  Widget build(BuildContext context) {
    void open() => Navigator.pushNamed(context, Paths.profile);

    return BlocBuilder<ProfileCubit, ProfileState>(
      buildWhen: (a, b) => a.profilePicture != b.profilePicture,
      builder: (context, state) {
        final picture = state.profilePicture;

        if (picture == null) {
          return SizedBox(
            width: _size,
            height: _size,
            child: GlassSurface(
              borderRadius: _size / 2,
              strong: true,
              padding: EdgeInsets.zero,
              onTap: open,
              child: Center(child: Icon(Icons.person_2_outlined, size: 22, color: XploreColors.white)),
            ),
          );
        }

        return GestureDetector(
          onTap: open,
          child: Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: XploreColors.glassBorder),
              image: DecorationImage(image: MemoryImage(picture), fit: BoxFit.cover),
            ),
          ),
        );
      },
    );
  }
}

class _HomeGreeting extends StatelessWidget {
  const _HomeGreeting();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      buildWhen: (a, b) => a.name != b.name,
      builder: (context, state) {
        final firstName = state.name.trim().split(' ').first;

        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome back', style: context.pText.labelSmall?.copyWith(color: XploreColors.subtleText)),
            Text(
              firstName,
              style: context.pText.labelLarge?.copyWith(letterSpacing: -0.2),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      },
    );
  }
}
