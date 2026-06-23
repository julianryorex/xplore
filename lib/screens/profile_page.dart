import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/core/avatar_map_icon.dart';
import 'package:xplore/core/header.dart';
import 'package:xplore/core/icon_button.dart';
import 'package:xplore/core/layout_padding.dart';
import 'package:xplore/features/auth/bloc/auth_cubit.dart';
import 'package:xplore/features/profile/bloc/profile_cubit.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: LayoutPadding(
          header: Header(
            leadingWidget: XploreIconBtn(
              onTapCallback: () => Navigator.pop(context),
              bgColor: XploreColors.darkBg,
              icon: const Icon(Icons.arrow_back, size: headerIconSize),
            ),
          ),
          child: Stack(
            children: [
              BlocBuilder<ProfileCubit, ProfileState>(
                builder: (context, state) {
                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Profile',
                              style: context.pText.headlineMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: paddingUnit),
                        AvatarMapIcon(
                          size: 100,
                          image: state.profilePicture != null
                              ? Image.memory(state.profilePicture!).image
                              : null,
                        ),
                        const SizedBox(height: paddingUnit),
                        const _SignedInAccountLabel(),
                        const SizedBox(height: paddingUnit * 2),
                        OutlinedButton(
                          onPressed: () async {
                            await context
                                .read<ProfileCubit>()
                                .changeProfilePicture();
                          },
                          child: Text(
                            'Change profile picture',
                            textAlign: TextAlign.center,
                            style: context.pText.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: paddingUnit),
                        OutlinedButton(
                          onPressed: () async => _confirmAndSignOut(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: XploreColors.error,
                            side: BorderSide(
                              color: XploreColors.error.withValues(alpha: 0.7),
                            ),
                          ),
                          child: Text(
                            'Sign out',
                            textAlign: TextAlign.center,
                            style: context.pText.bodySmall?.copyWith(
                              color: XploreColors.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: paddingUnit),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndSignOut(BuildContext context) async {
    final authCubit = context.read<AuthCubit>();
    final shouldSignOut =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Sign out?'),
              content: const Text(
                'You will return to the sign-in screen and can choose another Google account.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(
                    'Sign out',
                    style: TextStyle(color: XploreColors.error),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;

    if (shouldSignOut) {
      await authCubit.signOut();
    }
  }
}

class _SignedInAccountLabel extends StatelessWidget {
  const _SignedInAccountLabel();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      buildWhen: (previous, current) =>
          previous.runtimeType != current.runtimeType ||
          current is AuthAuthenticated,
      builder: (context, state) {
        if (state is! AuthAuthenticated) {
          return const SizedBox.shrink();
        }

        final subtitle = state.email ?? state.displayName;

        return Text(
          'Signed in as $subtitle',
          textAlign: TextAlign.center,
          style: context.pText.bodySmall?.copyWith(
            color: XploreColors.mutedText,
          ),
        );
      },
    );
  }
}
