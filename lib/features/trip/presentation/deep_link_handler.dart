import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/features/auth/bloc/auth_cubit.dart';
import 'package:xplore/features/onboarding/bloc/onboarding_cubit.dart';
import 'package:xplore/features/trip/services/deep_link_service.dart';
import 'package:xplore/features/trip/services/invite_link.dart';
import 'package:xplore/routes.dart';

/// Listens for invite deep links and routes them by who is opening them.
///
/// A signed-in user goes straight to the join-confirmation screen. A signed-out
/// user is handed to onboarding's invitee path, which shows the trip, signs
/// them in and, once it completes, lands them on the same join screen, so a
/// "tap link -> sign in -> land in the trip" flow works without losing the
/// invite.
///
/// Wraps the app's home so it sits *below* the [MaterialApp]'s [Navigator] and
/// can push named routes directly.
class DeepLinkHandler extends StatefulWidget {
  const DeepLinkHandler({required this.child, super.key});

  final Widget child;

  @override
  State<DeepLinkHandler> createState() => _DeepLinkHandlerState();
}

class _DeepLinkHandlerState extends State<DeepLinkHandler> {
  StreamSubscription<InviteLinkData>? _subscription;

  /// A link that cannot be routed yet: auth is still resolving, or the user is
  /// signed in but still finishing onboarding.
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
    _routePending();
  }

  void _routePending() {
    final pending = _pending;
    if (pending == null || !mounted) {
      return;
    }

    final onboarding = context.read<OnboardingCubit>();
    switch (context.read<AuthCubit>().state) {
      case AuthUnknown():
        return;
      case AuthUnauthenticated():
        _pending = null;
        unawaited(onboarding.startInvite(pending));
      case AuthAuthenticated():
        if (onboarding.state.isInProgress) {
          return;
        }
        _pending = null;
        _openJoinScreen(pending);
    }
  }

  void _onOnboardingCompleted(OnboardingState state) {
    final invite = state.inviteLink;
    if (invite != null) {
      _openJoinScreen(invite);
    }
    _routePending();
  }

  /// Deferred to a post-frame callback so it runs after the [AuthGate] has
  /// swapped in Home and reset its routes.
  void _openJoinScreen(InviteLinkData invite) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pushNamed(Paths.joinTrip, arguments: invite);
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
    return MultiBlocListener(
      listeners: [
        BlocListener<AuthCubit, AuthState>(
          listenWhen: (previous, current) => previous.runtimeType != current.runtimeType,
          listener: (_, _) => _routePending(),
        ),
        BlocListener<OnboardingCubit, OnboardingState>(
          listenWhen: (previous, current) => !previous.completed && current.completed,
          listener: (_, state) => _onOnboardingCompleted(state),
        ),
      ],
      child: widget.child,
    );
  }
}
