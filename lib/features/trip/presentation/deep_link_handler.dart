import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/features/auth/bloc/auth_cubit.dart';
import 'package:xplore/features/trip/services/deep_link_service.dart';
import 'package:xplore/features/trip/services/invite_link.dart';
import 'package:xplore/routes.dart';

/// Listens for invite deep links and routes them to the join-confirmation
/// screen once the user is authenticated.
///
/// Wraps the app's home so it sits *below* the [MaterialApp]'s [Navigator] and
/// can push named routes directly. If a link arrives while signed out, it is
/// held until [AuthAuthenticated] (the [AuthGate] presents sign-in/onboarding
/// in the meantime), then the join screen is pushed — so a "tap link → sign in
/// → land in the trip" flow works without losing the invite.
class DeepLinkHandler extends StatefulWidget {
  const DeepLinkHandler({required this.child, super.key});

  final Widget child;

  @override
  State<DeepLinkHandler> createState() => _DeepLinkHandlerState();
}

class _DeepLinkHandlerState extends State<DeepLinkHandler> {
  StreamSubscription<InviteLinkData>? _subscription;
  InviteLinkData? _pending;

  @override
  void initState() {
    super.initState();
    final service = context.read<DeepLinkService>();
    _subscription = service.inviteLinks.listen(_onInvite);
    unawaited(_checkInitialLink(service));
  }

  Future<void> _checkInitialLink(DeepLinkService service) async {
    final initial = await service.initialInviteLink();
    if (initial != null) {
      _onInvite(initial);
    }
  }

  void _onInvite(InviteLinkData data) {
    _pending = data;
    _tryConsumePending();
  }

  /// Navigates to the join screen if there is a held invite and the user is
  /// authenticated. Deferred to a post-frame callback so it runs after the
  /// [AuthGate]'s own route reset on sign-in.
  void _tryConsumePending() {
    final pending = _pending;
    if (pending == null || !mounted) {
      return;
    }

    final isAuthenticated = context.read<AuthCubit>().state is AuthAuthenticated;
    if (!isAuthenticated) {
      return;
    }

    _pending = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pushNamed(Paths.joinTrip, arguments: pending);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (previous, current) => previous.runtimeType != current.runtimeType,
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          _tryConsumePending();
        }
      },
      child: widget.child,
    );
  }
}
