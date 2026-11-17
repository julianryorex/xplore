import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/core/app_tab.dart';
import 'package:xplore/core/fade_indexed_stack.dart';
import 'package:xplore/core/navbar.dart';
import 'package:xplore/features/agent/presentation/agent_quick_menu.dart';
import 'package:xplore/features/nav/bloc/nav_cubit.dart';
import 'package:xplore/features/trip/bloc/trip_cubit.dart';
import 'package:xplore/features/trip/bloc/trip_state.dart';
import 'package:xplore/screens/home_page.dart';
import 'package:xplore/screens/map_canvas.dart';

/// Space between the top of the tab bar row and the bottom of the agent quick menu.
const _menuGapAboveNavbar = 14.0;

/// The authenticated app shell. Owns the single [Scaffold] + floating glass
/// [Navbar] and keeps the top-level destinations (Home, Map) alive in a
/// [FadeIndexedStack]. Tab switches change the [NavbarCubit] index only — no
/// route is pushed/replaced — so moving between tabs is a calm fade rather than
/// a forward/back slide, and the live map keeps its camera between visits.
///
/// It also owns the agent quick menu, layered between the body and the navbar
/// so its scrim dims the page but not the bar.
class RootShell extends StatefulWidget {
  const RootShell({this.initialTab = AppTab.home, super.key});

  final AppTab initialTab;

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  bool _initialTabApplied = false;
  bool _isMenuOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyInitialTab();
  }

  @override
  void didUpdateWidget(RootShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _initialTabApplied = false;
      _applyInitialTab();
    }
  }

  void _applyInitialTab() {
    if (_initialTabApplied) return;
    _initialTabApplied = true;
    final navCubit = context.read<NavbarCubit>();
    if (navCubit.state != widget.initialTab.index) {
      navCubit.setTab(widget.initialTab);
    }
  }

  void _toggleMenu() => setState(() => _isMenuOpen = !_isMenuOpen);

  void _closeMenu() {
    if (_isMenuOpen) setState(() => _isMenuOpen = false);
  }

  Widget _destinationFor(AppTab tab) {
    return switch (tab) {
      AppTab.home => const HomePage(),
      AppTab.map => const MapCanvas(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final menuBottomOffset = Navbar.bottomGapOf(context) + Navbar.height + _menuGapAboveNavbar;

    // A user without trips gets Home's own prompt field instead of the tab bar,
    // so there is nothing to switch to and no agent button to open the menu.
    return BlocConsumer<TripCubit, TripState>(
      listenWhen: (previous, current) => current is TripEmpty,
      listener: (context, _) => _closeMenu(),
      buildWhen: (previous, current) => (previous is TripEmpty) != (current is TripEmpty),
      builder: (context, tripState) {
        final showsNavbar = tripState is! TripEmpty;
        final isMenuOpen = _isMenuOpen && showsNavbar;

        return PopScope(
          canPop: !isMenuOpen,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _closeMenu();
          },
          child: Scaffold(
            backgroundColor: XploreColors.background,
            // Let content run full-bleed under the floating glass nav bar so the
            // backdrop blur has real content to refract.
            extendBody: true,
            bottomNavigationBar: showsNavbar ? Navbar(isMenuOpen: isMenuOpen, onAgentPressed: _toggleMenu) : null,
            body: Stack(
              fit: StackFit.expand,
              children: [
                BlocBuilder<NavbarCubit, int>(
                  builder: (context, index) {
                    return FadeIndexedStack(
                      index: showsNavbar ? index : AppTab.home.index,
                      children: [for (final tab in AppTab.values) _destinationFor(tab)],
                    );
                  },
                ),
                Positioned.fill(
                  child: AgentQuickMenu(isOpen: isMenuOpen, onClose: _closeMenu, bottomOffset: menuBottomOffset),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
