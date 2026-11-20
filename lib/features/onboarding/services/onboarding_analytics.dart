import 'package:xplore/utilities/utilities.dart';

/// Funnel events for the onboarding flow (FEAT-005), one per screen so
/// per-step drop-off can be measured.
///
/// Stub for now: it just logs. The real sink is wired up in FEAT-025; keeping
/// this seam means call sites don't change.
class OnboardingAnalytics {
  const OnboardingAnalytics();

  void stepViewed({required String path, required String step}) =>
      _log('onboarding_step_viewed', {'path': path, 'step': step});

  void stepSkipped({required String path, required String step}) =>
      _log('onboarding_step_skipped', {'path': path, 'step': step});

  void completed({required String path}) => _log('onboarding_completed', {'path': path});

  void _log(String event, Map<String, Object?> params) {
    wlog.d('[analytics] $event $params');
  }
}
