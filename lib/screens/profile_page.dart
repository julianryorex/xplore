import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/core/avatar.dart';
import 'package:xplore/core/header.dart';
import 'package:xplore/core/icon_button.dart';
import 'package:xplore/features/profile/bloc/profile_cubit.dart';

final assetPaths = ['assets/placeholders/skating.JPG', 'assets/placeholders/skytree.jpeg'];

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late int assetIndex;

  @override
  void initState() {
    super.initState();
    assetIndex = 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            BlocBuilder<ProfileCubit, ProfileState>(
              builder: (context, state) {
                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.only(top: paddingUnit * 4), //? for header
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: paddingUnit * 2,
                        right: paddingUnit * 2,
                        top: paddingUnit * 3,
                      ), //? for prettify padding
                      child: Column(
                        children: [
                          //! Header
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
                    ),
                  ),
                );
              },
            ),
            Header(
              leadingWidget: XploreIconBtn(
                onTapCallback: () => Navigator.pop(context),
                bgColor: XploreColors.darkBg,
                icon: const Icon(Icons.arrow_back, size: 35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
