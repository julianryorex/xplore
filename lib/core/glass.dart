import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xplore/constants/constants.dart';

/// A single liquid-glass material primitive.
///
/// Renders a translucent, backdrop-blurred surface with a hairline rim border
/// and a soft specular highlight along the top edge — the same recipe Apple's
/// Liquid Glass uses for the floating control layer. Whatever sits *behind* the
/// surface is blurred and tinted, so place these above colourful content
/// (see [AmbientBackground]) for the effect to read.
///
/// Keep glass for controls / floating chrome; content (lists, hero cards)
/// should stay on opaque surfaces for legibility.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final EdgeInsetsGeometry padding;
  final Color? tint;

  /// Use the stronger fill for small, dense controls (icon buttons, chips)
  /// where more contrast against busy backgrounds helps legibility.
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
    final fill = tint ?? (strong ? XploreColors.glassFillStrong : XploreColors.glassFill);

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
              border: Border.all(color: XploreColors.glassBorder),
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
