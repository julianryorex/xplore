import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/features/home/models/trip_overview.dart';
import 'package:xplore/features/home/widgets/gallery_strip.dart';
import 'package:xplore/features/home/widgets/itinerary_preview.dart';
import 'package:xplore/features/home/widgets/trip_hero.dart';
import 'package:xplore/features/home/widgets/trip_summary_card.dart';
import 'package:xplore/features/itinerary/bloc/itinerary_cubit.dart';
import 'package:xplore/features/trip/models/trip_model.dart';

/// Home's body when the user has an active trip: hero, summary card, itinerary
/// preview and shared gallery, scrolling under the fixed header.
class TripHome extends StatefulWidget {
  const TripHome({required this.trip, super.key});

  final TripModel trip;

  @override
  State<TripHome> createState() => _TripHomeState();
}

class _TripHomeState extends State<TripHome> {
  // The countdown is computed from today's date at build time, so rebuild when
  // the app returns to the foreground in case the day changed in the background.
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(onResume: () => setState(() {}));
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ItineraryCubit, ItineraryStates>(
      builder: (context, itineraryState) {
        final overview = TripOverview(
          trip: widget.trip,
          dailyPlans: switch (itineraryState) {
            LoadedItineraryState(:final itinerary) => itinerary.dailyPlans,
            _ => const [],
          },
        );

        return ListView(
          padding: EdgeInsets.only(bottom: MediaQuery.viewPaddingOf(context).bottom + navBarHeight),
          children: [
            TripHero(overview: overview),
            TripSummaryCard(overview: overview),
            // Keyed by trip so the expanded state resets when the active trip changes.
            ItineraryPreview(key: ValueKey(widget.trip.id), state: itineraryState, overview: overview),
            const GalleryStrip(),
          ],
        );
      },
    );
  }
}
