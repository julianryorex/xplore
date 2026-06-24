import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
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
///
/// `_destinations` order must stay in sync with [navBarItems] in `navbar.dart`.
class RootShell extends StatelessWidget {
  const RootShell({super.key});

  static const List<Widget> _destinations = [HomePage(), MapCanvas()];

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
          return FadeIndexedStack(index: index, children: _destinations);
        },
      ),
    );
  }
}
