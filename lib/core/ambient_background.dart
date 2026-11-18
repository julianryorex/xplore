import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';

/// The app's page background: true black, filling the available space.
///
/// Kept as a widget (rather than a scaffold colour) because pages stack their
/// floating headers and controls on top of it.
class AmbientBackground extends StatelessWidget {
  final Widget child;

  const AmbientBackground({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    // Expand so a short child (e.g. a scroll view sized to its content) cannot
    // collapse the background and leave the scaffold showing below it.
    return SizedBox.expand(
      child: ColoredBox(color: XploreColors.background, child: child),
    );
  }
}
