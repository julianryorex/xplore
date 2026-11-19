import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/features/gallery/models/image_models.dart';
import 'package:xplore/features/gallery/presentation/gallery_days.dart';
import 'package:xplore/features/gallery/presentation/widgets/album_mosaic.dart';
import 'package:xplore/features/gallery/presentation/widgets/album_photo_tile.dart';
import 'package:xplore/features/gallery/presentation/widgets/uploader_avatar.dart';

/// Space above every day header, which also separates consecutive days.
const albumDayTopGap = 28.0;

/// One day of the album: its header and a mosaic of its photos.
class AlbumDaySection extends StatelessWidget {
  const AlbumDaySection({
    required this.day,
    required this.overline,
    required this.leadOnLeft,
    required this.currentUid,
    required this.onOpen,
    required this.onRetry,
    super.key,
  });

  final GalleryDay day;
  final String? overline;
  final bool leadOnLeft;
  final String? currentUid;

  /// Opens the viewer at the given index of the whole newest-first gallery.
  final ValueChanged<int> onOpen;
  final ValueChanged<ImageModel> onRetry;

  @override
  Widget build(BuildContext context) {
    final tiles = mosaicLayout(day.photos.length, leadOnLeft: leadOnLeft);

    return Padding(
      padding: const EdgeInsets.only(top: albumDayTopGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DayHeader(
            overline: overline,
            heading: dayHeading(day.date),
            uploaders: distinctUploaders(day.photos, currentUid: currentUid),
            photoCount: day.photos.length,
          ),
          const SizedBox(height: 8),
          AlbumMosaic(
            tiles: tiles,
            tileBuilder: (context, i, tile) {
              final image = day.photos[i];
              return AlbumPhotoTile(
                key: ValueKey(image.id),
                image: image,
                uploader: PhotoUploader.of(image, currentUid: currentUid),
                showUploader: tile.showsUploader,
                semanticIndex: day.firstIndex + i + 1,
                onOpen: () => onOpen(day.firstIndex + i),
                onRetry: () => onRetry(image),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.overline, required this.heading, required this.uploaders, required this.photoCount});

  final String? overline;
  final String heading;
  final List<PhotoUploader> uploaders;
  final int photoCount;

  @override
  Widget build(BuildContext context) {
    final overline = this.overline;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (overline != null) ...[
                  Text(overline, style: XploreText.overline.copyWith(color: XploreColors.secondaryLabel)),
                  const SizedBox(height: 4),
                ],
                Text(heading, style: XploreText.heading.copyWith(color: XploreColors.white)),
              ],
            ),
          ),
        ),
        UploaderAvatarStack(uploaders: uploaders, size: 20, maxVisible: 4),
        const SizedBox(width: 8),
        Text(
          photoCountLabel(photoCount),
          style: XploreText.caption.copyWith(color: XploreColors.secondaryLabel, height: 21 / 12),
        ),
      ],
    );
  }
}
