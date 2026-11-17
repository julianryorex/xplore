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
class TripHome extends StatelessWidget {
  const TripHome({required this.trip, super.key});

  final TripModel trip;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ItineraryCubit, ItineraryStates>(
      builder: (context, itineraryState) {
        final overview = TripOverview(
          trip: trip,
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
            ItineraryPreview(state: itineraryState, overview: overview),
            const GalleryStrip(),
          ],
        );
      },
    );
  }
}
