import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xplore/constants/constants.dart';

/// The shared surface primitive for cards and floating controls.
///
/// By default it is an opaque card ([XploreColors.card]). With [strong] (or a
/// translucent [tint]) it becomes floating chrome: a translucent, backdrop-blurred
/// fill with a hairline rim and a soft top highlight, for controls that sit over
/// photos or the map.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final EdgeInsetsGeometry padding;
  final Color? tint;

  /// Use the translucent chrome fill for small controls (icon buttons, chips)
  /// that float over photos, the map, or a card.
  final bool strong;
  final bool highlight;
  final VoidCallback? onTap;
  final bool hapticOnTap;

  const GlassSurface({
    required this.child,
    this.borderRadius = radiusLg,
    this.blur = glassBlur,
    this.padding = const EdgeInsets.all(paddingUnit * 1.5),
    this.tint,
    this.strong = false,
    this.highlight = true,
    this.onTap,
    this.hapticOnTap = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final fill = tint ?? (strong ? XploreColors.glassChrome : XploreColors.card);
    // An opaque fill is a plain card: the blur, rim and specular highlight only
    // read on translucent material, and on pure black they look like a stray outline.
    final translucent = fill.a < 1;

    Widget content = Padding(padding: padding, child: child);

    if (onTap != null) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () {
            if (hapticOnTap) HapticFeedback.lightImpact();
            onTap!();
          },
          borderRadius: radius,
          splashColor: XploreColors.white.withValues(alpha: 0.06),
          highlightColor: XploreColors.white.withValues(alpha: 0.04),
          child: content,
        ),
      );
    }

    if (!translucent) {
      return ClipRRect(
        borderRadius: radius,
        child: ColoredBox(color: fill, child: content),
      );
    }

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  fill,
                  fill.withValues(alpha: (fill.a - 0.05).clamp(0.0, 1.0)),
                ],
              ),
              border: Border.all(color: XploreColors.glassChromeBorder),
            ),
            child: Stack(
              children: [
                if (highlight)
                  Positioned(
                    top: 0,
                    left: borderRadius,
                    right: borderRadius,
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            XploreColors.white.withValues(alpha: 0),
                            XploreColors.glassHighlight,
                            XploreColors.white.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                content,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A square liquid-glass icon button, used for header / floating controls.
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final Color? iconColor;
  final String? tooltip;

  const GlassIconButton({
    required this.icon,
    required this.onTap,
    this.size = headerIconButtonSize,
    this.iconSize = headerIconSize,
    this.iconColor,
    this.tooltip,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: size,
      height: size,
      child: GlassSurface(
        borderRadius: radiusMd,
        strong: true,
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: Center(
          child: Icon(icon, size: iconSize, color: iconColor ?? XploreColors.white),
        ),
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
