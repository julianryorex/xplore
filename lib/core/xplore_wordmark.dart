import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/theme.dart';

/// The lowercase "xplore" wordmark, the one place the app uses Manrope.
class XploreWordmark extends StatelessWidget {
  const XploreWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'xplore',
      style: TextStyle(
        fontFamily: wordmarkFontFamily,
        fontSize: 22,
        // Manrope ships as a variable font, so the weight axis has to be set
        // explicitly; `fontWeight` alone leaves it at the default instance.
        fontWeight: FontWeight.w800,
        fontVariations: [FontVariation('wght', 800)],
        letterSpacing: -0.8,
        height: 1.2,
        color: XploreColors.white,
      ),
    );
  }
}
