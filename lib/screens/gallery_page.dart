import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/core/ambient_background.dart';
import 'package:xplore/core/enums.dart';
import 'package:xplore/core/glass.dart';
import 'package:xplore/core/header.dart';
import 'package:xplore/features/gallery/bloc/gallery_cubit.dart';
import 'package:xplore/features/gallery/presentation/gallery_grid.dart';
import 'package:xplore/features/gallery/presentation/gallery_picker.dart';

class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final topInset = viewPadding.top;
    // Gap between the status bar and the header controls.
    const headerTopGap = paddingUnit * 0.75;
    final headerZone = topInset + headerTopGap + Header.padding;
    final bottomClearance = viewPadding.bottom + paddingUnit * 2;

    return Scaffold(
      backgroundColor: XploreColors.primaryBg,
      body: AmbientBackground(
        child: BlocBuilder<GalleryCubit, GalleryState>(
          builder: (context, state) {
            final isLoading = state.status == EBlocStatus.loading;

            return Stack(
              children: [
                // Content runs full-height behind the pinned header so the glass
                // surfaces have colourful content to refract.
                AnimatedOpacity(
                  opacity: isLoading ? 0.3 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: paddingUnit * 1.5,
                      right: paddingUnit * 1.5,
                      top: headerZone + paddingUnit * 0.5,
                      bottom: bottomClearance,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const GalleryPicker(),
                        const SizedBox(height: paddingUnit * 2),
                        if (state.imageMap.isEmpty)
                          Padding(
                            key: Key('emptyText_${state.imageMap.entries.isEmpty}'),
                            padding: const EdgeInsets.only(
                              top: paddingUnit * 12,
                              right: paddingUnit * 3,
                              left: paddingUnit * 3,
                            ),
                            child: Center(
                              child: Text(
                                'Start uploading pictures to share with others!',
                                textAlign: TextAlign.center,
                                style: context.pText.bodyMedium?.copyWith(color: XploreColors.mutedText),
                              ),
                            ),
                          )
                        else
                          GalleryGrid(gallery: state.imageMap.values.toList()),
                      ],
                    ),
                  ),
                ),
                if (isLoading) const Center(child: CircularProgressIndicator()),
                // Top scrim: blends the status-bar area into the base colour and
                // keeps content legible as it scrolls beneath the pinned header.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: headerZone + paddingUnit * 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            XploreColors.primaryBg,
                            XploreColors.primaryBg,
                            XploreColors.primaryBg.withValues(alpha: 0),
                          ],
                          stops: const [0, 0.6, 1],
                        ),
                      ),
                    ),
                  ),
                ),
                // Pinned header, sitting just below the status bar.
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
                    titleWidget: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trip Gallery',
                          style: context.pText.labelLarge?.copyWith(letterSpacing: -0.2),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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
}
