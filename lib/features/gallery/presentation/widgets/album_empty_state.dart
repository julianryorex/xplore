import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/features/gallery/presentation/widgets/album_action_bar.dart';

/// The album before anyone has added a photo: a fanned-cards illustration,
/// a short pitch and the "Add photos" call to action.
class AlbumEmptyState extends StatelessWidget {
  const AlbumEmptyState({required this.memberCount, required this.onAddPhotos, super.key});

  /// Everyone on the trip, including the signed-in member.
  final int memberCount;
  final VoidCallback onAddPhotos;

  @override
  Widget build(BuildContext context) {
    final others = memberCount - 1;
    final audience = switch (others) {
      <= 0 => 'Everyone on the trip will see them',
      1 => '1 other person will see them',
      _ => '$others others will see them',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 96, 36, 0),
      child: Column(
        children: [
          const ExcludeSemantics(child: _FannedCards()),
          const SizedBox(height: 28),
          Semantics(
            header: true,
            child: Text(
              'Start the shared album',
              textAlign: TextAlign.center,
              style: XploreText.heading.copyWith(color: XploreColors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Photos from everyone on the trip land here in full quality, as they are added.',
            textAlign: TextAlign.center,
            style: XploreText.body.copyWith(color: XploreColors.secondaryLabel),
          ),
          const SizedBox(height: 24),
          AddPhotosButton(onPressed: onAddPhotos, horizontalPadding: 28),
          const SizedBox(height: 20),
          Text(audience, style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel)),
        ],
      ),
    );
  }
}

class _FannedCards extends StatelessWidget {
  const _FannedCards();

  static const _tilt = 9 * math.pi / 180;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 150,
      child: Stack(
        children: [
          Positioned(
            left: 14,
            top: 18,
            child: Transform.rotate(angle: -_tilt, child: const _Card()),
          ),
          Positioned(
            right: 14,
            top: 18,
            child: Transform.rotate(angle: _tilt, child: const _Card()),
          ),
          Positioned(
            left: 50,
            top: 6,
            child: _Card(
              width: 100,
              height: 128,
              color: XploreColors.raised,
              child: Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(color: XploreColors.accentSoft, shape: BoxShape.circle),
                  child: const Icon(Icons.photo_outlined, size: 24, color: XploreColors.accent),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({this.width = 96, this.height = 120, this.color = XploreColors.card, this.child});

  final double width;
  final double height;
  final Color color;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radiusMd),
        border: Border.all(color: XploreColors.glassChromeBorder),
      ),
      child: child,
    );
  }
}
