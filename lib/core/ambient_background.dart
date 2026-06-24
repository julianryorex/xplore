import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';

/// Paints the app's base colour plus a few soft, brand-tinted radial glows.
///
/// This gives the [GlassSurface] layer something colourful to refract and blur,
/// which is what makes the liquid-glass material read as glass rather than a
/// flat translucent panel. Purely decorative and non-interactive.
class AmbientBackground extends StatelessWidget {
  final Widget child;

  const AmbientBackground({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    // Force the decorative layer to fill the whole screen. Without this the
    // Stack uses its loose fit and collapses to the height of its child (e.g. a
    // SingleChildScrollView sized to its content), leaving the page background
    // showing below it.
    return SizedBox.expand(
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Color(0xFF1E1A22))),
          Positioned(
            top: -140,
            left: -90,
            child: _Glow(color: XploreColors.alternate.withValues(alpha: 0.30), size: 340),
          ),
          Positioned(
            top: 120,
            right: -130,
            child: _Glow(color: XploreColors.secondary.withValues(alpha: 0.24), size: 380),
          ),
          Positioned(
            bottom: -120,
            left: -60,
            child: _Glow(color: XploreColors.secondaryBg.withValues(alpha: 0.18), size: 320),
          ),
          child,
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double size;

  const _Glow({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
