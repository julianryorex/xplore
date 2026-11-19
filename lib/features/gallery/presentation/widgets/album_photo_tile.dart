import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/core/glass.dart';
import 'package:xplore/features/gallery/models/image_models.dart';
import 'package:xplore/features/gallery/presentation/widgets/uploader_avatar.dart';

/// One photo in the album mosaic: opens the viewer once uploaded, shows an
/// indeterminate ring while uploading and a retry control if the upload failed.
class AlbumPhotoTile extends StatelessWidget {
  const AlbumPhotoTile({
    required this.image,
    required this.uploader,
    required this.showUploader,
    required this.semanticIndex,
    required this.onOpen,
    required this.onRetry,
    super.key,
  });

  final ImageModel image;
  final PhotoUploader uploader;

  /// Whether to overlay the uploader's name chip (wide tiles only).
  final bool showUploader;

  /// 1-based position for the screen-reader label.
  final int semanticIndex;
  final VoidCallback onOpen;
  final VoidCallback onRetry;

  static const radius = radiusSm;

  @override
  Widget build(BuildContext context) {
    final status = image.isUploading;
    final isUploading = status == EUploadStatus.uploading || status == EUploadStatus.notStarted;
    final hasFailed = status == EUploadStatus.failed;

    final (String label, VoidCallback? onTap) = switch ((isUploading, hasFailed)) {
      (true, _) => ('Photo $semanticIndex by ${uploader.label}, uploading', null),
      (_, true) => ('Photo $semanticIndex by ${uploader.label}, upload failed. Retry upload', onRetry),
      _ => ('Photo $semanticIndex by ${uploader.label}. Opens the photo', onOpen),
    };

    return Semantics(
      button: onTap != null,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: XploreColors.card,
                child: _Thumbnail(image: image),
              ),
              if (isUploading) const _UploadingOverlay(),
              if (hasFailed) _FailedOverlay(onRetry: onRetry),
              if (showUploader && !isUploading && !hasFailed)
                Positioned(left: 8, bottom: 8, child: _UploaderChip(uploader: uploader)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.image});

  final ImageModel image;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Thumbnails can be 1080px wide; decode them at the size they are shown.
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final longestSide = constraints.biggest.longestSide;
        return Image.memory(
          image.lowResImage,
          key: ValueKey(image.id),
          fit: BoxFit.cover,
          cacheWidth: longestSide.isFinite ? (longestSide * dpr).round() : null,
          gaplessPlayback: true,
        );
      },
    );
  }
}

class _UploadingOverlay extends StatelessWidget {
  const _UploadingOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x8C000000),
      child: Center(
        child: SizedBox.square(
          dimension: 30,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            strokeCap: StrokeCap.round,
            color: XploreColors.white,
            backgroundColor: XploreColors.white.withValues(alpha: 0.28),
          ),
        ),
      ),
    );
  }
}

class _FailedOverlay extends StatelessWidget {
  const _FailedOverlay({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x9E000000),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: minTouchTarget,
                  child: GlassSurface(
                    tint: const Color(0xD92C2C2E),
                    borderRadius: minTouchTarget / 2,
                    padding: EdgeInsets.zero,
                    highlight: false,
                    onTap: onRetry,
                    child: const Center(child: Icon(Icons.refresh_rounded, size: 22, color: XploreColors.white)),
                  ),
                ),
                const SizedBox(height: 4),
                Text('Retry', style: XploreText.caption.copyWith(color: XploreColors.white)),
              ],
            ),
          ),
          Positioned(
            top: 7,
            right: 7,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(color: XploreColors.error, shape: BoxShape.circle),
              child: const Icon(Icons.priority_high_rounded, size: 13, color: XploreColors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _UploaderChip extends StatelessWidget {
  const _UploaderChip({required this.uploader});

  final PhotoUploader uploader;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      tint: const Color(0xB81C1C1E),
      borderRadius: 13,
      highlight: false,
      padding: const EdgeInsets.fromLTRB(3, 3, 10, 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          UploaderAvatar(uploader: uploader, size: 20),
          const SizedBox(width: 6),
          Text(uploader.label, style: XploreText.caption.copyWith(color: XploreColors.white, height: 1)),
        ],
      ),
    );
  }
}
