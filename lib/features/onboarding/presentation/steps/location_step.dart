import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/features/onboarding/bloc/onboarding_cubit.dart';
import 'package:xplore/features/onboarding/presentation/widgets/onboarding_buttons.dart';
import 'package:xplore/features/onboarding/presentation/widgets/onboarding_map_art.dart';
import 'package:xplore/features/onboarding/presentation/widgets/onboarding_scaffold.dart';

/// The last onboarding step: explains live location sharing and asks for the
/// location permission. Onboarding finishes whatever the user answers, so a
/// denial never traps them here.
class LocationStep extends StatefulWidget {
  const LocationStep({this.requestPermission, super.key});

  /// Asks the OS for location permission. Defaults to Geolocator's prompt;
  /// tests inject a fake.
  final Future<void> Function()? requestPermission;

  @override
  State<LocationStep> createState() => _LocationStepState();
}

class _LocationStepState extends State<LocationStep> {
  bool _requesting = false;

  Future<void> _turnOnLocation() async {
    final cubit = context.read<OnboardingCubit>();
    setState(() => _requesting = true);
    try {
      await (widget.requestPermission ?? _requestWithGeolocator)();
    } catch (_) {
      // A failed prompt (e.g. a missing Info.plist key) must not block the user;
      // the map asks again when it needs a position.
    } finally {
      if (mounted) {
        setState(() => _requesting = false);
      }
    }
    cubit.next();
  }

  static Future<void> _requestWithGeolocator() async {
    await Geolocator.requestPermission();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();
    final isInvitee = context.select((OnboardingCubit cubit) => cubit.state.path == OnboardingPath.invitee);

    return OnboardingStepScaffold(
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          OnboardingPrimaryButton(label: 'Turn on location', loading: _requesting, onPressed: _turnOnLocation),
          OnboardingTextButton(label: 'Not now', onPressed: _requesting ? null : cubit.skip),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isInvitee ? const _InviteeMap() : const _OrganizerMap(),
          const SizedBox(height: 28),
          isInvitee
              ? const OnboardingHeading(
                  title: 'Your group is on the map',
                  subtitle: 'Turn on location to see them, and let them find you.',
                )
              : const OnboardingHeading(
                  title: 'See each other on the map',
                  subtitle: 'No more “where are you?” texts. Your group shows up here as they join.',
                ),
          const SizedBox(height: 22),
          const _ReassuranceRow(icon: Icons.group_outlined, label: 'Your location shows on your trip’s map'),
          const SizedBox(height: 14),
          const _ReassuranceRow(icon: Icons.near_me_outlined, label: 'Shared only while you’re using Xplore'),
          const SizedBox(height: 14),
          const _ReassuranceRow(icon: Icons.settings_outlined, label: 'Change it any time in Settings'),
        ],
      ),
    );
  }
}

const _mapHeight = 250.0;

// Where the three other members sit around the user on the illustrated map.
const _memberSpots = [Alignment(-0.6, -0.62), Alignment(0.76, -0.4), Alignment(0.58, 0.65)];

/// The organizer's map: them at the centre, three open seats for the group.
class _OrganizerMap extends StatelessWidget {
  const _OrganizerMap();

  static const _you = Alignment(0, -0.1);

  @override
  Widget build(BuildContext context) {
    return OnboardingMapArt(
      height: _mapHeight,
      highlight: _you,
      pins: [
        const MapArtPin(alignment: _you, label: 'You'),
        for (final spot in _memberSpots) MapArtPin(alignment: spot, isPlaceholder: true),
      ],
    );
  }
}

/// The invitee's map: the group already there, and an open seat for them in
/// the middle. The pins carry no initials since members are not known yet.
class _InviteeMap extends StatelessWidget {
  const _InviteeMap();

  static const _memberColors = [OnboardingAvatarColors.sand, OnboardingAvatarColors.blue, OnboardingAvatarColors.coral];

  @override
  Widget build(BuildContext context) {
    return OnboardingMapArt(
      height: _mapHeight,
      highlight: Alignment.center,
      pins: [
        const MapArtPin(alignment: Alignment.center, label: 'You', isPlaceholder: true),
        for (var member = 0; member < _memberSpots.length; member++)
          MapArtPin(alignment: _memberSpots[member], color: _memberColors[member]),
      ],
    );
  }
}

class _ReassuranceRow extends StatelessWidget {
  const _ReassuranceRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: paddingUnit,
      children: [
        Icon(icon, size: 20, color: XploreColors.accent),
        Expanded(
          child: Text(label, style: XploreText.body.copyWith(color: XploreColors.inactiveControl)),
        ),
      ],
    );
  }
}
