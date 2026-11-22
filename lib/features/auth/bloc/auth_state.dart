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

    /// False when this account has signed in before, so onboarding can skip
    /// what a returning user has already set up.
    @Default(true) bool isNewAccount,
  }) = AuthAuthenticated;
}
