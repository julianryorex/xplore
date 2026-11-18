import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/core/ambient_background.dart';
import 'package:xplore/core/error_state.dart';
import 'package:xplore/features/home/presentation/empty_home.dart';
import 'package:xplore/features/home/presentation/trip_home.dart';
import 'package:xplore/features/home/widgets/home_header.dart';
import 'package:xplore/features/trip/bloc/trip_cubit.dart';
import 'package:xplore/features/trip/bloc/trip_state.dart';

/// The Home tab: a fixed header above whichever body matches the trip state —
/// the active trip, the first-trip prompt, or a loading / error placeholder.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AmbientBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const HomeHeader(),
            Expanded(
              child: BlocBuilder<TripCubit, TripState>(
                builder: (context, state) {
                  return switch (state) {
                    TripLoading() => const Center(child: CircularProgressIndicator()),
                    TripEmpty() => const EmptyHome(),
                    TripLoaded(:final active) => TripHome(trip: active),
                    TripError() => Padding(
                      padding: const EdgeInsets.all(paddingUnit * 1.5),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ErrorState(
                          title: 'Unable to load trips',
                          message: 'Something went wrong while loading your trips. Please try again.',
                          onRetry: () => context.read<TripCubit>().retry(),
                        ),
                      ),
                    ),
                  };
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
