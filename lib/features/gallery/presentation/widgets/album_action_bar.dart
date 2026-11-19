import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/core/glass.dart';
import 'package:xplore/features/gallery/bloc/gallery_cubit.dart';
import 'package:xplore/features/gallery/models/image_models.dart';
import 'package:xplore/features/gallery/presentation/widgets/album_status_ring.dart';

/// Height of the floating action bar's capsules.
const albumActionBarHeight = 50.0;

/// What the Save-all button offers, derived from the album and any running save.
enum SaveAllMode {
  /// Nothing can be saved yet (first sync, or no photo has finished uploading).
  unavailable,

  /// A Save-all run is in progress.
  saving,

  /// Nothing from this album has been saved from this device yet.
  saveAll,

  /// Some photos were saved before; [AlbumActionBar.unsavedCount] are new.
  saveNew,

  /// Every uploaded photo is already in Photos; pressing checks again.
  allSaved;

  /// The mode for [state]; [isFirstSync] is true while the album loads for the first time.
  static SaveAllMode of(GalleryState state, {required bool isFirstSync}) {
    if (state.saveProgress?.phase == EPhotoSavePhase.saving) return saving;
    final uploaded = state.imageMap.values.where((image) => image.isUploading == EUploadStatus.complete).length;
    if (isFirstSync || uploaded == 0) return unavailable;
    if (state.unsavedCount == 0) return allSaved;
    return state.unsavedCount < uploaded ? saveNew : saveAll;
  }
}

/// The floating bottom actions: a white "Add photos" capsule and the glass Save-all capsule.
class AlbumActionBar extends StatelessWidget {
  const AlbumActionBar({
    required this.saveMode,
    required this.unsavedCount,
    required this.onAddPhotos,
    required this.onSaveAll,
    super.key,
  });

  final SaveAllMode saveMode;
  final int unsavedCount;
  final VoidCallback onAddPhotos;
  final VoidCallback onSaveAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: AddPhotosButton(onPressed: onAddPhotos)),
        const SizedBox(width: 10),
        _SaveAllButton(mode: saveMode, unsavedCount: unsavedCount, onPressed: onSaveAll),
      ],
    );
  }
}

/// The primary white "Add photos" capsule.
class AddPhotosButton extends StatelessWidget {
  const AddPhotosButton({required this.onPressed, this.horizontalPadding = 20, super.key});

  final VoidCallback onPressed;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add_rounded, size: 20),
      label: const Text('Add photos'),
      style: FilledButton.styleFrom(
        backgroundColor: XploreColors.white,
        foregroundColor: XploreColors.background,
        minimumSize: const Size(0, albumActionBarHeight),
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        shape: const StadiumBorder(),
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: XploreText.bodyStrong.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SaveAllButton extends StatelessWidget {
  const _SaveAllButton({required this.mode, required this.unsavedCount, required this.onPressed});

  final SaveAllMode mode;
  final int unsavedCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = mode != SaveAllMode.unavailable && mode != SaveAllMode.saving;

    final (String label, String semantics, Widget icon) = switch (mode) {
      SaveAllMode.saving => (
        'Saving',
        'Saving to Photos',
        const AlbumStatusRing(size: 18, strokeWidth: 2.4, color: XploreColors.secondaryLabel),
      ),
      SaveAllMode.allSaved => (
        'All saved',
        'All saved to Photos. Press to check for new photos',
        const Icon(Icons.check_rounded, size: 20, color: XploreColors.accent),
      ),
      SaveAllMode.saveNew => (
        'Save $unsavedCount new',
        'Save the $unsavedCount new photos to Photos',
        const Icon(Icons.download_rounded, size: 20, color: XploreColors.white),
      ),
      SaveAllMode.saveAll => (
        'Save all',
        'Save all to Photos',
        const Icon(Icons.download_rounded, size: 20, color: XploreColors.white),
      ),
      SaveAllMode.unavailable => (
        'Save all',
        'Save all to Photos, unavailable until photos finish syncing',
        const Icon(Icons.download_rounded, size: 20, color: Color(0xFF77777D)),
      ),
    };

    final foreground = switch (mode) {
      SaveAllMode.unavailable => const Color(0xFF77777D),
      SaveAllMode.saving => XploreColors.secondaryLabel,
      SaveAllMode.allSaved => XploreColors.inactiveControl,
      _ => XploreColors.white,
    };

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 8),
        Text(label, style: XploreText.bodyStrong.copyWith(color: foreground)),
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: semantics,
      excludeSemantics: true,
      onTap: enabled ? onPressed : null,
      child: SizedBox(
        height: albumActionBarHeight,
        child: enabled
            ? GlassSurface(
                strong: true,
                borderRadius: albumActionBarHeight / 2,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                onTap: onPressed,
                child: Center(widthFactor: 1, child: content),
              )
            : DecoratedBox(
                decoration: const ShapeDecoration(color: XploreColors.raised, shape: StadiumBorder()),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Center(widthFactor: 1, child: content),
                ),
              ),
      ),
    );
  }
}
