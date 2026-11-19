import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/core/glass.dart';
import 'package:xplore/features/gallery/bloc/gallery_cubit.dart';
import 'package:xplore/features/gallery/models/image_models.dart';
import 'package:xplore/features/gallery/presentation/widgets/album_status_ring.dart';

/// The one glass bar above the action bar that reports the album's transient
/// state: a Save-all run, failed uploads, or uploads in progress, in that order.
class AlbumStatusBar extends StatelessWidget {
  const AlbumStatusBar({
    required this.status,
    required this.onRetryUploads,
    required this.onSaveAgain,
    required this.onOpenPhotos,
    super.key,
  });

  /// What to show; build it with [AlbumStatus.of]. Null hides the bar.
  final AlbumStatus? status;
  final VoidCallback onRetryUploads;
  final VoidCallback onSaveAgain;
  final VoidCallback onOpenPhotos;

  @override
  Widget build(BuildContext context) {
    final status = this.status;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      child: status == null
          ? const SizedBox(width: double.infinity)
          : KeyedSubtree(key: ValueKey(status.kind), child: _bar(status)),
    );
  }

  Widget _bar(AlbumStatus status) {
    final (VoidCallback? action, String? actionLabel) = switch (status.kind) {
      AlbumStatusKind.uploadsFailed => (onRetryUploads, 'Retry'),
      AlbumStatusKind.savePartial => (onSaveAgain, 'Try again'),
      AlbumStatusKind.saveDone => (onOpenPhotos, 'Open Photos'),
      _ => (null, null),
    };

    return Semantics(
      container: true,
      liveRegion: true,
      child: GlassSurface(
        strong: true,
        borderRadius: radiusLg,
        padding: EdgeInsets.fromLTRB(14, 12, action == null ? 14 : 6, status.progress == null ? 12 : 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _StatusIcon(kind: status.kind),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatusText(title: status.title, subtitle: status.subtitle),
                ),
                if (action != null && actionLabel != null) _StatusAction(label: actionLabel, onTap: action),
              ],
            ),
            if (status.progress != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: status.progress,
                  minHeight: 4,
                  color: XploreColors.accent,
                  backgroundColor: XploreColors.white.withValues(alpha: 0.14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The kinds of message the status bar can carry.
enum AlbumStatusKind { saving, savePartial, saveDone, uploadsFailed, uploading }

/// The status bar's content, resolved from the gallery state by priority.
@immutable
class AlbumStatus {
  const AlbumStatus({required this.kind, required this.title, this.subtitle, this.progress});

  final AlbumStatusKind kind;
  final String title;
  final String? subtitle;

  /// Determinate progress (0–1) of a Save-all run.
  final double? progress;

  /// The highest-priority status for [state], or null when there is nothing to report.
  static AlbumStatus? of(GalleryState state) {
    final save = state.saveProgress;
    if (save != null) {
      switch (save.phase) {
        case EPhotoSavePhase.saving:
          final handled = save.saved + save.failed;
          return AlbumStatus(
            kind: AlbumStatusKind.saving,
            title: save.total == 0 ? 'Saving' : 'Saving ${(handled + 1).clamp(1, save.total)} of ${save.total}',
            subtitle: save.album == null ? 'To your Photos library' : 'To the album “${save.album}”',
            progress: save.total == 0 ? 0 : handled / save.total,
          );
        case EPhotoSavePhase.done when save.failed > 0:
          return AlbumStatus(
            kind: AlbumStatusKind.savePartial,
            title: '${save.failed} couldn\'t be saved',
            subtitle: save.saved == 0 ? 'Check your connection and try again' : _savedSoFar(save),
          );
        case EPhotoSavePhase.done:
          return AlbumStatus(
            kind: AlbumStatusKind.saveDone,
            title: save.total == 0 ? 'Already in Photos' : '${save.saved} saved to Photos',
            subtitle: save.total == 0
                ? 'Every photo here is in your library'
                : save.album == null
                ? 'In your Photos library'
                : 'In “${save.album}”',
          );
        // Denial is shown as a sheet, not in the bar.
        case EPhotoSavePhase.denied:
          break;
      }
    }

    final images = state.imageMap.values;
    final failed = images.where((image) => image.isUploading == EUploadStatus.failed).length;
    if (failed > 0) {
      final uploaded = images.where((image) => image.isUploading == EUploadStatus.complete).length;
      return AlbumStatus(
        kind: AlbumStatusKind.uploadsFailed,
        title: failed == 1 ? '1 photo didn\'t upload' : '$failed photos didn\'t upload',
        subtitle: '$uploaded of ${images.length} are in the album',
      );
    }

    final uploading = images
        .where((image) => image.isUploading == EUploadStatus.uploading || image.isUploading == EUploadStatus.notStarted)
        .length;
    if (uploading > 0) {
      return AlbumStatus(
        kind: AlbumStatusKind.uploading,
        title: uploading == 1 ? 'Uploading 1 photo' : 'Uploading $uploading photos',
        subtitle: 'Everyone sees each photo as it finishes',
      );
    }
    return null;
  }
}

// The saved part of a partial run, e.g. "1 is in “Amalfi Coast”" or "3 are in your Photos library".
String _savedSoFar(PhotoSaveProgress save) {
  final verb = save.saved == 1 ? 'is' : 'are';
  final where = save.album == null ? 'your Photos library' : '“${save.album}”';
  return '${save.saved} $verb in $where';
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.kind});

  final AlbumStatusKind kind;

  static const _size = 36.0;

  // A lighter red than XploreColors.error, so the icon stays legible on its own red tint.
  static const _errorOnTint = Color(0xFFFF6B61);

  @override
  Widget build(BuildContext context) {
    if (kind == AlbumStatusKind.uploading) return const AlbumStatusRing(size: _size);

    final (Color fill, Color foreground, IconData icon) = switch (kind) {
      AlbumStatusKind.saving => (XploreColors.accentSoft, XploreColors.accent, Icons.download_rounded),
      AlbumStatusKind.saveDone => (XploreColors.accent, XploreColors.onAccent, Icons.check_rounded),
      AlbumStatusKind.savePartial => (
        XploreColors.warning.withValues(alpha: 0.18),
        XploreColors.warning,
        Icons.priority_high_rounded,
      ),
      _ => (XploreColors.error.withValues(alpha: 0.2), _errorOnTint, Icons.priority_high_rounded),
    };

    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
      child: Icon(icon, size: 20, color: foreground),
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText({required this.title, required this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: XploreText.bodyStrong.copyWith(color: XploreColors.white)),
        if (subtitle != null)
          Text(
            subtitle,
            style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

class _StatusAction extends StatelessWidget {
  const _StatusAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: XploreColors.accent,
        minimumSize: const Size(minTouchTarget, minTouchTarget),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: XploreText.footnoteStrong,
      ),
      child: Text(label),
    );
  }
}
