import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/core/enums.dart';
import 'package:xplore/core/header.dart';
import 'package:xplore/core/icon_button.dart';
import 'package:xplore/core/layout_padding.dart';
import 'package:xplore/features/gallery/bloc/gallery_cubit.dart';
import 'package:xplore/features/gallery/presentation/gallery_grid.dart';
import 'package:xplore/features/gallery/presentation/gallery_picker.dart';
import 'package:xplore/utilities/utilities.dart';

class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<GalleryCubit, GalleryState>(
          builder: (context, state) {
            return Stack(
              children: [
                if (state.status == EBlocStatus.loading)
                  SizedBox(
                    width: getScreenWidth(context: context),
                    height: getScreenHeight(context: context),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                AnimatedOpacity(
                  opacity: state.status == EBlocStatus.loading ? 0.3 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: LayoutPadding(
                    enableHeaderPadding: true,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Trip Gallery', style: context.pText.headlineLarge, textAlign: TextAlign.start),
                          const SizedBox(height: paddingUnit * 2),
                          const GalleryPicker(),
                          const SizedBox(height: paddingUnit * 2),
                          Builder(
                            builder: (context) {
                              if (state.imageMap.isEmpty) {
                                return Padding(
                                  key: Key('emptyText_${state.imageMap.entries.isEmpty.toString()}'),
                                  padding: const EdgeInsets.only(
                                    top: paddingUnit * 15,
                                    right: paddingUnit * 3,
                                    left: paddingUnit * 3,
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Start uploading pictures to share with others!',
                                      textAlign: TextAlign.center,
                                      style: context.pText.bodyMedium,
                                    ),
                                  ),
                                );
                              }

                              return GalleryGrid(gallery: state.imageMap.values.toList());
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Header(
                  leadingWidget: XploreIconBtn(
                    bgColor: XploreColors.darkBg,
                    onTapCallback: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, size: 45),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
