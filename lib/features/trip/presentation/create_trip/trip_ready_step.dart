import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/features/trip/bloc/trip_creation_cubit.dart';
import 'package:xplore/features/trip/models/trip_draft.dart';
import 'package:xplore/features/trip/presentation/create_trip/plan_step.dart';
import 'package:xplore/features/trip/presentation/trip_invite_sharer.dart';

/// The closing screen once the trip exists: what was created, and the invite.
/// Group trips lead with sharing the invite link; solo trips lead with going
/// to the trip. There is no way back into the editing steps from here.
class TripReadyStep extends StatelessWidget {
  const TripReadyStep({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TripCreationCubit>().state;
    final draft = state.draft;
    final trip = state.createdTrip;
    final solo = draft.isSolo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const Align(alignment: Alignment.centerLeft, child: _CheckBadge()),
        const SizedBox(height: 28),
        Text(
          trip?.title ?? draft.effectiveTitle,
          style: XploreText.footnoteStrong.copyWith(color: XploreColors.accent),
        ),
        const SizedBox(height: 10),
        Semantics(header: true, child: Text(trip?.headline ?? draft.headline, style: XploreText.display)),
        const SizedBox(height: 12),
        Text(_lengthLine(draft), style: XploreText.body.copyWith(color: XploreColors.secondaryLabel)),
        const SizedBox(height: 48),
        if (!solo) ...[
          const Text('Bring your crew', style: XploreText.heading),
          const SizedBox(height: 6),
          Text(
            'Share a link so they can join and plan with you. You can also invite people later from the trip.',
            style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel),
          ),
        ] else
          Text(
            'All set. Travelling with someone after all? You can share an invite link now or anytime later.',
            style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel),
          ),
        const SizedBox(height: 24),
        _ReadyActions(solo: solo, canShare: trip != null),
      ],
    );
  }

  /// "Apr 3 – Apr 13 · 11 days · 4 places", or "Flexible dates" in place of the
  /// range. The headline already names the place, so this line only adds shape.
  static String _lengthLine(TripDraft draft) {
    final days = draft.durationDays;
    return [
      tripDateRangeLabel(draft) ?? 'Flexible dates',
      days == 1 ? '1 day' : '$days days',
      if (draft.stops.length > 1) '${draft.stops.length} places',
    ].join(' · ');
  }
}

class _CheckBadge extends StatelessWidget {
  const _CheckBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: XploreColors.accent),
      child: const Icon(Icons.check_rounded, size: 24, color: XploreColors.onAccent, semanticLabel: 'Trip created'),
    );
  }
}

/// Share and "Go to trip", ordered by what the trip most likely needs next.
class _ReadyActions extends StatefulWidget {
  const _ReadyActions({required this.solo, required this.canShare});

  final bool solo;
  final bool canShare;

  @override
  State<_ReadyActions> createState() => _ReadyActionsState();
}

class _ReadyActionsState extends State<_ReadyActions> {
  bool _sharing = false;

  /// [buttonContext] anchors the share sheet on iPad.
  Future<void> _share(BuildContext buttonContext) async {
    final trip = context.read<TripCreationCubit>().state.createdTrip;
    if (trip == null || _sharing) {
      return;
    }
    setState(() => _sharing = true);
    try {
      await shareTripInvite(buttonContext, trip);
    } finally {
      if (mounted) {
        setState(() => _sharing = false);
      }
    }
  }

  // The trip was made active on creation, so leaving the flow lands on the
  // home screen showing it.
  void _goToTrip() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final share = Builder(
      builder: (buttonContext) => _ActionButton(
        label: 'Share invite link',
        primary: !widget.solo,
        busy: _sharing,
        // Stays enabled while busy so the spinner sits on the normal fill; _share ignores repeat taps.
        onPressed: widget.canShare ? () => _share(buttonContext) : null,
      ),
    );
    final goToTrip = _ActionButton(label: 'Go to trip', primary: widget.solo, onPressed: _goToTrip);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widget.solo
          ? [goToTrip, const SizedBox(height: 4), share]
          : [share, const SizedBox(height: 4), goToTrip],
    );
  }
}

/// The primary action is a white pill; the secondary one is quiet text.
class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.primary, required this.onPressed, this.busy = false});

  final String label;
  final bool primary;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: primary ? XploreColors.background : XploreColors.secondaryLabel,
            ),
          )
        : Text(label);

    if (!primary) {
      return TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size.fromHeight(minTouchTarget),
          foregroundColor: XploreColors.secondaryLabel,
          textStyle: XploreText.bodyStrong,
        ),
        child: child,
      );
    }
    // The theme's filled button is already the white capsule the flow uses.
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), textStyle: XploreText.bodyStrong),
      child: child,
    );
  }
}
