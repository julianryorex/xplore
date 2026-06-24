import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/core/header.dart';

class LayoutPadding extends StatelessWidget {
  final Widget child;
  final Widget? header;
  final bool enableHeaderPadding;

  const LayoutPadding({required this.child, this.enableHeaderPadding = true, this.header, super.key});

  @override
  Widget build(BuildContext context) {
    // True status-bar height read straight from the render view. We can't use
    // MediaQuery here: the enclosing SafeArea consumes the top inset and zeroes
    // it out for its descendants, so MediaQuery would report 0. Reading the
    // view directly lets the scrim reach up behind the status bar so the
    // ambient glow doesn't peek out above it as a hard teal band.
    final view = View.of(context);
    final topInset = view.viewPadding.top / view.devicePixelRatio;

    return Stack(
      // Allow the scrim to paint upward into the status-bar area, above this
      // widget's own bounds.
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: paddingUnit * 1.5,
            right: paddingUnit * 1.5,
            bottom: paddingUnit * 1.5,
            top: paddingUnit * 1.5 + (enableHeaderPadding && header != null ? Header.padding : 0),
          ),
          child: child,
        ),
        // Soft scrim so content scrolling beneath the floating header stays
        // legible without giving the header a heavy opaque bar. It extends up
        // over the status bar so the top of the screen fades evenly into the
        // ambient background instead of cutting off the glow abruptly.
        if (header != null)
          Positioned(
            top: -topInset,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: Header.padding + paddingUnit * 2 + topInset,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      XploreColors.primaryBg,
                      XploreColors.primaryBg.withValues(alpha: 0.85),
                      XploreColors.primaryBg.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.55, 1],
                  ),
                ),
              ),
            ),
          ),
        ?header,
      ],
    );
  }
}
