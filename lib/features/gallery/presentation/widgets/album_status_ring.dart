import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';

/// An indeterminate jade ring on a faint track: the album's "work in progress" mark.
class AlbumStatusRing extends StatelessWidget {
  const AlbumStatusRing({this.size = 36, this.strokeWidth = 3, this.color = XploreColors.accent, super.key});

  final double size;
  final double strokeWidth;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Padding(
        // CircularProgressIndicator strokes centred on its bounds; inset so the ring fits the box.
        padding: EdgeInsets.all(strokeWidth / 2),
        child: CircularProgressIndicator(
          strokeWidth: strokeWidth,
          strokeCap: StrokeCap.round,
          color: color,
          backgroundColor: XploreColors.white.withValues(alpha: 0.16),
        ),
      ),
    );
  }
}
