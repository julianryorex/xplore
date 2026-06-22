import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/features/nav/bloc/nav_cubit.dart';
import 'package:xplore/routes.dart';

class _NavBarItem {
  final String path;
  final String label;
  final IconData icon;

  const _NavBarItem({required this.path, required this.label, required this.icon});
}

const List<_NavBarItem> _navBarItems = [
  _NavBarItem(path: Paths.home, label: 'Home', icon: Icons.home_outlined),
  _NavBarItem(path: Paths.map, label: 'Map', icon: Icons.map_rounded),
];

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
    Navigator.pushReplacementNamed(ctx, _navBarItems[selectedIndex].path);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: navBarHeight,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: BlocBuilder<NavbarCubit, int>(
          builder: (context, state) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _navBarItems
                  .mapIndexed(
                    (index, item) => _NavbarButton(
                      item: item,
                      isSelected: state == index,
                      onPressed: state == index ? () {} : () => onIconClick(context, index),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ),
    );
  }
}

class _NavbarButton extends StatelessWidget {
  final _NavBarItem item;
  final bool isSelected;
  final VoidCallback onPressed;

  const _NavbarButton({required this.item, required this.isSelected, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final activeColor = XploreColors.alternate;
    final inactiveColor = XploreColors.white.withValues(alpha: 0.38);

    return Expanded(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: paddingUnit / 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, color: isSelected ? activeColor : inactiveColor, size: 28),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isSelected ? activeColor : inactiveColor,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
