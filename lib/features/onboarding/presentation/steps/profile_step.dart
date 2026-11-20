import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/features/auth/bloc/auth_cubit.dart';
import 'package:xplore/features/onboarding/bloc/onboarding_cubit.dart';
import 'package:xplore/features/onboarding/presentation/widgets/onboarding_buttons.dart';
import 'package:xplore/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:xplore/features/profile/bloc/profile_cubit.dart';

/// The optional onboarding step that asks for a profile photo, the avatar that
/// marks the user on the map. Name and handle are not editable here yet: the
/// name is shown read-only from the signed-in account.
class ProfileStep extends StatelessWidget {
  const ProfileStep({super.key});

  @override
  Widget build(BuildContext context) {
    final onboarding = context.read<OnboardingCubit>();
    final isInvitee = context.select<OnboardingCubit, bool>((cubit) => cubit.state.path == OnboardingPath.invitee);

    return OnboardingStepScaffold(
      skippable: true,
      footer: OnboardingPrimaryButton(label: 'Continue', onPressed: onboarding.next),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          OnboardingHeading(
            title: isInvitee ? 'Let the group know it’s you' : 'How should the group see you?',
            subtitle: isInvitee
                ? 'A photo helps the group spot you on the map.'
                : 'Your photo marks you on the map and on the photos you share.',
          ),
          const SizedBox(height: paddingUnit * 8 / 3),
          const _PhotoPicker(),
        ],
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker();

  void _pickPhoto(BuildContext context) => unawaited(context.read<ProfileCubit>().changeProfilePicture());

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileCubit>().state;
    final name = _displayName(context, profile);
    final image = _avatarImage(profile);

    return Column(
      children: [
        _Avatar(image: image, initial: _initialOf(name), onTap: () => _pickPhoto(context)),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () => _pickPhoto(context),
          style: TextButton.styleFrom(
            foregroundColor: XploreColors.accent,
            minimumSize: const Size(minTouchTarget, minTouchTarget),
            padding: const EdgeInsets.symmetric(horizontal: paddingUnit),
            textStyle: XploreText.body.copyWith(fontWeight: FontWeight.w600),
          ),
          child: Text(image == null ? 'Add a photo' : 'Change photo'),
        ),
        if (name.isNotEmpty) ...[
          const SizedBox(height: paddingUnit),
          Text(
            name,
            textAlign: TextAlign.center,
            style: XploreText.heading.copyWith(color: XploreColors.white),
          ),
        ],
        const SizedBox(height: paddingUnit),
        Text(
          'You can change your photo later in your profile.',
          textAlign: TextAlign.center,
          style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel),
        ),
      ],
    );
  }

  /// The profile's name, falling back to the signed-in account's until the
  /// profile has loaded.
  static String _displayName(BuildContext context, ProfileState profile) {
    final fromProfile = profile.name.trim();
    if (fromProfile.isNotEmpty) {
      return fromProfile;
    }
    final auth = context.watch<AuthCubit>().state;
    return auth is AuthAuthenticated ? auth.displayName.trim() : '';
  }

  /// Freshly picked bytes win; otherwise the synced cloud avatar, if any.
  static ImageProvider? _avatarImage(ProfileState profile) {
    final bytes = profile.profilePicture;
    if (bytes != null) {
      return MemoryImage(bytes);
    }
    final url = profile.photoUrl;
    return url == null || url.isEmpty ? null : NetworkImage(url);
  }

  static String _initialOf(String name) => name.isEmpty ? '?' : name.characters.first.toUpperCase();
}

/// The 112pt avatar with its Jade camera badge. Tapping it picks a photo too;
/// it is hidden from screen readers since the text button below does the same.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.image, required this.initial, required this.onTap});

  final ImageProvider? image;
  final String initial;
  final VoidCallback onTap;

  static const _size = 112.0;
  static const _badgeSize = 38.0;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox.square(
          dimension: _size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: _size,
                height: _size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: XploreColors.raised,
                  shape: BoxShape.circle,
                  image: image == null ? null : DecorationImage(image: image!, fit: BoxFit.cover),
                ),
                child: image == null
                    ? Text(
                        initial,
                        // Bespoke size: a monogram scaled to the avatar, not running text.
                        style: const TextStyle(
                          fontFamily: systemFontFamily,
                          fontSize: 44,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -1,
                          color: XploreColors.white,
                        ),
                      )
                    : null,
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: _badgeSize,
                  height: _badgeSize,
                  decoration: BoxDecoration(
                    color: XploreColors.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: XploreColors.background, width: 3),
                  ),
                  child: const Icon(Icons.photo_camera_rounded, size: 18, color: XploreColors.onAccent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
