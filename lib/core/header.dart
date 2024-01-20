import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/core/icon_button.dart';

class Header extends StatelessWidget {
  const Header({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: paddingUnit * 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          XploreIconBtn(
            onTapCallback: () {
              print('tapped');
            },
            icon: const Icon(Icons.person_2_outlined),
          ),
          XploreIconBtn(
            onTapCallback: () {
              print('tapped');
            },
            icon: const Icon(Icons.notifications),
          ),
        ],
      ),
    );
  }
}
