/// Points at one stop of the loaded itinerary by position. Screens take this
/// instead of the stop itself so they always show the live plan.
typedef ItineraryStopRef = ({int dayIndex, int stopIndex});
