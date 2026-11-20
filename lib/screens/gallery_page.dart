import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/core/confirm_dialog.dart';
import 'package:xplore/core/glass.dart';
import 'package:xplore/features/gallery/bloc/gallery_cubit.dart';
import 'package:xplore/features/gallery/models/image_models.dart';
import 'package:xplore/features/gallery/presentation/gallery_days.dart';
import 'package:xplore/features/gallery/presentation/widgets/album_action_bar.dart';
import 'package:xplore/features/gallery/presentation/widgets/album_day_section.dart';
import 'package:xplore/features/gallery/presentation/widgets/album_empty_state.dart';
import 'package:xplore/features/gallery/presentation/widgets/album_photos_access_sheet.dart';
import 'package:xplore/features/gallery/presentation/widgets/album_skeleton.dart';
import 'package:xplore/features/gallery/presentation/widgets/album_status_bar.dart';
import 'package:xplore/features/gallery/presentation/widgets/album_title_block.dart';
import 'package:xplore/features/gallery/presentation/widgets/uploader_avatar.dart';
import 'package:xplore/features/gallery/services/photo_save_service.dart';
import 'package:xplore/features/trip/bloc/trip_cubit.dart';
import 'package:xplore/features/trip/bloc/trip_state.dart';
import 'package:xplore/features/trip/models/trip_model.dart';
import 'package:xplore/routes.dart';

/// The trip's shared album, told as a day-by-day story: newest day first, each
/// day a mosaic led by one large photo, with floating actions and a single
/// status bar for uploads and Save-all runs.
class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key});

  static const _sideInset = paddingUnit * 1.5;
  static const _headerHeight = 62.0;
  static const _statusGap = 12.0;

  // Space the status bar may take, reserved so the last row can scroll clear of it.
  static const _statusClearance = 92.0;

  @override
  Widget build(BuildContext context) {
    final trip = context.select<TripCubit, TripModel?>(
      (cubit) => switch (cubit.state) {
        TripLoaded(:final active) => active,
        _ => null,
      },
    );
    final albumName = tripAlbumName(trip?.title ?? '');

    return Scaffold(
      backgroundColor: XploreColors.background,
      body: BlocConsumer<GalleryCubit, GalleryState>(
        listenWhen: (previous, current) => previous.saveProgress != current.saveProgress,
        listener: (context, state) => _onSaveProgressChanged(context, state.saveProgress, albumName),
        builder: (context, state) => _buildAlbum(context, state, trip, albumName),
      ),
    );
  }

  Widget _buildAlbum(BuildContext context, GalleryState state, TripModel? trip, String albumName) {
    final cubit = context.read<GalleryCubit>();
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final bottomInset = math.max(viewPadding.bottom, paddingUnit * 1.5);

    final photos = state.newestFirst;
    // An empty local cache says nothing until the cloud has answered once.
    final isFirstSync = photos.isEmpty && !state.hasSyncedWithCloud;
    final isEmpty = photos.isEmpty && !isFirstSync;
    final status = AlbumStatus.of(state);
    final saveMode = SaveAllMode.of(state, isFirstSync: isFirstSync);
    final bottomClearance =
        bottomInset + albumActionBarHeight + paddingUnit * 2 + (status == null ? 0 : _statusClearance);

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(_sideInset, viewPadding.top + _headerHeight + 8, _sideInset, 0),
              sliver: SliverToBoxAdapter(
                child: AlbumTitleBlock(
                  tripTitle: trip?.title ?? '',
                  photoCount: photos.length,
                  uploaders: distinctUploaders(photos, currentUid: cubit.currentUid),
                  isSyncing: isFirstSync,
                ),
              ),
            ),
            if (isFirstSync)
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: _sideInset),
                sliver: SliverToBoxAdapter(child: AlbumSkeleton()),
              )
            else if (isEmpty)
              SliverToBoxAdapter(
                child: AlbumEmptyState(memberCount: trip?.memberIds.length ?? 1, onAddPhotos: cubit.uploadToGallery),
              )
            else
              ..._albumSlivers(context, state, photos, trip),
            SliverPadding(padding: EdgeInsets.only(bottom: isEmpty ? bottomInset : bottomClearance)),
          ],
        ),
        Positioned(
          top: viewPadding.top + (_headerHeight - headerIconButtonSize) / 2,
          left: _sideInset,
          child: GlassIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onTap: () => Navigator.pop(context)),
        ),
        if (!isEmpty) ...[
          _BottomFade(height: status == null ? 168 : 230),
          Positioned(
            left: _sideInset,
            right: _sideInset,
            bottom: bottomInset,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AlbumStatusBar(
                  status: status,
                  onRetryUploads: cubit.retryFailedUploads,
                  onSaveAgain: cubit.saveAllToPhotos,
                  onOpenPhotos: cubit.openPhotosApp,
                ),
                if (status != null) const SizedBox(height: _statusGap),
                AlbumActionBar(
                  saveMode: saveMode,
                  unsavedCount: state.unsavedCount,
                  onAddPhotos: cubit.uploadToGallery,
                  // With nothing new to save, the button offers to save the whole album again.
                  onSaveAll: saveMode == SaveAllMode.allSaved
                      ? () => _confirmSaveAllAgain(context, cubit)
                      : cubit.saveAllToPhotos,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// The app can't see that an album was deleted in Photos, so re-saving is the user's call.
  Future<void> _confirmSaveAllAgain(BuildContext context, GalleryCubit cubit) async {
    final confirmed = await showConfirmDialog(
      context,
      icon: CupertinoIcons.arrow_down_to_line,
      title: 'Save all photos again?',
      message:
          'Every photo in this album is already marked as saved. Saving again adds them all to Photos '
          'once more, so any that are still in your library will appear twice.',
      confirmLabel: 'Save again',
    );
    if (confirmed) await cubit.saveAllToPhotos(includeAlreadySaved: true);
  }

  List<Widget> _albumSlivers(BuildContext context, GalleryState state, List<ImageModel> photos, TripModel? trip) {
    final cubit = context.read<GalleryCubit>();
    final days = groupGalleryDays(photos);
    final today = DateTime.now();

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: _sideInset),
        // Built lazily per day: only the days near the viewport decode thumbnails.
        sliver: SliverList.builder(
          itemCount: days.length,
          itemBuilder: (context, i) {
            final day = days[i];
            return AlbumDaySection(
              key: ValueKey(day.date),
              day: day,
              overline: dayOverline(day.date, today: today, tripStart: trip?.startDate),
              // Counted from the oldest day so a new day doesn't flip every existing mosaic.
              leadOnLeft: (days.length - 1 - i).isEven,
              currentUid: cubit.currentUid,
              onOpen: (index) => _openFocus(context, photos, index),
              onRetry: (image) => cubit.retryUpload(image.id),
            );
          },
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(_sideInset, albumDayTopGap, _sideInset, 0),
          child: Text(
            '${photoCountLabel(photos.length)} · ${albumDateRange(photos.last.createdAt, photos.first.createdAt)} '
            '· end of album',
            textAlign: TextAlign.center,
            style: XploreText.caption.copyWith(color: XploreColors.secondaryLabel),
          ),
        ),
      ),
    ];
  }

  // A finished run clears itself in the cubit; only a denial needs the page.
  void _onSaveProgressChanged(BuildContext context, PhotoSaveProgress? progress, String albumName) {
    if (progress?.phase != EPhotoSavePhase.denied) return;
    // Clear it straight away so the sheet appears once per Save-all press.
    context.read<GalleryCubit>().dismissSaveProgress();
    showPhotosAccessSheet(context, albumName: albumName);
  }
}

void _openFocus(BuildContext context, List<ImageModel> gallery, int index) {
  Navigator.pushNamed(context, Paths.galleryFocusView, arguments: {'gallery': gallery, 'initialIndex': index});
}

class _BottomFade extends StatelessWidget {
  const _BottomFade({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: height,
      child: const IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x00000000), Color(0xC7000000), XploreColors.background],
              stops: [0, 0.55, 1],
            ),
          ),
        ),
      ),
    );
  }
}
