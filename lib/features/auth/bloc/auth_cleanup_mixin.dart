import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/features/auth/services/auth_service.dart';

/// Makes a [Cubit] auth-aware so it can wipe its per-user local state on
/// sign-out — nothing (profile pictures, cached docs, in-memory bytes) must
/// bleed into the next account on the same device.
///
/// Feature cubits are app-scoped singletons created above the `AuthGate`, so a
/// single instance outlives sign-out/sign-in. This mixin listens to
/// [AuthService.authStateChanges] (NOT `AuthCubit` — cubits never import other
/// cubits, per `docs/PATTERNS.md`) and fires:
///
/// * [onSignedOut] on the authenticated → unauthenticated edge (the cleanup
///   hook every subscriber implements), and
/// * [onSignedIn] on the unauthenticated → authenticated edge (optional
///   re-initialisation, e.g. re-hydrating after an account switch).
///
/// Only edges fire, so boot-time emissions, token refreshes, and repeated
/// authenticated events never trigger a wipe. Call [bindAuthCleanup] once from
/// the constructor; the subscription is cancelled automatically on [close]
/// (provided the cubit's own `close` override chains to `super.close()`).
mixin AuthCleanupMixin<S> on Cubit<S> {
  StreamSubscription<User?>? _authCleanupSubscription;
  bool _wasAuthenticated = false;

  /// Wires the auth-edge listener. Safe to call once, from the constructor.
  void bindAuthCleanup(AuthService authService) {
    _wasAuthenticated = authService.currentUid != null;
    _authCleanupSubscription = authService.authStateChanges().listen((user) {
      final isAuthenticated = user != null;
      if (_wasAuthenticated && !isAuthenticated) {
        unawaited(_runGuarded(onSignedOut));
      } else if (!_wasAuthenticated && isAuthenticated) {
        unawaited(_runGuarded(() => onSignedIn(user.uid)));
      }
      _wasAuthenticated = isAuthenticated;
    });
  }

  /// Wipes this cubit's per-user local state (Hive boxes, cached files,
  /// in-memory state). Implementations should be best-effort; thrown errors are
  /// swallowed so one cubit's failure never blocks the others' cleanup.
  Future<void> onSignedOut();

  /// Re-initialises per-user state for the freshly signed-in [uid]. Defaults to
  /// a no-op for cubits whose sign-in path is already driven elsewhere (e.g. via
  /// the trip stream).
  Future<void> onSignedIn(String uid) async {}

  Future<void> _runGuarded(Future<void> Function() action) async {
    if (isClosed) return;
    try {
      await action();
    } catch (_) {
      // Best-effort: cleanup/rehydrate failures must not crash the auth flow.
    }
  }

  @override
  Future<void> close() async {
    await _authCleanupSubscription?.cancel();
    return super.close();
  }
}
