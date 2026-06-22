import 'dart:math';

import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/features/gallery/models/image_models.dart';
import 'package:xplore/routes.dart';

class GalleryGrid extends StatelessWidget {
  final List<ImageModel> gallery;

  const GalleryGrid({
    required this.gallery,
    super.key,
  });

  static const itemSize = 92.0;
  static const _radius = radiusSm;

  @override
  Widget build(BuildContext context) {
    final itemNum = gallery.length;

    return LayoutBuilder(
      builder: (context, bc) {
        const spacing = 6.0;

        final colWidth = bc.maxWidth;
        final colCalc = colWidth / (itemSize + spacing);
        final totalCol = colCalc.floor();

        final rowCalc = itemNum / totalCol;
        final totalRows = rowCalc.ceil();

        // Distribute the leftover horizontal space so tiles fill the row evenly.
        final tileSize = (colWidth - spacing * (totalCol - 1)) / totalCol;

        return Column(
          children: [
            ...List.generate(totalRows, (i) => i).map(
              (row) {
                final itemsLeftInCurrentRow = itemNum - totalCol * row;

                return Padding(
                  key: Key('row-$row'),
                  padding: const EdgeInsets.only(bottom: spacing),
                  child: SizedBox(
                    height: tileSize,
                    child: Row(
                      children: [
                        ...List.generate(min(itemsLeftInCurrentRow, totalCol), (colIndex) => colIndex).map(
                          (col) {
                            final currentItemIndex = row * totalCol + col;
                            final currentItem = gallery[currentItemIndex];

                            return Padding(
                              key: Key('item-$currentItemIndex'),
                              padding: col == totalCol - 1
                                  ? EdgeInsets.zero
                                  : const EdgeInsets.only(right: spacing),
                              child: _GalleryTile(
                                item: currentItem,
                                size: tileSize,
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  Paths.galleryFocusView,
                                  arguments: {'gallery': gallery, 'initialIndex': currentItemIndex},
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _GalleryTile extends StatelessWidget {
  final ImageModel item;
  final double size;
  final VoidCallback onTap;

  const _GalleryTile({required this.item, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      width: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(GalleryGrid._radius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: XploreColors.surfaceElevated,
            borderRadius: BorderRadius.circular(GalleryGrid._radius),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildContent(),
              // Hairline rim keeps tiles crisp and consistent against the
              // ambient background.
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(GalleryGrid._radius),
                    border: Border.all(color: XploreColors.glassBorder),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (item.isUploading) {
      case EUploadStatus.notStarted:
      case EUploadStatus.uploading:
        return Center(
          child: SizedBox(
            height: 26,
            width: 26,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: XploreColors.alternate),
          ),
        );
      case EUploadStatus.complete:
        return GestureDetector(
          onTap: onTap,
          child: Image.memory(item.lowResImage, fit: BoxFit.cover),
        );
      case EUploadStatus.failed:
        return GestureDetector(
          onTap: () {
            // TODO: add re-upload functionality?
            debugPrint('tapped failed photo');
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              Opacity(opacity: 0.4, child: Image.memory(item.lowResImage, fit: BoxFit.cover)),
              Center(child: Icon(Icons.error_outline_rounded, color: XploreColors.white, size: 24)),
            ],
          ),
        );
    }
  }
}
