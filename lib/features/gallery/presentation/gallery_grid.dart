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

  static const itemSize = 85.0;

  @override
  Widget build(BuildContext context) {
    final itemNum = gallery.length;

    return LayoutBuilder(
      builder: (context, bc) {
        const spacing = 3.0;

        final colWidth = bc.maxWidth; // padding
        final colCalc = (colWidth / (itemSize + spacing));
        final totalCol = colCalc.floor();

        final rowCalc = itemNum / totalCol;
        final totalRows = rowCalc.ceil();

        return Column(
          children: [
            ...List.generate(totalRows, (i) => i).map(
              (row) {
                final itemsLeftInCurrentRow = (itemNum - totalCol * row);

                return Padding(
                  key: Key('row-$row'),
                  padding: const EdgeInsets.only(bottom: spacing),
                  child: SizedBox(
                    height: itemSize,
                    child: Row(
                      children: [
                        ...List.generate(min(itemsLeftInCurrentRow, totalCol), ((colIndex) => colIndex)).map(
                          (col) {
                            final currentItemIndex = row * totalCol + col;
                            final currentItem = gallery[currentItemIndex];
                            final currentUploadStatus = gallery[currentItemIndex].isUploading;

                            return Container(
                              key: Key('item-$currentItemIndex'),
                              margin: col == totalCol - 1 ? null : const EdgeInsets.only(right: spacing),
                              height: itemSize,
                              width: itemSize,
                              decoration: BoxDecoration(
                                color: XploreColors.secondary
                                    .withValues(alpha: currentItem.isUploading == EUploadStatus.uploading ? 0.4 : 1),
                                border: Border.all(color: XploreColors.primary, width: 1),
                              ),
                              child: Builder(
                                builder: (context) {
                                  switch (currentUploadStatus) {
                                    case EUploadStatus.notStarted:
                                    case EUploadStatus.uploading:
                                      return Center(
                                        child: SizedBox(
                                          height: 30,
                                          width: 30,
                                          child: CircularProgressIndicator(color: XploreColors.darkBg),
                                        ),
                                      );
                                    case EUploadStatus.complete:
                                      return GestureDetector(
                                        onTap: () {
                                          Navigator.pushNamed(
                                            context,
                                            Paths.galleryFocusView,
                                            arguments: {'gallery': gallery, 'initialIndex': currentItemIndex},
                                          );
                                        },
                                        child: Image.memory(gallery[currentItemIndex].lowResImage, fit: BoxFit.cover),
                                      );
                                    case EUploadStatus.failed:
                                      return GestureDetector(
                                        onTap: () {
                                          // TODO: add re-upload functionality?
                                          print('tapped failed photo');
                                        },
                                        child: Container(
                                          color: XploreColors.black,
                                          child: Opacity(
                                            opacity: 0.3,
                                            child: Image.memory(
                                              gallery[currentItemIndex].lowResImage,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      );
                                  }
                                },
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
