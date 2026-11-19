import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/core/enums.dart';
import 'package:xplore/features/gallery/bloc/gallery_cubit.dart';
import 'package:xplore/features/gallery/models/image_models.dart';
import 'package:xplore/features/gallery/presentation/gallery_days.dart';
import 'package:xplore/features/gallery/presentation/widgets/uploader_avatar.dart';
import 'package:xplore/features/home/widgets/home_section_header.dart';
import 'package:xplore/routes.dart';

const _tileSize = 124.0;
const _tileRadius = 18.0;
const _tileGap = 8.0;

/// Home's shared-gallery section: the photo count and the newest trip photos in
/// a horizontal strip that bleeds off the right edge, or a prompt card when
/// there are none yet.
class GalleryStrip extends StatelessWidget {
  const GalleryStrip({super.key});

  static const _maxPhotos = 10;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 20),
            child: HomeSectionHeader(
              title: 'Shared gallery',
              actionLabel: 'Open',
              onAction: () => context.push(Paths.gallery),
            ),
          ),
          BlocBuilder<GalleryCubit, GalleryState>(
            // Skips the save-progress emits the strip doesn't show. `identical` because Freezed's deep map
            // equality would compare every thumbnail's bytes.
            buildWhen: (previous, current) =>
                !identical(previous.imageMap, current.imageMap) || previous.status != current.status,
            builder: (context, state) {
              final photos = state.newestFirst;
              if (photos.isNotEmpty) {
                return _PhotoStrip(
                  photos: photos.take(_maxPhotos).toList(),
                  totalCount: photos.length,
                  currentUid: context.read<GalleryCubit>().currentUid,
                );
              }
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: state.status == EBlocStatus.loading ? const _SkeletonStrip() : const _StartAlbumCard(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.photos, required this.totalCount, required this.currentUid});

  final List<ImageModel> photos;
  final int totalCount;
  final String? currentUid;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            photoCountLabel(totalCount),
            style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: _tileSize,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 16),
            itemCount: photos.length,
            separatorBuilder: (_, _) => const SizedBox(width: _tileGap),
            itemBuilder: (context, index) => _PhotoTile(photo: photos[index], currentUid: currentUid),
          ),
        ),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo, required this.currentUid});

  final ImageModel photo;
  final String? currentUid;

  @override
  Widget build(BuildContext context) {
    final uploader = PhotoUploader.of(photo, currentUid: currentUid);
    final byline = uploader.isCurrentUser ? 'Your photo' : 'Photo by ${uploader.label}';
    // excludeSemantics drops the GestureDetector's tap action, so the
    // Semantics node carries its own onTap for screen readers.
    return Semantics(
      button: true,
      label: '$byline. Opens the gallery',
      excludeSemantics: true,
      onTap: () => context.push(Paths.gallery),
      child: GestureDetector(
        onTap: () => context.push(Paths.gallery),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_tileRadius),
          child: Stack(
            children: [
              Image.memory(
                photo.lowResImage,
                key: ValueKey(photo.id),
                width: _tileSize,
                height: _tileSize,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
              Positioned(
                left: 8,
                bottom: 8,
                child: UploaderAvatar(
                  uploader: uploader,
                  size: 22,
                  borderColor: XploreColors.black.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder tiles shown while the gallery loads for the first time.
class _SkeletonStrip extends StatelessWidget {
  const _SkeletonStrip();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading photos',
      child: SizedBox(
        height: _tileSize,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(right: 16),
          itemCount: 4,
          separatorBuilder: (_, _) => const SizedBox(width: _tileGap),
          itemBuilder: (_, _) => Container(
            width: _tileSize,
            decoration: BoxDecoration(color: XploreColors.card, borderRadius: BorderRadius.circular(_tileRadius)),
          ),
        ),
      ),
    );
  }
}

class _StartAlbumCard extends StatelessWidget {
  const _StartAlbumCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Material(
        color: XploreColors.card,
        borderRadius: BorderRadius.circular(radiusLg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(Paths.gallery),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: XploreColors.accentSoft,
                    borderRadius: BorderRadius.circular(radiusSm),
                  ),
                  child: const Icon(CupertinoIcons.photo, size: 24, color: XploreColors.accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Start the shared album', style: XploreText.bodyStrong.copyWith(color: XploreColors.white)),
                      const SizedBox(height: 2),
                      Text(
                        'Add the first photos. Everyone on the trip sees them.',
                        style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(CupertinoIcons.chevron_right, size: 16, color: XploreColors.secondaryLabel),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
