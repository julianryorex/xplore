// Tests for `AuthCleanupMixin`: per-user cubits wipe their local state on the
// sign-out edge (and re-init on sign-in) so nothing bleeds across accounts on a
// shared device. A controllable `AuthService` drives the auth stream directly so
// the edge logic is exercised without Firebase.

import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/features/auth/bloc/auth_cleanup_mixin.dart';
import 'package:xplore/features/auth/services/auth_service.dart';

/// [AuthService] whose auth stream and current uid are fully driver-controlled.
class _ControllableAuthService extends AuthService {
  _ControllableAuthService({String? initialUid})
    : _uid = initialUid,
      super(firebaseAuth: MockFirebaseAuth(), firestore: FakeFirebaseFirestore());

  final _controller = StreamController<User?>.broadcast();
  String? _uid;

  @override
  String? get currentUid => _uid;

  @override
  Stream<User?> authStateChanges() => _controller.stream;

  void emitSignedIn(String uid) {
    _uid = uid;
    _controller.add(MockUser(uid: uid));
  }

  void emitSignedOut() {
    _uid = null;
    _controller.add(null);
  }

  Future<void> dispose() => _controller.close();
}

class _ProbeCubit extends Cubit<int> with AuthCleanupMixin {
  _ProbeCubit(AuthService auth) : super(0) {
    bindAuthCleanup(auth);
  }

  int signedOutCalls = 0;
  final List<String> signedInUids = [];

  @override
  Future<void> onSignedOut() async => signedOutCalls++;

  @override
  Future<void> onSignedIn(String uid) async => signedInUids.add(uid);
}

/// Lets the broadcast stream deliver and the async hooks run.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('fires onSignedOut on the authenticated -> unauthenticated edge', () async {
    final auth = _ControllableAuthService(initialUid: 'u1');
    addTearDown(auth.dispose);
    final cubit = _ProbeCubit(auth);
    addTearDown(cubit.close);

    auth.emitSignedOut();
    await _settle();

    expect(cubit.signedOutCalls, 1);
    expect(cubit.signedInUids, isEmpty);
  });

  test('fires onSignedIn on the unauthenticated -> authenticated edge', () async {
    final auth = _ControllableAuthService();
    addTearDown(auth.dispose);
    final cubit = _ProbeCubit(auth);
    addTearDown(cubit.close);

    auth.emitSignedIn('u2');
    await _settle();

    expect(cubit.signedInUids, ['u2']);
    expect(cubit.signedOutCalls, 0);
  });

  test('does not fire when the user stays authenticated (boot / token refresh)', () async {
    final auth = _ControllableAuthService(initialUid: 'u1');
    addTearDown(auth.dispose);
    final cubit = _ProbeCubit(auth);
    addTearDown(cubit.close);

    // Re-emitting the same authenticated user must not be treated as an edge.
    auth.emitSignedIn('u1');
    await _settle();

    expect(cubit.signedOutCalls, 0);
    expect(cubit.signedInUids, isEmpty);
  });

  test('handles a full sign-out then sign-in (account switch)', () async {
    final auth = _ControllableAuthService(initialUid: 'u1');
    addTearDown(auth.dispose);
    final cubit = _ProbeCubit(auth);
    addTearDown(cubit.close);

    auth.emitSignedOut();
    await _settle();
    auth.emitSignedIn('u2');
    await _settle();

    expect(cubit.signedOutCalls, 1);
    expect(cubit.signedInUids, ['u2']);
  });

  test('stops firing once the cubit is closed', () async {
    final auth = _ControllableAuthService(initialUid: 'u1');
    addTearDown(auth.dispose);
    final cubit = _ProbeCubit(auth);

    await cubit.close();
    auth.emitSignedOut();
    await _settle();

    expect(cubit.signedOutCalls, 0);
  });
}
