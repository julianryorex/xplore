import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/core/glass.dart';
import 'package:xplore/features/nav/bloc/nav_cubit.dart';

class _NavBarItem {
  final String label;
  final IconData icon;

  const _NavBarItem({required this.label, required this.icon});
}

/// Order must stay in sync with `RootShell`'s destination list.
const List<_NavBarItem> _navBarItems = [
  _NavBarItem(label: 'Home', icon: Icons.home_outlined),
  _NavBarItem(label: 'Map', icon: Icons.map_rounded),
];

class Navbar extends StatelessWidget {
  const Navbar({super.key});

  // The tabs are top-level *siblings* living in `RootShell`'s IndexedStack, so
  // selecting one only flips the NavbarCubit index — no route is pushed. That's
  // what keeps tab switches from animating like forward/back navigation.
  void onIconClick(BuildContext ctx, int selectedIndex) {
    final currentIndex = ctx.read<NavbarCubit>().state;
    if (selectedIndex == currentIndex) return;

    if (selectedIndex == 0) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    ctx.read<NavbarCubit>().setNavIndex(selectedIndex);
  }

  /// Horizontal alignment for the selection pill behind item [index].
  Alignment _pillAlignment(int index) {
    if (_navBarItems.length < 2) return Alignment.center;
    return Alignment(-1 + 2 * index / (_navBarItems.length - 1), 0);
  }

  @override
  Widget build(BuildContext context) {
    // A floating liquid-glass tab bar: it overlays the content behind it
    // (pair with `Scaffold(extendBody: true)`) so the backdrop blur has real
    // content to refract, giving the footer its glass feel.
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: paddingUnit / 2),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: paddingUnit * 1.5),
        // Drop shadow lifts the bar off the content so it reads as floating
        // glass; the lower-opacity tint + heavier blur let the content scrolling
        // underneath show through.
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radiusXl),
            boxShadow: [
              BoxShadow(
                color: XploreColors.black.withValues(alpha: 0.38),
                blurRadius: 28,
                spreadRadius: -4,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: GlassSurface(
            borderRadius: radiusXl,
            blur: 28,
            tint: XploreColors.surface.withValues(alpha: 0.28),
            padding: const EdgeInsets.symmetric(horizontal: paddingUnit / 2),
            child: SizedBox(
              height: 62,
              child: BlocBuilder<NavbarCubit, int>(
                builder: (context, state) {
                  return Stack(
                    children: [
                      // Selection pill that glides between tabs. This sliding
                      // accent is the one bit of motion the tab bar earns —
                      // it cues the change without the screens themselves
                      // having to slide.
                      AnimatedAlign(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        alignment: _pillAlignment(state),
                        child: FractionallySizedBox(
                          widthFactor: 1 / _navBarItems.length,
                          heightFactor: 1,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: paddingUnit / 2,
                              vertical: paddingUnit * 0.6,
                            ),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: XploreColors.alternate.withValues(
                                  alpha: 0.16,
                                ),
                                borderRadius: BorderRadius.circular(radiusMd),
                                border: Border.all(
                                  color: XploreColors.alternate.withValues(
                                    alpha: 0.28,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: _navBarItems
                            .mapIndexed(
                              (index, item) => _NavbarButton(
                                item: item,
                                isSelected: state == index,
                                onPressed: state == index
                                    ? () {}
                                    : () => onIconClick(context, index),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavbarButton extends StatelessWidget {
  final _NavBarItem item;
  final bool isSelected;
  final VoidCallback onPressed;

  const _NavbarButton({
    required this.item,
    required this.isSelected,
    required this.onPressed,
  });

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
              AnimatedScale(
                scale: isSelected ? 1.0 : 0.9,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                child: TweenAnimationBuilder<Color?>(
                  duration: const Duration(milliseconds: 240),
                  tween: ColorTween(
                    end: isSelected ? activeColor : inactiveColor,
                  ),
                  builder: (context, color, _) =>
                      Icon(item.icon, color: color, size: 28),
                ),
              ),
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
