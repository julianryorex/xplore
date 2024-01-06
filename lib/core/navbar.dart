import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/features/nav/bloc/nav_cubit.dart';
import 'package:xplore/routes.dart';

final Map<String, IconData> _navBarIcons = {
  Paths.home: Icons.home_outlined,
  Paths.map: Icons.map_rounded,
};

class Navbar extends StatelessWidget {
  const Navbar({super.key});

  void onIconClick(BuildContext ctx, int selectedIndex) {
    final currentIndex = ctx.read<NavbarCubit>().state;
    if (selectedIndex == 0 && currentIndex != 0) {
      HapticFeedback.heavyImpact();
    } else if (selectedIndex != currentIndex) {
      HapticFeedback.lightImpact();
    }

    ctx.read<NavbarCubit>().setNavIndex(selectedIndex);
    Navigator.pushReplacementNamed(ctx, _navBarIcons.keys.toList()[selectedIndex]);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80.0,
      decoration: BoxDecoration(
        color: XploreColors.primaryBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BlocBuilder<NavbarCubit, int>(
        builder: (context, state) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _navBarIcons.entries
                .mapIndexed(
                  (index, items) => IconButton(
                    highlightColor: Colors.transparent,
                    icon: Icon(items.value),
                    color: state == index ? XploreColors.secondary : XploreColors.white.withOpacity(0.3),
                    iconSize: 30.0,
                    onPressed: state == index ? () {} : () => onIconClick(context, index),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}
