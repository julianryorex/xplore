import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/core/glass.dart';
import 'package:xplore/core/header.dart';
import 'package:xplore/features/gallery/bloc/gallery_cubit.dart';
import 'package:xplore/features/gallery/models/image_models.dart';
import 'package:xplore/utilities/utilities.dart';

class GalleryFocusView extends StatefulWidget {
  final List<ImageModel> images;
  final int initialIndex;

  const GalleryFocusView({required this.images, required this.initialIndex, super.key});

  @override
  State<GalleryFocusView> createState() => _GalleryFocusViewState();
}

class _GalleryFocusViewState extends State<GalleryFocusView> {
  late final PageController controller;
  late Map<int, Uint8List?> highResImagesCache;
  late int curentIndex;
  late bool displayNav;

  @override
  void initState() {
    super.initState();
    curentIndex = widget.initialIndex;
    controller = PageController(initialPage: curentIndex);
    highResImagesCache = {};
    displayNav = true;

    fetchHighResAsset(curentIndex);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void onPageChanged(int nextIndx) {
    curentIndex = nextIndx;
    fetchHighResAsset(nextIndx);
  }

  void fetchHighResAsset(int index) {
    context.read<GalleryCubit>().fetchHighResAsset(widget.images[index].id).then((imgBytes) {
      setState(() {
        highResImagesCache = Map.from(highResImagesCache)..addAll({index: imgBytes});
      });

      wlog.d('fetched index $index');
    });
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    const headerTopGap = paddingUnit * 0.75;

    return Scaffold(
      backgroundColor: XploreColors.black,
      body: GestureDetector(
        onTap: () => setState(() => displayNav = !displayNav),
        child: Stack(
          children: [
            BlocBuilder<GalleryCubit, GalleryState>(
              builder: (context, state) {
                return PhotoViewGallery.builder(
                  scrollPhysics: const BouncingScrollPhysics(),
                  builder: (BuildContext context, int index) {
                    return PhotoViewGalleryPageOptions(
                      imageProvider: highResImagesCache[index] != null
                          ? MemoryImage(highResImagesCache[index]!)
                          : MemoryImage(widget.images[index].lowResImage),
                      initialScale: PhotoViewComputedScale.contained,
                      minScale: PhotoViewComputedScale.contained,
                      maxScale: PhotoViewComputedScale.contained * 2,
                      heroAttributes: PhotoViewHeroAttributes(tag: widget.images[index].id),
                    );
                  },
                  itemCount: widget.images.length,
                  loadingBuilder: (context, event) =>
                      Center(child: Image.memory(widget.images[curentIndex].lowResImage)),
                  backgroundDecoration: BoxDecoration(color: XploreColors.black),
                  pageController: controller,
                  onPageChanged: onPageChanged,
                  wantKeepAlive: true,
                );
              },
            ),
            // Floating glass chrome over the image — fades out on tap so the
            // photo can be viewed unobstructed.
            IgnorePointer(
              ignoring: !displayNav,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: displayNav ? 1 : 0,
                child: Stack(
                  children: [
                    // Top scrim keeps the glass controls legible over bright photos.
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Container(
                          height: topInset + Header.padding + paddingUnit * 2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                XploreColors.black.withValues(alpha: 0.55),
                                XploreColors.black.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: topInset + headerTopGap,
                      left: 0,
                      right: 0,
                      child: Header(
                        leadingWidget: GlassIconButton(
                          size: 44,
                          iconSize: 22,
                          icon: Icons.close_rounded,
                          tooltip: 'Close',
                          onTap: () => Navigator.pop(context),
                        ),
                        trailingWidget: _PhotoCounter(index: curentIndex, total: widget.images.length),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoCounter extends StatelessWidget {
  final int index;
  final int total;

  const _PhotoCounter({required this.index, required this.total});

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      strong: true,
      borderRadius: radiusLg,
      padding: const EdgeInsets.symmetric(horizontal: paddingUnit, vertical: paddingUnit * 0.5),
      child: Text(
        '${index + 1} / $total',
        style: TextStyle(color: XploreColors.white, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}
