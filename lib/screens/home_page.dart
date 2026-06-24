import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/core/ambient_background.dart';
import 'package:xplore/core/error_state.dart';
import 'package:xplore/core/glass.dart';
import 'package:xplore/core/header.dart';
import 'package:xplore/core/section_header.dart';
import 'package:xplore/features/gallery/bloc/gallery_cubit.dart';
import 'package:xplore/features/itinerary/bloc/itinerary_cubit.dart';
import 'package:xplore/features/itinerary/widgets/itinerary_card.dart';
import 'package:xplore/features/profile/bloc/profile_cubit.dart';
import 'package:xplore/features/trip/bloc/trip_cubit.dart';
import 'package:xplore/features/trip/bloc/trip_state.dart';
import 'package:xplore/routes.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _openCreateTripSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateTripSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final topInset = viewPadding.top;
    // Space the scroll content needs to clear the floating glass nav bar (its
    // height + the device's bottom safe-area inset).
    final bottomClearance = viewPadding.bottom + navBarHeight;
    // Gap between the status bar and the header controls.
    const headerTopGap = paddingUnit * 0.75;
    final headerZone = topInset + headerTopGap + Header.padding;

    // Pure content for the RootShell's IndexedStack: the surrounding Scaffold,
    // background colour and floating glass nav bar live in RootShell.
    return AmbientBackground(
      child: Stack(
        children: [
          // Content runs full-height behind the pinned header and floating
          // nav bar so the glass surfaces have content to refract.
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
                SectionHeader(
                  title: 'Daily Plans',
                  actionLabel: 'See all',
                  onAction: () => _openCreateTripSheet(context),
                ),
                const SizedBox(height: paddingUnit),
                _TripStatePrompt(
                  onCreateTrip: () => _openCreateTripSheet(context),
                ),
                const SizedBox(height: paddingUnit),

                //! Daily Plans Section Containers
                BlocBuilder<ItineraryCubit, ItineraryStates>(
                  builder: (context, state) {
                    return switch (state) {
                      InitialItineraryState() ||
                      LoadingItineraryState() => const SizedBox(
                        height: 300,
                        width: 230,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      EmptyItineraryState() => const _ItineraryPlaceholder(
                        message:
                            'Create or open a trip to see its daily plans here.',
                      ),
                      ErrorItineraryState() => ErrorState(
                        title: 'Unable to load itinerary',
                        message: 'Something went wrong. Please try again later',
                        onRetry: () => context.read<ItineraryCubit>().retry(),
                      ),
                      LoadedItineraryState(:final itinerary)
                          when itinerary.dailyPlans.isEmpty =>
                        const _ItineraryPlaceholder(
                          message:
                              'No plans yet. Days and stops will appear here once added.',
                        ),
                      LoadedItineraryState(:final itinerary) =>
                        SingleChildScrollView(
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

                //! Gallery Section Header
                const SectionHeader(title: 'Gallery'),
                const SizedBox(height: paddingUnit),

                //! Gallery options
                GlassSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(paddingUnit * 0.75),
                            decoration: BoxDecoration(
                              color: XploreColors.alternate.withValues(
                                alpha: 0.18,
                              ),
                              borderRadius: BorderRadius.circular(radiusSm),
                              border: Border.all(
                                color: XploreColors.alternate.withValues(
                                  alpha: 0.32,
                                ),
                              ),
                            ),
                            child: Icon(
                              Icons.photo_library_outlined,
                              size: 22,
                              color: XploreColors.alternate,
                            ),
                          ),
                          const SizedBox(width: paddingUnit),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Shared gallery',
                                  style: context.pText.labelLarge,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Keep every trip moment in one place.',
                                  style: context.pText.bodySmall?.copyWith(
                                    color: XploreColors.mutedText,
                                  ),
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
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                          ),
                          label: const Text('View gallery'),
                        ),
                      ),
                    ],
                  ),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: paddingUnit),
                  Wrap(
                    spacing: paddingUnit,
                    runSpacing: paddingUnit,
                    children: [
                      OutlinedButton(
                        onPressed: () async {
                          await context
                              .read<ItineraryCubit>()
                              .loadDemoItinerary();
                        },
                        child: const Text('Load data'),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          context.push(Paths.gallery);
                          await context.read<GalleryCubit>().uploadToGallery();
                        },
                        child: const Text('Upload'),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          context.read<GalleryCubit>().deleteAll();
                          // context.read<LocationCubit>().deleteAll();
                          context.read<ProfileCubit>().deleteAll();
                        },
                        child: const Text('Delete Hive'),
                      ),
                      OutlinedButton(
                        onPressed: () => context.read<TripCubit>().debugTriggerError(),
                        child: const Text('Trigger error'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Top scrim: blends the status-bar area into the base colour and
          // keeps content legible as it scrolls beneath the pinned header.
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
          // Pinned header, sitting just below the status bar.
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

class _TripStatePrompt extends StatelessWidget {
  const _TripStatePrompt({required this.onCreateTrip});

  final VoidCallback onCreateTrip;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TripCubit, TripState>(
      builder: (context, state) {
        return switch (state) {
          TripEmpty() => GlassSurface(
            child: Row(
              children: [
                Icon(
                  Icons.travel_explore_rounded,
                  color: XploreColors.alternate,
                ),
                const SizedBox(width: paddingUnit),
                Expanded(
                  child: Text(
                    'Create your first trip to start saving plans, photos, and locations together.',
                    style: context.pText.bodySmall?.copyWith(
                      color: XploreColors.mutedText,
                    ),
                  ),
                ),
                const SizedBox(width: paddingUnit),
                FilledButton(
                  onPressed: onCreateTrip,
                  child: const Text('Create'),
                ),
              ],
            ),
          ),
          TripError() => ErrorState(
            title: 'Unable to load trips',
            message: 'Something went wrong while loading your trips. Please try again.',
            onRetry: () => context.read<TripCubit>().retry(),
          ),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }
}

class _CreateTripSheet extends StatefulWidget {
  const _CreateTripSheet();

  @override
  State<_CreateTripSheet> createState() => _CreateTripSheetState();
}

class _CreateTripSheetState extends State<_CreateTripSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _controller.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Name your trip first.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await context.read<TripCubit>().createTrip(title);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: paddingUnit,
        right: paddingUnit,
        bottom: MediaQuery.viewInsetsOf(context).bottom + paddingUnit,
      ),
      child: GlassSurface(
        strong: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create a trip', style: context.pText.headlineSmall),
            const SizedBox(height: paddingUnit / 2),
            Text(
              'Give this shared space a name. Dates and cover images will come in the full trip switcher.',
              style: context.pText.bodySmall?.copyWith(
                color: XploreColors.mutedText,
              ),
            ),
            const SizedBox(height: paddingUnit),
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _isSubmitting ? null : _submit(),
              decoration: InputDecoration(
                errorText: _error,
                labelText: 'Trip name',
              ),
            ),
            const SizedBox(height: paddingUnit),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: Text(_isSubmitting ? 'Creating...' : 'Create trip'),
              ),
            ),
          ],
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
              child: Center(
                child: Icon(
                  Icons.person_2_outlined,
                  size: 22,
                  color: XploreColors.white,
                ),
              ),
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
              image: DecorationImage(
                image: MemoryImage(picture),
                fit: BoxFit.cover,
              ),
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
            Text(
              'Welcome back',
              style: context.pText.labelSmall?.copyWith(
                color: XploreColors.subtleText,
              ),
            ),
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
