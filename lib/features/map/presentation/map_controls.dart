import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xplore/constants/constants.dart';

/// The map's floating controls: one capsule holding the style picker and the
/// recenter action, in the same material as the tab bar so they read as one set.
class MapControls extends StatelessWidget {
  const MapControls({required this.onPickStyle, required this.onRecenter, super.key});

  final VoidCallback onPickStyle;
  final VoidCallback onRecenter;

  static const _width = 48.0;
  static const _radius = BorderRadius.all(Radius.circular(_width / 2));

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: _radius,
        boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 20, offset: Offset(0, 6))],
      ),
      child: ClipRRect(
        borderRadius: _radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            width: _width,
            decoration: BoxDecoration(
              // The stronger fill keeps the icons legible over the light map style.
              color: XploreColors.glassChromeStrong,
              borderRadius: _radius,
              border: Border.all(color: XploreColors.glassChromeBorder),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ControlButton(icon: CupertinoIcons.layers, label: 'Map style', onPressed: onPickStyle),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 10,
                    endIndent: 10,
                    color: XploreColors.glassChromeBorder,
                  ),
                  _ControlButton(icon: CupertinoIcons.location, label: 'Recenter', onPressed: onRecenter),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
        splashColor: XploreColors.white.withValues(alpha: 0.06),
        highlightColor: XploreColors.white.withValues(alpha: 0.04),
        child: SizedBox.square(
          dimension: MapControls._width,
          child: Icon(icon, size: 21, color: XploreColors.white),
        ),
      ),
    );
  }
}
