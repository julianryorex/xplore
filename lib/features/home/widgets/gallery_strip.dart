import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/core/enums.dart';
import 'package:xplore/features/gallery/bloc/gallery_cubit.dart';
import 'package:xplore/features/gallery/models/image_models.dart';
import 'package:xplore/features/home/widgets/home_section_header.dart';
import 'package:xplore/routes.dart';

/// Home's shared-gallery section: the newest trip photos in a horizontal strip
/// that bleeds off the right edge, or a prompt card when there are none yet.
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
          const SizedBox(height: 8),
          BlocBuilder<GalleryCubit, GalleryState>(
            builder: (context, state) {
              final photos = _newestFirst(state.imageMap.values);
              if (photos.isNotEmpty) {
                return _PhotoStrip(photos: photos);
              }
              return state.status == EBlocStatus.loading ? const _LoadingStrip() : const _NoPhotosCard();
            },
          ),
        ],
      ),
    );
  }

  List<ImageModel> _newestFirst(Iterable<ImageModel> images) {
    final sorted = images.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(_maxPhotos).toList();
  }
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.photos});

  final List<ImageModel> photos;

  static const _size = 124.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 16),
        itemCount: photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        // excludeSemantics drops the GestureDetector's tap action, so the
        // Semantics node carries its own onTap for screen readers.
        itemBuilder: (context, index) => Semantics(
          button: true,
          label: 'Photo ${index + 1} of ${photos.length}. Opens the gallery',
          excludeSemantics: true,
          onTap: () => context.push(Paths.gallery),
          child: GestureDetector(
            onTap: () => context.push(Paths.gallery),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.memory(
                photos[index].lowResImage,
                key: ValueKey(photos[index].id),
                width: _size,
                height: _size,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingStrip extends StatelessWidget {
  const _LoadingStrip();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 124, child: Center(child: CircularProgressIndicator()));
  }
}

class _NoPhotosCard extends StatelessWidget {
  const _NoPhotosCard();

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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('No photos yet', style: XploreText.bodyStrong.copyWith(color: XploreColors.white)),
                      const SizedBox(height: 2),
                      Text(
                        'Add the first shots from your trip for everyone to see.',
                        style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(CupertinoIcons.chevron_right, size: 16, color: XploreColors.tertiaryLabel),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
