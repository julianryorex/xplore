import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/core/header.dart';
import 'package:xplore/core/icon_button.dart';
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
    displayNav = false;

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
    return Scaffold(
      backgroundColor: displayNav ? XploreColors.white : XploreColors.darkBg,
      body: GestureDetector(
        onTap: () => setState(() => displayNav = !displayNav),
        child: SafeArea(
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
                    backgroundDecoration: BoxDecoration(color: displayNav ? XploreColors.white : XploreColors.darkBg),
                    pageController: controller,
                    onPageChanged: onPageChanged,
                    wantKeepAlive: true,
                  );
                },
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: displayNav ? 1 : 0,
                child: Header(
                  leadingWidget: XploreIconBtn(
                    hasVibrations: true,
                    bgColor: XploreColors.darkBg,
                    onTapCallback: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, size: headerIconSize),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
