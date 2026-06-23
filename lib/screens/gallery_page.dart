import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/core/ambient_background.dart';
import 'package:xplore/core/enums.dart';
import 'package:xplore/core/glass.dart';
import 'package:xplore/core/header.dart';
import 'package:xplore/features/gallery/bloc/gallery_cubit.dart';
import 'package:xplore/features/gallery/models/image_models.dart';
import 'package:xplore/routes.dart';

/// The Trip Gallery — a premium "album cover" layout.
///
/// A large hero cover with a glass overlay (title, photo count, upload action),
/// followed by a compact grid of the remaining photos. Built on the shared
/// liquid-glass primitives (`AmbientBackground`, `GlassSurface`,
/// `GlassIconButton`).
class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final topInset = viewPadding.top;
    const headerTopGap = paddingUnit * 0.75;
    final bottomClearance = viewPadding.bottom + paddingUnit * 2;
    final heroHeight = MediaQuery.sizeOf(context).height * 0.46;

    return Scaffold(
      backgroundColor: XploreColors.primaryBg,
      body: AmbientBackground(
        child: BlocBuilder<GalleryCubit, GalleryState>(
          builder: (context, state) {
            final isLoading = state.status == EBlocStatus.loading;
            final images = state.imageMap.values.toList();
            final cover = _coverImage(images);
            final rest = cover == null ? <ImageModel>[] : images.where((img) => img.id != cover.id).toList();

            return Stack(
              children: [
                AnimatedOpacity(
                  opacity: isLoading ? 0.3 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(bottom: bottomClearance),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Hero(
                          cover: cover,
                          height: heroHeight,
                          total: images.length,
                          onUpload: () => context.read<GalleryCubit>().uploadToGallery(),
                          onTapCover: cover == null ? null : () => _openFocus(context, images, images.indexOf(cover)),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(paddingUnit * 1.5, paddingUnit * 2, paddingUnit * 1.5, 0),
                          child: images.isEmpty
                              ? const _GalleryEmptyState()
                              : _CompactGrid(
                                  images: rest,
                                  onTapImage: (image) => _openFocus(context, images, images.indexOf(image)),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isLoading) const Center(child: CircularProgressIndicator()),
                // Floating glass back control over the hero.
                Positioned(
                  top: topInset + headerTopGap,
                  left: 0,
                  right: 0,
                  child: Header(
                    leadingWidget: GlassIconButton(
                      size: 44,
                      iconSize: 22,
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Prefer a fully-uploaded image for the cover; otherwise fall back to the
  /// first available image.
  ImageModel? _coverImage(List<ImageModel> images) {
    if (images.isEmpty) return null;
    return images.firstWhere((img) => img.isUploading == EUploadStatus.complete, orElse: () => images.first);
  }
}

void _openFocus(BuildContext context, List<ImageModel> gallery, int index) {
  Navigator.pushNamed(context, Paths.galleryFocusView, arguments: {'gallery': gallery, 'initialIndex': index});
}

class _Hero extends StatelessWidget {
  final ImageModel? cover;
  final double height;
  final int total;
  final VoidCallback onUpload;
  final VoidCallback? onTapCover;

  const _Hero({
    required this.cover,
    required this.height,
    required this.total,
    required this.onUpload,
    required this.onTapCover,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTapCover,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (cover != null)
              Image.memory(cover!.lowResImage, fit: BoxFit.cover)
            else
              DecoratedBox(decoration: BoxDecoration(color: XploreColors.surfaceElevated)),
            // Legibility gradient from the bottom for the overlay text.
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      XploreColors.primaryBg,
                      XploreColors.primaryBg.withValues(alpha: 0.2),
                      XploreColors.black.withValues(alpha: 0.25),
                    ],
                    stops: const [0, 0.55, 1],
                  ),
                ),
              ),
            ),
            Positioned(
              left: paddingUnit * 1.5,
              right: paddingUnit * 1.5,
              bottom: paddingUnit * 1.5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trip Gallery',
                    style: context.pText.headlineMedium?.copyWith(
                      color: XploreColors.white,
                      letterSpacing: -0.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    total == 0 ? 'No photos yet' : '$total ${total == 1 ? 'photo' : 'photos'}',
                    style: context.pText.bodyMedium?.copyWith(color: XploreColors.mutedText),
                  ),
                  const SizedBox(height: paddingUnit * 1.25),
                  GlassSurface(
                    strong: true,
                    borderRadius: radiusLg,
                    padding: const EdgeInsets.symmetric(horizontal: paddingUnit * 1.25, vertical: paddingUnit * 0.75),
                    onTap: onUpload,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_a_photo_outlined, size: 18, color: XploreColors.white),
                        const SizedBox(width: paddingUnit * 0.75),
                        Text(
                          'Add photos',
                          style: TextStyle(color: XploreColors.white, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactGrid extends StatelessWidget {
  final List<ImageModel> images;
  final void Function(ImageModel image) onTapImage;

  const _CompactGrid({required this.images, required this.onTapImage});

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: images.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: paddingUnit * 0.5,
        crossAxisSpacing: paddingUnit * 0.5,
      ),
      itemBuilder: (context, i) {
        final image = images[i];
        final isUploading =
            image.isUploading == EUploadStatus.uploading || image.isUploading == EUploadStatus.notStarted;

        return GestureDetector(
          onTap: isUploading ? null : () => onTapImage(image),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radiusSm),
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(color: XploreColors.surfaceElevated),
                  child: Opacity(
                    opacity: isUploading ? 0.4 : 1,
                    child: Image.memory(image.lowResImage, fit: BoxFit.cover),
                  ),
                ),
                if (isUploading)
                  Center(
                    child: SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: XploreColors.alternate),
                    ),
                  ),
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radiusSm),
                      border: Border.all(color: XploreColors.glassBorder),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GalleryEmptyState extends StatelessWidget {
  const _GalleryEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: paddingUnit * 6, right: paddingUnit * 3, left: paddingUnit * 3),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined, size: 40, color: XploreColors.subtleText),
            const SizedBox(height: paddingUnit),
            Text(
              'Start uploading pictures to share with others!',
              textAlign: TextAlign.center,
              style: context.pText.bodyMedium?.copyWith(color: XploreColors.mutedText),
            ),
          ],
        ),
      ),
    );
  }
}
