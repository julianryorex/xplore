import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/core/glass.dart';
import 'package:xplore/features/gallery/bloc/gallery_cubit.dart';
import 'package:xplore/features/gallery/models/image_models.dart';
import 'package:xplore/features/gallery/presentation/gallery_days.dart';
import 'package:xplore/features/gallery/presentation/widgets/uploader_avatar.dart';
import 'package:xplore/features/trip/presentation/trip_invite_sharer.dart';

const _chromeInset = 18.0;
const _chromeFade = Duration(milliseconds: 250);
const _noticeDuration = Duration(milliseconds: 2500);

/// How long a page must stay on screen before its original is downloaded, so a fling through the
/// album doesn't start a multi-MB download for every photo it passes.
const _settleDelay = Duration(milliseconds: 300);

/// Originals are decoded at most this many times the screen's physical size: enough detail at the
/// 2x maximum zoom, a fraction of a full-sensor decode's memory.
const _maxDecodeScale = 2.0;

/// Full-screen, swipeable photo viewer with pinch zoom. Tapping the photo
/// toggles the floating chrome: close, counter, uploader, Save and Share.
///
/// Each page shows the thumbnail first and swaps in the full-resolution
/// original once it is on this device.
class GalleryFocusView extends StatefulWidget {
  final List<ImageModel> images;
  final int initialIndex;

  const GalleryFocusView({required this.images, required this.initialIndex, super.key});

  @override
  State<GalleryFocusView> createState() => _GalleryFocusViewState();
}

class _GalleryFocusViewState extends State<GalleryFocusView> {
  late final PageController _pageController;
  late int _currentIndex;
  var _chromeVisible = true;

  /// Originals already on disk, by photo id. Only paths are held here; the pixels are decoded at
  /// screen size into Flutter's image cache.
  final _fullResFiles = <String, File>{};

  /// Fetches in flight, by photo id, so a Save or Share tap during loading reuses the running download.
  final _pendingFetches = <String, Future<File?>>{};

  // Busy state is per photo: paging stays enabled while an action runs, and the spinner must not
  // follow the user onto the next photo.
  final _savingIds = <String>{};
  final _sharingIds = <String>{};
  final _deletingIds = <String>{};

  String? _notice;
  Timer? _noticeTimer;
  Timer? _settleTimer;

  ImageModel get _currentImage => widget.images[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _loadFullRes(_currentImage.id);
  }

  @override
  void dispose() {
    _noticeTimer?.cancel();
    _settleTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _settleTimer?.cancel();
    _settleTimer = Timer(_settleDelay, () {
      if (mounted && _currentIndex == index) _loadFullRes(widget.images[index].id);
    });
  }

  /// The original of photo [id] (downloaded first if another member added it),
  /// or `null` when it is unavailable.
  Future<File?> _loadFullRes(String id) {
    final known = _fullResFiles[id];
    if (known != null) return Future.value(known);
    return _pendingFetches[id] ??= _fetchFullRes(id);
  }

  Future<File?> _fetchFullRes(String id) async {
    final file = await _cubit.fetchFullResFile(id);
    _pendingFetches.remove(id);
    if (mounted) {
      setState(() {
        if (file != null) _fullResFiles[id] = file;
      });
    }
    return file;
  }

  Future<void> _saveCurrentPhoto() async {
    final id = _currentImage.id;
    setState(() => _savingIds.add(id));
    // Resolving the original here first tells "offline" apart from "no photo access", which the
    // cubit's save reports alike, and reuses the download already running for this page.
    final file = await _loadFullRes(id);
    final saved = file != null && await _cubit.savePhotoToPhotos(id);
    if (!mounted) return;
    setState(() => _savingIds.remove(id));

    if (file == null) {
      _showNotice(_unavailableNotice);
    } else if (!saved) {
      _showNotice('Couldn’t save. Check photo access in Settings.');
    } else if (_currentImage.id == id) {
      // A confirmation over a different photo would read as that photo being saved.
      HapticFeedback.lightImpact();
      _showNotice('Saved to Photos');
    }
  }

  Future<void> _shareCurrentPhoto(Rect? origin) async {
    final id = _currentImage.id;
    setState(() => _sharingIds.add(id));
    final file = await _loadFullRes(id);
    if (!mounted) return;
    setState(() => _sharingIds.remove(id));

    // The user swiped away while the original downloaded; opening the sheet now would share a photo
    // that is no longer on screen.
    if (_currentImage.id != id) return;
    // Sharing the thumbnail would quietly send a low-quality copy, so say why nothing happened instead.
    if (file == null) {
      _showNotice(_unavailableNotice);
      return;
    }
    try {
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], sharePositionOrigin: origin));
    } catch (_) {
      if (mounted) _showNotice('Couldn’t open the share sheet. Please try again.');
    }
  }

  Future<void> _deleteCurrentPhoto() async {
    final id = _currentImage.id;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete this photo?'),
            content: const Text('It will be removed from the album for everyone on the trip. This can’t be undone.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text('Delete', style: TextStyle(color: XploreColors.error)),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() => _deletingIds.add(id));
    final deleted = await _cubit.deletePhoto(id);
    if (!mounted) return;
    setState(() => _deletingIds.remove(id));

    if (deleted) {
      // The viewer pages through a snapshot of the album, which now holds a photo that no longer exists.
      Navigator.pop(context);
    } else {
      _showNotice('Couldn’t delete the photo. Try again when you’re online.');
    }
  }

  GalleryCubit get _cubit => context.read<GalleryCubit>();

  static const _unavailableNotice = 'Couldn’t load the full-quality photo. Try again when you’re online.';

  void _showNotice(String message) {
    _noticeTimer?.cancel();
    setState(() => _notice = message);
    _noticeTimer = Timer(_noticeDuration, () {
      if (mounted) setState(() => _notice = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.viewPaddingOf(context);
    final bottomOffset = math.max(padding.bottom, 16.0);
    final image = _currentImage;
    final uploader = PhotoUploader.of(image, currentUid: _cubit.currentUid);
    final loadingOriginal = _pendingFetches.containsKey(image.id);
    // The status chip sits a fixed distance above the bottom row, over the lower edge of a typical photo.
    final chipBottom = bottomOffset + minTouchTarget + 100;

    return Scaffold(
      backgroundColor: XploreColors.background,
      body: GestureDetector(
        onTap: () => setState(() => _chromeVisible = !_chromeVisible),
        child: Stack(
          children: [
            Positioned.fill(child: _buildPager()),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_chromeVisible,
                child: AnimatedOpacity(
                  duration: _chromeFade,
                  opacity: _chromeVisible ? 1 : 0,
                  child: Stack(
                    children: [
                      const _Scrims(),
                      Positioned(
                        top: padding.top + 16,
                        left: _chromeInset,
                        right: _chromeInset,
                        child: _TopBar(
                          position: _currentIndex + 1,
                          total: widget.images.length,
                          onDelete: _cubit.canDeletePhoto(_currentImage.id) ? _deleteCurrentPhoto : null,
                          deleting: _deletingIds.contains(_currentImage.id),
                        ),
                      ),
                      if (loadingOriginal && _notice == null)
                        Positioned(
                          left: _chromeInset,
                          right: _chromeInset,
                          bottom: chipBottom,
                          child: const _StatusChip(label: 'Loading full quality', showSpinner: true),
                        ),
                      Positioned(
                        left: _chromeInset,
                        right: _chromeInset,
                        bottom: bottomOffset,
                        child: _BottomBar(
                          uploader: uploader,
                          takenAt: image.createdAt,
                          saving: _savingIds.contains(image.id),
                          sharing: _sharingIds.contains(image.id),
                          onSave: _saveCurrentPhoto,
                          onShare: _shareCurrentPhoto,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Outside the fading chrome so a save/share result still shows if the chrome was hidden meanwhile.
            if (_notice != null)
              Positioned(
                left: _chromeInset,
                right: _chromeInset,
                bottom: chipBottom,
                child: IgnorePointer(child: _StatusChip(label: _notice!)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPager() {
    final decodeBound =
        (MediaQuery.sizeOf(context).longestSide * MediaQuery.devicePixelRatioOf(context) * _maxDecodeScale).round();
    return PhotoViewGallery.builder(
      pageController: _pageController,
      onPageChanged: _onPageChanged,
      itemCount: widget.images.length,
      scrollPhysics: const BouncingScrollPhysics(),
      backgroundDecoration: const BoxDecoration(color: XploreColors.background),
      // Keeps the thumbnail on screen while the original decodes, instead of flashing black.
      gaplessPlayback: true,
      loadingBuilder: (_, _) => const SizedBox.shrink(),
      builder: (context, index) {
        final image = widget.images[index];
        final original = _fullResFiles[image.id];
        return PhotoViewGalleryPageOptions(
          imageProvider: original != null
              // Display only: Save and Share still send the untouched original file.
              ? ResizeImage(FileImage(original), width: decodeBound, height: decodeBound, policy: ResizeImagePolicy.fit)
              : MemoryImage(image.lowResImage) as ImageProvider,
          initialScale: PhotoViewComputedScale.contained,
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.contained * 2,
          filterQuality: FilterQuality.medium,
          heroAttributes: PhotoViewHeroAttributes(tag: image.id),
          errorBuilder: (_, _, _) => Center(child: Image.memory(image.lowResImage, gaplessPlayback: true)),
        );
      },
    );
  }
}

/// Top and bottom gradients that keep the white chrome legible over bright photos.
class _Scrims extends StatelessWidget {
  const _Scrims();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            height: 180,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [XploreColors.black.withValues(alpha: 0.6), XploreColors.black.withValues(alpha: 0)],
              ),
            ),
          ),
          Container(
            height: 240,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.6, 1],
                colors: [
                  XploreColors.black.withValues(alpha: 0),
                  XploreColors.black.withValues(alpha: 0.72),
                  XploreColors.black.withValues(alpha: 0.88),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.position, required this.total, required this.onDelete, required this.deleting});

  final int position;
  final int total;

  /// Null when the photo on screen is not the signed-in member's to delete.
  final VoidCallback? onDelete;
  final bool deleting;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GlassIconButton(
          size: minTouchTarget,
          iconSize: headerIconSize,
          icon: Icons.close_rounded,
          tooltip: 'Close',
          onTap: () => Navigator.pop(context),
        ),
        Expanded(
          child: Center(
            child: Semantics(
              label: 'Photo $position of $total',
              excludeSemantics: true,
              child: _GlassPill(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  '$position of $total',
                  style: XploreText.footnoteStrong.copyWith(
                    color: XploreColors.white,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
        ),
        // Without a delete button the slot still balances the close button, so the counter stays centred.
        if (onDelete == null)
          const SizedBox(width: minTouchTarget)
        else
          IgnorePointer(
            ignoring: deleting,
            child: Opacity(
              opacity: deleting ? 0.5 : 1,
              child: GlassIconButton(
                size: minTouchTarget,
                iconSize: headerIconSize,
                icon: CupertinoIcons.trash,
                tooltip: 'Delete photo',
                onTap: onDelete!,
              ),
            ),
          ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.uploader,
    required this.takenAt,
    required this.saving,
    required this.sharing,
    required this.onSave,
    required this.onShare,
  });

  final PhotoUploader uploader;
  final DateTime takenAt;
  final bool saving;
  final bool sharing;
  final VoidCallback onSave;

  /// Receives the Share button's global rect, which anchors the share sheet on iPad.
  final ValueChanged<Rect?> onShare;

  @override
  Widget build(BuildContext context) {
    final taken = _formatTakenAt(takenAt);
    return Row(
      children: [
        UploaderAvatar(uploader: uploader, size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Semantics(
            label: 'Added by ${uploader.label}, $taken',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  uploader.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: XploreText.bodyStrong.copyWith(color: XploreColors.white),
                ),
                Text(
                  taken,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: XploreText.footnote.copyWith(color: XploreColors.inactiveControl),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        _ActionButton(icon: Icons.download_rounded, label: 'Save to Photos', busy: saving, onTap: (_) => onSave()),
        const SizedBox(width: 8),
        _ActionButton(icon: CupertinoIcons.share, label: 'Share', busy: sharing, onTap: onShare),
      ],
    );
  }
}

/// A glass icon button that shows a spinner and ignores taps while its action runs.
class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.busy, required this.onTap});

  final IconData icon;
  final String label;
  final bool busy;

  /// Receives this button's global rect, for anchoring popovers.
  final ValueChanged<Rect?> onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        enabled: !busy,
        label: label,
        excludeSemantics: true,
        onTap: busy ? null : () => onTap(shareOriginOf(context)),
        child: SizedBox.square(
          dimension: minTouchTarget,
          child: GlassSurface(
            strong: true,
            borderRadius: radiusMd,
            padding: EdgeInsets.zero,
            onTap: busy ? null : () => onTap(shareOriginOf(context)),
            child: Center(
              child: busy ? const _Spinner(size: 18) : Icon(icon, size: headerIconSize, color: XploreColors.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small centred glass chip for transient status ("Loading full quality", "Saved to Photos").
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, this.showSpinner = false});

  final String label;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        liveRegion: true,
        child: _GlassPill(
          padding: EdgeInsets.only(left: showSpinner ? 10 : 14, right: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showSpinner) ...[const _Spinner(size: 16), const SizedBox(width: 8)],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: XploreText.caption.copyWith(color: XploreColors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The translucent capsule shared by the counter and status chips: 32pt tall, growing with large text.
class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.padding, required this.child});

  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      strong: true,
      borderRadius: radiusMd,
      padding: padding,
      // The minimum height sits inside the surface so the content is centred
      // in it; outside, the surface grew but its content stayed at the top.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: Center(widthFactor: 1, heightFactor: 1, child: child),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        strokeCap: StrokeCap.round,
        color: XploreColors.white,
        backgroundColor: XploreColors.white.withValues(alpha: 0.2),
      ),
    );
  }
}

String _formatTakenAt(DateTime takenAt) {
  final local = takenAt.toLocal();
  final year = local.year == DateTime.now().year ? '' : ' ${local.year}';
  final time = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  return '${dayHeading(local)}$year · $time';
}
