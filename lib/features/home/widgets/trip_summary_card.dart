import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/features/home/models/trip_overview.dart';
import 'package:xplore/features/home/widgets/capsule_button.dart';
import 'package:xplore/features/profile/bloc/profile_cubit.dart';
import 'package:xplore/features/trip/presentation/trip_invite_sharer.dart';

/// The card under the trip hero: countdown, traveler count and planning
/// progress, then the members row with an Invite button.
class TripSummaryCard extends StatelessWidget {
  const TripSummaryCard({required this.overview, super.key});

  final TripOverview overview;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      decoration: BoxDecoration(color: XploreColors.card, borderRadius: BorderRadius.circular(radiusLg)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(child: _timingStat()),
                  const _VerticalHairline(),
                  Expanded(child: _travelersStat()),
                  const _VerticalHairline(),
                  Expanded(child: _plannedStat()),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 16),
            child: ColoredBox(
              color: XploreColors.separator,
              child: SizedBox(height: 1, width: double.infinity),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                Expanded(child: _MemberAvatars(otherMembers: overview.trip.memberIds.length - 1)),
                const SizedBox(width: 12),
                _InviteButton(overview: overview),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _Stat _timingStat() {
    return switch (overview.timing) {
      TripTiming.upcoming => _Stat(
        value: '${overview.daysToGo}',
        label: overview.daysToGo == 1 ? 'day to go' : 'days to go',
        accent: true,
      ),
      TripTiming.ongoing => _Stat(
        value: 'Day ${overview.currentDayNumber}',
        label: overview.lengthInDays == null ? 'of the trip' : 'of ${overview.lengthInDays}',
        accent: true,
      ),
      TripTiming.past => const _Stat(value: 'Done', label: 'trip ended', accent: true),
      TripTiming.undated => const _Stat(value: '—', label: 'no dates yet', accent: true),
    };
  }

  _Stat _travelersStat() {
    final count = overview.trip.memberIds.length;
    return _Stat(value: '$count', label: count == 1 ? 'traveler' : 'travelers');
  }

  _Stat _plannedStat() {
    final planned = overview.plannedDays;
    final length = overview.lengthInDays;
    if (length == null) {
      return _Stat(value: '$planned', label: planned == 1 ? 'day planned' : 'days planned');
    }
    return _Stat(value: '$planned of $length', label: 'days planned');
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.accent = false});

  final String value;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Values like "12 of 14" must stay whole, so they shrink rather than truncate.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: accent ? XploreColors.accent : XploreColors.white,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: XploreColors.secondaryLabel),
        ),
      ],
    );
  }
}

class _VerticalHairline extends StatelessWidget {
  const _VerticalHairline();

  @override
  Widget build(BuildContext context) => const ColoredBox(color: XploreColors.separator, child: SizedBox(width: 1));
}

/// The signed-in user's avatar plus one "+N" bubble for everyone else: Firestore
/// rules only let a user read their own profile, so other members' names and
/// photos are not available here.
class _MemberAvatars extends StatelessWidget {
  const _MemberAvatars({required this.otherMembers});

  final int otherMembers;

  static const _size = 32.0;
  static const _overlap = 8.0;

  @override
  Widget build(BuildContext context) {
    final semanticsLabel = otherMembers > 0
        ? 'You and $otherMembers other ${otherMembers == 1 ? 'traveler' : 'travelers'}'
        : 'Just you';

    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: Row(
        children: [
          BlocBuilder<ProfileCubit, ProfileState>(
            buildWhen: (previous, current) =>
                previous.name != current.name || previous.profilePicture != current.profilePicture,
            builder: (context, profile) => _AvatarBubble(child: _ownAvatarContent(profile)),
          ),
          if (otherMembers > 0)
            Transform.translate(
              offset: const Offset(-_overlap, 0),
              child: _AvatarBubble(
                child: Text(
                  '+$otherMembers',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: XploreColors.secondaryLabel),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _ownAvatarContent(ProfileState profile) {
    final picture = profile.profilePicture;
    if (picture != null) {
      return Image.memory(picture, fit: BoxFit.cover, width: _size, height: _size, gaplessPlayback: true);
    }
    final name = profile.name.trim();
    return Text(
      name.isEmpty ? '?' : name.characters.first.toUpperCase(),
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: XploreColors.white),
    );
  }
}

class _AvatarBubble extends StatelessWidget {
  const _AvatarBubble({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _MemberAvatars._size,
      height: _MemberAvatars._size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: XploreColors.raised,
        border: Border.all(color: XploreColors.card, width: 2, strokeAlign: BorderSide.strokeAlignOutside),
      ),
      child: child,
    );
  }
}

class _InviteButton extends StatefulWidget {
  const _InviteButton({required this.overview});

  final TripOverview overview;

  @override
  State<_InviteButton> createState() => _InviteButtonState();
}

class _InviteButtonState extends State<_InviteButton> {
  bool _sharing = false;

  Future<void> _invite() async {
    if (_sharing) {
      return;
    }
    setState(() => _sharing = true);
    try {
      await shareTripInvite(context, widget.overview.trip);
    } finally {
      if (mounted) {
        setState(() => _sharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CapsuleButton(
      label: 'Invite',
      onPressed: _sharing ? null : _invite,
      backgroundColor: XploreColors.white,
      foregroundColor: XploreColors.background,
      horizontalPadding: 18,
      leading: _sharing
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: XploreColors.background),
            )
          : const Icon(CupertinoIcons.share, size: 16),
    );
  }
}
