part of 'auth_cubit.dart';

@freezed
sealed class AuthState with _$AuthState {
  /// Boot, before the first auth resolution.
  const factory AuthState.unknown() = AuthUnknown;

  const factory AuthState.unauthenticated() = AuthUnauthenticated;

  const factory AuthState.authenticated({
    required String uid,
    required String displayName,
    String? email,
    String? photoUrl,
  }) = AuthAuthenticated;
}
