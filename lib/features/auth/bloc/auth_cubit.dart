import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:xplore/features/auth/services/auth_analytics.dart';
import 'package:xplore/features/auth/services/auth_service.dart';

part '../../../generated/features/auth/bloc/auth_cubit.freezed.dart';
part 'auth_state.dart';

/// Exposes auth UI state to the widget tree (the `AuthGate`). Composes
/// [AuthService] (the single UID source) and maps its stream to [AuthState].
/// Imports no other cubit, per the architecture rule.
class AuthCubit extends Cubit<AuthState> {
  final AuthService _authService;
  final AuthAnalytics analytics;
  StreamSubscription<User?>? _subscription;

  AuthCubit(this._authService, {this.analytics = const AuthAnalytics()}) : super(const AuthState.unknown()) {
    _subscription = _authService.authStateChanges().listen(_onUserChanged);
  }

  void _onUserChanged(User? user) {
    if (user == null) {
      emit(const AuthState.unauthenticated());
      return;
    }

    final name = (user.displayName == null || user.displayName!.trim().isEmpty) ? 'Traveler' : user.displayName!;

    emit(AuthState.authenticated(uid: user.uid, displayName: name, email: user.email, photoUrl: user.photoURL));
  }

  /// Forwards to [AuthService]; the `authStateChanges` stream drives the actual
  /// transition to [AuthAuthenticated]. Rethrows so the UI can surface errors.
  Future<void> signInWithGoogle() async {
    analytics.signInStarted(provider: 'google');
    try {
      await _authService.signInWithGoogle();
      analytics.signInSucceeded(provider: 'google');
    } on AuthCancelledException {
      analytics.signInFailed(provider: 'google', reason: 'cancelled');
      rethrow;
    } on AuthFailureException catch (e) {
      analytics.signInFailed(provider: 'google', reason: e.message);
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    analytics.signOut();
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
