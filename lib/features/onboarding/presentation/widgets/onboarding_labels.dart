import 'package:xplore/features/auth/bloc/auth_cubit.dart';
import 'package:xplore/features/home/models/trip_overview.dart';
import 'package:xplore/features/trip/models/trip_window.dart';

/// The user's first name for onboarding copy, or null when there is no real
/// name yet: signed out, blank, or the placeholder the auth layer uses.
String? onboardingFirstName(AuthState auth) {
  if (auth is! AuthAuthenticated) {
    return null;
  }
  final name = auth.displayName.trim();
  if (name.isEmpty || name == AuthCubit.placeholderName) {
    return null;
  }
  return name.split(RegExp(r'\s+')).first;
}

/// "Jun 3 – 9", "Jun 28 – Jul 3" or "Jun 3"; null without a complete date range.
String? tripDatesLabel(DateTime? start, DateTime? end) {
  if (start == null || end == null) {
    return null;
  }
  if (daysUntil(end, now: start) == 0) {
    return formatMonthDay(start);
  }
  final sameMonth = start.year == end.year && start.month == end.month;
  return '${formatMonthDay(start)} – ${sameMonth ? end.day : formatMonthDay(end)}';
}

/// The trip's length counting both ends, e.g. "7 days" for Jun 3 – 9.
String tripLengthLabel(DateTime start, DateTime end) {
  final days = daysUntil(end, now: start) + 1;
  return days == 1 ? '1 day' : '$days days';
}
