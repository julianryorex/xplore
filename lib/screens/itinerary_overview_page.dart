import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/core/header.dart';
import 'package:xplore/core/icon_button.dart';
import 'package:xplore/core/layout_padding.dart';
import 'package:xplore/features/itinerary/bloc/itinerary_cubit.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/features/itinerary/widgets/itinerary_tile.dart';
import 'package:xplore/utilities/utilities.dart';

/// A single day's checklist. Reads the day live from [ItineraryCubit] by
/// [dayIndex] so completion toggles (and later edits) reflect instantly; the
/// trip owner can check stops off, everyone else sees a read-only view.
class ItineraryOverviewPage extends StatelessWidget {
  final int dayIndex;

  const ItineraryOverviewPage({required this.dayIndex, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            BlocBuilder<ItineraryCubit, ItineraryStates>(
              builder: (context, state) {
                final dailyPlan = _dayFor(state);
                if (dailyPlan == null) {
                  return const _MissingDay();
                }
                final canEdit = state is LoadedItineraryState && state.canEdit;
                return _OverviewBody(dailyPlan: dailyPlan, dayIndex: dayIndex, canEdit: canEdit);
              },
            ),
            SafeArea(
              child: Header(
                leadingWidget: XploreIconBtn(
                  bgColor: XploreColors.darkBg,
                  onTapCallback: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: headerIconSize),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The day at [dayIndex], or null if the itinerary isn't loaded or the index
  /// is out of range (e.g. the day was removed on another device).
  DailyPlanModel? _dayFor(ItineraryStates state) {
    if (state is! LoadedItineraryState) {
      return null;
    }
    final plans = state.itinerary.dailyPlans;
    if (dayIndex < 0 || dayIndex >= plans.length) {
      return null;
    }
    return plans[dayIndex];
  }
}

class _OverviewBody extends StatelessWidget {
  final DailyPlanModel dailyPlan;
  final int dayIndex;
  final bool canEdit;

  const _OverviewBody({required this.dailyPlan, required this.dayIndex, required this.canEdit});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: getScreenHeight(context: context, percent: 0.45),
            decoration: const BoxDecoration(
              image: DecorationImage(image: AssetImage('assets/placeholders/skytree.jpeg'), fit: BoxFit.fitWidth),
            ),
          ),
          LayoutPadding(
            enableHeaderPadding: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dailyPlan.title, style: context.pText.headlineMedium),
                const SizedBox(height: 30),
                _Checklist(dailyPlan: dailyPlan, dayIndex: dayIndex, canEdit: canEdit),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Checklist extends StatelessWidget {
  final DailyPlanModel dailyPlan;
  final int dayIndex;
  final bool canEdit;

  const _Checklist({required this.dailyPlan, required this.dayIndex, required this.canEdit});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, bc) {
        const rowSize = 60.0;
        final locations = dailyPlan.plan.locations;

        return SizedBox(
          width: bc.maxWidth,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  for (final (index, location) in locations.indexed)
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 40),
                      child: _renderCheckOrCircle(context, location, index, rowSize),
                    ),
                ],
              ),
              const SizedBox(width: paddingUnit * 2),
              Column(
                children: [
                  for (final location in locations)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 30),
                      child: ItineraryTile(locationPlan: location, width: bc.maxWidth, height: rowSize),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _renderCheckOrCircle(BuildContext context, LocationPlanModel locationPlan, int locationIndex, double rowSize) {
    // Owner-only: a non-owner sees the same indicator but tapping does nothing.
    void onTap() => context.read<ItineraryCubit>().toggleLocationCompleted(dayIndex, locationIndex);
    final callback = canEdit ? onTap : () {};

    if (locationPlan.completed) {
      return XploreIconBtn(
        icon: Icon(Icons.check, color: XploreColors.darkBg, size: 30),
        onTapCallback: callback,
        size: rowSize,
        borderRadius: 100,
      );
    }
    return XploreIconBtn(
      onTapCallback: callback,
      size: rowSize,
      borderColor: XploreColors.alternate,
      bgColor: XploreColors.darkBg,
      borderRadius: 100,
    );
  }
}

class _MissingDay extends StatelessWidget {
  const _MissingDay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LayoutPadding(
        child: Text('This day is no longer available.', textAlign: TextAlign.center, style: context.pText.bodyMedium),
      ),
    );
  }
}
