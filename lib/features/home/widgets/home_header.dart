import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/core/xplore_wordmark.dart';
import 'package:xplore/features/profile/bloc/profile_cubit.dart';
import 'package:xplore/routes.dart';

/// Home's top bar: the wordmark, then notifications and the profile avatar.
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 0),
      child: Row(
        children: [
          const Expanded(child: XploreWordmark()),
          _CircleButton(
            semanticLabel: 'Notifications',
            color: XploreColors.card,
            onTap: () => context.push(Paths.notifications),
            child: const Icon(CupertinoIcons.bell, size: 20, color: XploreColors.white),
          ),
          const SizedBox(width: 8),
          const _ProfileButton(),
        ],
      ),
    );
  }
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      buildWhen: (a, b) => a.profilePicture != b.profilePicture || a.name != b.name,
      builder: (context, state) {
        final picture = state.profilePicture;
        final name = state.name.trim();

        return _CircleButton(
          semanticLabel: 'Open profile',
          color: XploreColors.white,
          image: picture == null ? null : MemoryImage(picture),
          onTap: () => context.push(Paths.profile),
          child: picture != null
              ? null
              : name.isEmpty
              ? const Icon(CupertinoIcons.person_fill, size: 20, color: XploreColors.background)
              : Text(
                  name.characters.first.toUpperCase(),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: XploreColors.background),
                ),
        );
      },
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.semanticLabel, required this.color, required this.onTap, this.child, this.image});

  final String semanticLabel;
  final Color color;
  final VoidCallback onTap;
  final Widget? child;
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: color,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          width: minTouchTarget,
          height: minTouchTarget,
          decoration: image == null
              ? null
              : BoxDecoration(
                  image: DecorationImage(image: image!, fit: BoxFit.cover),
                ),
          child: InkWell(
            onTap: onTap,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
