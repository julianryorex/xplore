import 'package:xplore/features/trip/bloc/trip_creation_state.dart';
import 'package:xplore/features/trip/models/nights_allocation.dart';
import 'package:xplore/features/trip/models/trip_draft.dart';

/// What the user has to do before the current step's primary button works, or
/// null when it already works (or is busy creating the trip, which the button
/// itself shows).
String? advanceBlockerMessage(TripCreationState state) => switch (state.advanceBlocker) {
  null || CreateTripBlocker.submitting => null,
  CreateTripBlocker.noStops => 'Add a place to continue',
  CreateTripBlocker.nightsInvalid => nightsIssueMessage(state.draft.nightsAllocation),
  CreateTripBlocker.notesTooLong => 'Notes are too long (up to $maxTripNotesLength characters)',
  CreateTripBlocker.titleTooLong => 'Trip name is too long (up to $maxTripTitleLength characters)',
};

/// A short instruction for fixing [allocation]'s issue ("Assign 1 more night"),
/// or null when the nights are valid.
String? nightsIssueMessage(NightsAllocation allocation) {
  final target = allocation.target ?? allocation.assigned;
  return switch (allocation.issue) {
    null => null,
    NightsIssue.noStops => 'Add a place to continue',
    NightsIssue.missingDates => 'Choose your dates',
    NightsIssue.tooLong => 'Trips can be up to $maxTripNights nights',
    NightsIssue.fewerNightsThanStops =>
      '${allocation.stopCount} places need at least ${nightsLabel(allocation.stopCount)}',
    NightsIssue.stopWithoutNights => 'Every place needs at least 1 night',
    NightsIssue.unassigned => 'Assign ${_more(target - allocation.assigned)}',
    NightsIssue.overassigned => 'Remove ${nightsLabel(allocation.assigned - target)}',
  };
}

/// "1 night" or "4 nights".
String nightsLabel(int nights) => nights == 1 ? '1 night' : '$nights nights';

String _more(int nights) => nights == 1 ? '1 more night' : '$nights more nights';
