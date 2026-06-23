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
    return Stack(
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
        // legible without giving the header a heavy opaque bar.
        if (header != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: Header.padding + paddingUnit * 2,
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
