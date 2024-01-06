import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/core/avatar_map_icon.dart';
import 'package:xplore/core/header.dart';
import 'package:xplore/core/icon_button.dart';
import 'package:xplore/core/layout_padding.dart';
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
              icon: const Icon(Icons.arrow_back, size: 35),
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
                            Text('Profile', style: context.pText.headlineMedium),
                          ],
                        ),
                        const SizedBox(height: paddingUnit),
                        AvatarMapIcon(
                          size: 100,
                          image: state.profilePicture != null ? Image.memory(state.profilePicture!).image : null,
                        ),
                        const SizedBox(height: paddingUnit * 2),
                        OutlinedButton(
                          onPressed: () async {
                            await context.read<ProfileCubit>().changeProfilePicture();
                          },
                          child: Text(
                            'Change profile picture',
                            textAlign: TextAlign.center,
                            style: context.pText.bodySmall?.copyWith(fontWeight: FontWeight.w500),
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
}
