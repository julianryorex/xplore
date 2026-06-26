import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/core/app_tab.dart';
import 'package:xplore/core/fade_indexed_stack.dart';
import 'package:xplore/core/navbar.dart';
import 'package:xplore/features/nav/bloc/nav_cubit.dart';
import 'package:xplore/screens/home_page.dart';
import 'package:xplore/screens/map_canvas.dart';

/// The authenticated app shell. Owns the single [Scaffold] + floating glass
/// [Navbar] and keeps the top-level destinations (Home, Map) alive in a
/// [FadeIndexedStack]. Tab switches change the [NavbarCubit] index only — no
/// route is pushed/replaced — so moving between tabs is a calm fade rather than
/// a forward/back slide, and the live map keeps its camera between visits.
class RootShell extends StatefulWidget {
  const RootShell({this.initialTab = AppTab.home, super.key});

  final AppTab initialTab;

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  bool _initialTabApplied = false;

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

  Widget _destinationFor(AppTab tab) {
    return switch (tab) {
      AppTab.home => const HomePage(),
      AppTab.map => const MapCanvas(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XploreColors.primaryBg,
      // Let content run full-bleed under the floating glass nav bar so the
      // backdrop blur has real content to refract.
      extendBody: true,
      bottomNavigationBar: const Navbar(),
      body: BlocBuilder<NavbarCubit, int>(
        builder: (context, index) {
          return FadeIndexedStack(
            index: index,
            children: [for (final tab in AppTab.values) _destinationFor(tab)],
          );
        },
      ),
    );
  }
}
