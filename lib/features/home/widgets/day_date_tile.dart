import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/features/home/models/trip_overview.dart';

/// The 40pt leading tile of an itinerary day row: month over day number for a
/// dated trip, or "DAY" over the 1-based index. Accent when the day has stops
/// ([planned]), muted grey otherwise.
class DayDateTile extends StatelessWidget {
  const DayDateTile({required this.overview, required this.dayIndex, required this.planned, super.key});

  final TripOverview overview;
  final int dayIndex;
  final bool planned;

  @override
  Widget build(BuildContext context) {
    final date = overview.dateOfDay(dayIndex);
    final caption = date == null ? 'DAY' : monthAbbreviation(date).toUpperCase();
    final number = date == null ? '${dayIndex + 1}' : '${date.day}';
    final foreground = planned ? XploreColors.accent : XploreColors.secondaryLabel;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: planned ? XploreColors.accentSoft : XploreColors.raised,
        borderRadius: BorderRadius.circular(radiusSm),
      ),
      // The tile keeps its fixed size, so large text sizes shrink to fit instead of overflowing.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(caption, style: XploreText.overline.copyWith(color: foreground)),
            Text(number, style: XploreText.stat.copyWith(height: 1.05, color: foreground)),
          ],
        ),
      ),
    );
  }
}
