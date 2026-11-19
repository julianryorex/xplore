import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/features/gallery/presentation/gallery_days.dart';
import 'package:xplore/features/gallery/presentation/widgets/album_status_ring.dart';
import 'package:xplore/features/gallery/presentation/widgets/uploader_avatar.dart';

/// The album's heading: "SHARED ALBUM", the trip title and a summary line with
/// the contributors, the photo count, or the first-sync indicator.
class AlbumTitleBlock extends StatelessWidget {
  const AlbumTitleBlock({
    required this.tripTitle,
    required this.photoCount,
    required this.uploaders,
    required this.isSyncing,
    super.key,
  });

  final String tripTitle;
  final int photoCount;
  final List<PhotoUploader> uploaders;

  /// The album is loading for the first time and has nothing to show yet.
  final bool isSyncing;

  @override
  Widget build(BuildContext context) {
    final secondary = XploreText.footnote.copyWith(color: XploreColors.secondaryLabel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SHARED ALBUM', style: XploreText.overline.copyWith(color: XploreColors.secondaryLabel)),
        const SizedBox(height: 6),
        Semantics(
          header: true,
          child: Text(
            tripTitle.isEmpty ? 'Trip album' : tripTitle,
            style: XploreText.title.copyWith(color: XploreColors.white),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 24),
          child: Row(
            children: [
              if (isSyncing) ...[
                const AlbumStatusRing(size: 16, strokeWidth: 2.2),
                const SizedBox(width: 8),
                Text('Syncing the album…', style: secondary),
              ] else if (photoCount == 0)
                Text('No photos yet', style: secondary)
              else ...[
                if (uploaders.isNotEmpty) ...[UploaderAvatarStack(uploaders: uploaders), const SizedBox(width: 10)],
                Flexible(
                  child: Text(_summary, style: secondary, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // The people count only adds something once more than one person contributed.
  String get _summary {
    final photos = photoCountLabel(photoCount);
    return uploaders.length > 1 ? '$photos · ${uploaders.length} people' : photos;
  }
}
