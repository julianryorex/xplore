import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/core/app_tab.dart';
import 'package:xplore/features/nav/bloc/nav_cubit.dart';

const _tabWidth = 92.0;
const _tabHeight = 54.0;
const _tabGap = 2.0;
const _pillPadding = 4.0;
const _agentButtonSize = 62.0;

final _floatingShadow = BoxShadow(
  color: XploreColors.background.withValues(alpha: 0.5),
  offset: const Offset(0, 8),
  blurRadius: 28,
);

/// The floating tab bar: a centred glass pill with the tabs, plus the round
/// agent button beside it that toggles the agent quick menu.
///
/// It overlays the content behind it, so pair it with `Scaffold(extendBody: true)`.
class Navbar extends StatelessWidget {
  const Navbar({required this.isMenuOpen, required this.onAgentPressed, super.key});

  /// Whether the agent quick menu is open; the agent button then shows a close icon.
  final bool isMenuOpen;
  final VoidCallback onAgentPressed;

  /// Height of the bar row, excluding the gap below it.
  static const height = _tabHeight + 2 * _pillPadding + 2;

  /// Gap between the bar and the bottom screen edge: 26px on a phone with a
  /// home indicator, never less than 12px on one without.
  static double bottomGapOf(BuildContext context) => math.max(12, MediaQuery.viewPaddingOf(context).bottom - 8);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomGapOf(context)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _TabPill(),
          const SizedBox(width: 10),
          _AgentButton(isMenuOpen: isMenuOpen, onPressed: onAgentPressed),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill();

  // The tabs are top-level *siblings* living in `RootShell`'s stack, so
  // selecting one only flips the NavbarCubit index — no route is pushed. That's
  // what keeps tab switches from animating like forward/back navigation.
  void _selectTab(BuildContext context, AppTab tab) {
    final navCubit = context.read<NavbarCubit>();
    if (tab.index == navCubit.state) return;

    if (tab == AppTab.home) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    navCubit.setTab(tab);
  }

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(radiusXl));
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: [_floatingShadow]),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.all(_pillPadding),
            decoration: BoxDecoration(
              color: XploreColors.glassChrome,
              borderRadius: radius,
              border: Border.all(color: XploreColors.glassChromeBorder),
            ),
            child: BlocBuilder<NavbarCubit, int>(
              builder: (context, selectedIndex) {
                return Stack(
                  children: [
                    _SelectionIndicator(selectedIndex: selectedIndex),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: _tabGap,
                      children: [
                        for (final tab in AppTab.values)
                          _TabButton(
                            tab: tab,
                            isSelected: selectedIndex == tab.index,
                            onPressed: () => _selectTab(context, tab),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The highlight that glides behind the selected tab. This sliding cue is the
/// one bit of motion the tab bar earns, so the screens themselves need not slide.
class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator({required this.selectedIndex});

  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final lastIndex = AppTab.values.length - 1;
    return Positioned.fill(
      child: AnimatedAlign(
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: lastIndex == 0 ? Alignment.center : Alignment(-1 + 2 * selectedIndex / lastIndex, 0),
        child: const SizedBox(
          width: _tabWidth,
          height: _tabHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: XploreColors.glassChromeBorder,
              borderRadius: BorderRadius.all(Radius.circular(_tabHeight / 2)),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.tab, required this.isSelected, required this.onPressed});

  final AppTab tab;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final color = isSelected ? XploreColors.accent : XploreColors.inactiveControl;

    return Semantics(
      button: true,
      selected: isSelected,
      label: tab.label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          customBorder: const StadiumBorder(),
          child: SizedBox(
            width: _tabWidth,
            height: _tabHeight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 2,
              children: [
                TweenAnimationBuilder<Color?>(
                  duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 240),
                  tween: ColorTween(end: color),
                  builder: (context, animatedColor, _) => Icon(tab.icon, color: animatedColor, size: 24),
                ),
                Text(
                  tab.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    height: 1.2,
                    color: color,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AgentButton extends StatelessWidget {
  const _AgentButton({required this.isMenuOpen, required this.onPressed});

  final bool isMenuOpen;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      label: isMenuOpen ? 'Close menu' : 'Ask xplore',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [_floatingShadow]),
        child: Material(
          color: XploreColors.accent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              HapticFeedback.lightImpact();
              onPressed();
            },
            child: SizedBox.square(
              dimension: _agentButtonSize,
              child: AnimatedSwitcher(
                duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: isMenuOpen
                    ? const Icon(CupertinoIcons.xmark, key: ValueKey('close'), size: 22, color: XploreColors.onAccent)
                    : const Icon(Icons.auto_awesome, key: ValueKey('ask'), size: 26, color: XploreColors.onAccent),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
