import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/features/gallery/presentation/gallery_days.dart';
import 'package:xplore/features/gallery/presentation/widgets/album_day_section.dart';
import 'package:xplore/features/gallery/presentation/widgets/album_mosaic.dart';

/// Placeholder days shown while the album syncs for the first time.
class AlbumSkeleton extends StatelessWidget {
  const AlbumSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Column(
        children: [
          _SkeletonDay(tiles: mosaicLayout(9, leadOnLeft: true)),
          _SkeletonDay(tiles: mosaicLayout(6, leadOnLeft: false)),
        ],
      ),
    );
  }
}

class _SkeletonDay extends StatelessWidget {
  const _SkeletonDay({required this.tiles});

  final List<MosaicTile> tiles;

  static const _tileShade = Color(0xFF232325);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: albumDayTopGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stands in for the overline and date heading, bottom-aligned in the 44pt header.
          const SizedBox(height: 12),
          const _Bar(width: 64, height: 9, color: XploreColors.card),
          const SizedBox(height: 8),
          const _Bar(width: 120, height: 15, color: XploreColors.raised),
          const SizedBox(height: 8),
          AlbumMosaic(
            tiles: tiles,
            tileBuilder: (context, i, _) => DecoratedBox(
              decoration: BoxDecoration(
                color: i % 3 == 0 ? _tileShade : XploreColors.card,
                borderRadius: BorderRadius.circular(radiusSm),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.width, required this.height, required this.color});

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height / 2)),
    );
  }
}
