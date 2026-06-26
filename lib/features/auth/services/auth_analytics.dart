import 'package:xplore/utilities/utilities.dart';

/// Thin wrapper for the §8 auth analytics events (FEAT-001).
///
/// Stub for now — it just logs. The real sink (Firebase Analytics / Amplitude)
/// is wired up in FEAT-025; keeping this seam means call sites don't change.
class AuthAnalytics {
  const AuthAnalytics();

  void signInStarted({required String provider}) => _log('auth_sign_in_started', {'provider': provider});

  void signInSucceeded({required String provider}) => _log('auth_sign_in_succeeded', {'provider': provider});

  void signInFailed({required String provider, required String reason}) =>
      _log('auth_sign_in_failed', {'provider': provider, 'reason': reason});

  void signOut() => _log('auth_sign_out', const {});

  void accountDeletionStarted() => _log('auth_account_deletion_started', const {});

  void accountDeleted() => _log('auth_account_deleted', const {});

  void accountDeletionFailed({required String reason}) => _log('auth_account_deletion_failed', {'reason': reason});

  void _log(String event, Map<String, Object?> params) {
    wlog.d('[analytics] $event ${params.isEmpty ? '' : params}');
  }
}
