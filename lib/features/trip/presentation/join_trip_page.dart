import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/core/ambient_background.dart';
import 'package:xplore/core/glass.dart';
import 'package:xplore/core/header.dart';
import 'package:xplore/features/trip/bloc/join_trip_cubit.dart';
import 'package:xplore/features/trip/bloc/join_trip_state.dart';
import 'package:xplore/features/trip/bloc/trip_cubit.dart';
import 'package:xplore/features/trip/models/trip_invite.dart';
import 'package:xplore/features/trip/services/invite_results.dart';

/// The join-confirmation screen reached via an invite deep link.
///
/// Liquid-glass styled to match the rest of the app: an [AmbientBackground]
/// with a centred glass "trip card" (name + member avatars + CTA). It handles
/// the loading, ready, joining, joined and invalid states; on success it makes
/// the joined trip active via [TripCubit] and returns to Home.
class JoinTripPage extends StatefulWidget {
  const JoinTripPage({super.key});

  @override
  State<JoinTripPage> createState() => _JoinTripPageState();
}

class _JoinTripPageState extends State<JoinTripPage> {
  @override
  void initState() {
    super.initState();
    // Kick off the invite lookup once the cubit is in the tree.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<JoinTripCubit>().loadPreview();
    });
  }

  void _onJoined(BuildContext context, String tripId) {
    context.read<TripCubit>().setActiveTrip(tripId);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final topInset = viewPadding.top;
    const headerTopGap = paddingUnit * 0.75;

    return Scaffold(
      backgroundColor: XploreColors.primaryBg,
      body: AmbientBackground(
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(
                  left: paddingUnit * 1.5,
                  right: paddingUnit * 1.5,
                  top: topInset + Header.padding,
                  bottom: viewPadding.bottom + paddingUnit * 2,
                ),
                child: Center(
                  child: BlocConsumer<JoinTripCubit, JoinTripState>(
                    listenWhen: (previous, current) => current is JoinTripJoined,
                    listener: (context, state) {
                      if (state is JoinTripJoined) {
                        _onJoined(context, state.trip.id);
                      }
                    },
                    builder: (context, state) {
                      return switch (state) {
                        JoinTripLooking() => const _JoinLoading(),
                        JoinTripReady(:final invite) => _JoinCard(invite: invite, isJoining: false),
                        JoinTripJoining(:final invite) => _JoinCard(invite: invite, isJoining: true),
                        // Joined is transient — the listener navigates away.
                        JoinTripJoined() => const _JoinLoading(),
                        JoinTripInvalid(:final reason) => _JoinInvalid(reason: reason),
                      };
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              top: topInset + headerTopGap,
              left: 0,
              right: 0,
              child: Header(
                leadingWidget: GlassIconButton(
                  size: 44,
                  iconSize: 20,
                  icon: Icons.close_rounded,
                  tooltip: 'Close',
                  onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinLoading extends StatelessWidget {
  const _JoinLoading();

  @override
  Widget build(BuildContext context) {
    return CircularProgressIndicator(color: XploreColors.alternate);
  }
}

class _JoinCard extends StatelessWidget {
  const _JoinCard({required this.invite, required this.isJoining});

  final TripInvite invite;
  final bool isJoining;

  @override
  Widget build(BuildContext context) {
    final memberCount = invite.memberCount;
    final spotsLeft = (maxFreeTierTripMembers - memberCount).clamp(0, maxFreeTierTripMembers);

    return GlassSurface(
      strong: true,
      padding: const EdgeInsets.all(paddingUnit * 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(paddingUnit),
            decoration: BoxDecoration(
              color: XploreColors.alternate.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(radiusMd),
              border: Border.all(color: XploreColors.alternate.withValues(alpha: 0.32)),
            ),
            child: Icon(Icons.flight_takeoff_rounded, color: XploreColors.alternate, size: 28),
          ),
          const SizedBox(height: paddingUnit * 1.25),
          Text(
            'You\u2019re invited to join',
            style: context.pText.labelSmall?.copyWith(color: XploreColors.subtleText),
          ),
          const SizedBox(height: 4),
          Text(
            invite.tripTitle.isEmpty ? 'a trip' : invite.tripTitle,
            style: context.pText.headlineSmall?.copyWith(letterSpacing: -0.3),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: paddingUnit * 1.25),
          _AvatarStack(memberCount: memberCount),
          const SizedBox(height: paddingUnit * 0.75),
          Text(
            _membersLabel(memberCount, spotsLeft),
            style: context.pText.bodySmall?.copyWith(color: XploreColors.mutedText),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: paddingUnit * 1.75),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isJoining ? null : () => context.read<JoinTripCubit>().join(),
              child: isJoining
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Join trip'),
            ),
          ),
          const SizedBox(height: paddingUnit * 0.5),
          TextButton(
            onPressed: isJoining ? null : () => Navigator.of(context).popUntil((route) => route.isFirst),
            child: const Text('Not now'),
          ),
        ],
      ),
    );
  }

  String _membersLabel(int memberCount, int spotsLeft) {
    final memberText = memberCount == 1 ? '1 traveler' : '$memberCount travelers';
    if (spotsLeft <= 0) {
      return '$memberText \u00b7 trip is full';
    }
    return '$memberText \u00b7 $spotsLeft ${spotsLeft == 1 ? 'spot' : 'spots'} left';
  }
}

/// A compact, overlapping stack of generic member avatars.
///
/// Real per-member photos are intentionally *not* fetched here: Firestore rules
/// restrict `users/{uid}` reads to the owner, so a not-yet-member cannot read
/// other travelers' profiles. We render count-based glass circles instead;
/// swap for real avatars if/when a member-preview is denormalised server-side.
class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.memberCount});

  final int memberCount;

  static const _maxShown = 4;
  static const _size = 40.0;
  static const _overlap = 12.0;

  @override
  Widget build(BuildContext context) {
    final shown = memberCount.clamp(1, _maxShown);
    final overflow = memberCount - shown;

    final circles = <Widget>[
      for (var i = 0; i < shown; i++)
        _AvatarCircle(child: Icon(Icons.person_rounded, size: 20, color: XploreColors.white)),
      if (overflow > 0)
        _AvatarCircle(
          child: Text('+$overflow', style: context.pText.labelSmall?.copyWith(color: XploreColors.white)),
        ),
    ];

    return SizedBox(
      height: _size,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < circles.length; i++)
            Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : _size - _overlap),
              child: circles[i],
            ),
        ],
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _AvatarStack._size,
      height: _AvatarStack._size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: XploreColors.glassFillStrong,
        border: Border.all(color: XploreColors.primaryBg, width: 2),
      ),
      child: child,
    );
  }
}

class _JoinInvalid extends StatelessWidget {
  const _JoinInvalid({required this.reason});

  final InviteFailureReason reason;

  @override
  Widget build(BuildContext context) {
    final canRetry = reason == InviteFailureReason.unavailable;

    return GlassSurface(
      strong: true,
      padding: const EdgeInsets.all(paddingUnit * 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(paddingUnit),
            decoration: BoxDecoration(
              color: XploreColors.alternate.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(radiusMd),
              border: Border.all(color: XploreColors.alternate.withValues(alpha: 0.28)),
            ),
            child: Icon(_iconFor(reason), color: XploreColors.alternate, size: 28),
          ),
          const SizedBox(height: paddingUnit * 1.25),
          Text(reason.title, style: context.pText.labelLarge, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            reason.message,
            style: context.pText.bodySmall?.copyWith(color: XploreColors.mutedText),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: paddingUnit * 1.75),
          if (canRetry)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.read<JoinTripCubit>().loadPreview(),
                child: const Text('Try again'),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text('Back to Xplore'),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(InviteFailureReason reason) => switch (reason) {
    InviteFailureReason.notFound => Icons.link_off_rounded,
    InviteFailureReason.revoked => Icons.block_rounded,
    InviteFailureReason.expired => Icons.timer_off_rounded,
    InviteFailureReason.tripFull => Icons.groups_rounded,
    InviteFailureReason.unavailable => Icons.cloud_off_rounded,
  };
}
