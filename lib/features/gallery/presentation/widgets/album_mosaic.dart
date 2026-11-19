import 'package:flutter/material.dart';
import 'package:xplore/features/gallery/presentation/gallery_days.dart';

/// Places [tiles] on a 3-column grid of square cells sized from the available
/// width, building each tile's content with [tileBuilder].
class AlbumMosaic extends StatelessWidget {
  const AlbumMosaic({required this.tiles, required this.tileBuilder, super.key});

  final List<MosaicTile> tiles;
  final Widget Function(BuildContext context, int index, MosaicTile tile) tileBuilder;

  static const gap = 6.0;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = (constraints.maxWidth - gap * (mosaicColumns - 1)) / mosaicColumns;
        double extent(int span) => cell * span + gap * (span - 1);
        double offset(int index) => (cell + gap) * index;

        return SizedBox(
          height: extent(mosaicRowCount(tiles)),
          child: Stack(
            children: [
              for (var i = 0; i < tiles.length; i++)
                Positioned(
                  left: offset(tiles[i].column),
                  top: offset(tiles[i].row),
                  width: extent(tiles[i].columnSpan),
                  height: extent(tiles[i].rowSpan),
                  child: tileBuilder(context, i, tiles[i]),
                ),
            ],
          ),
        );
      },
    );
  }
}
