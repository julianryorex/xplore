import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/features/gallery/bloc/gallery_cubit.dart';

class GalleryPicker extends StatelessWidget {
  const GalleryPicker({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, bc) {
        return DottedBorder(
          options: RoundedRectDottedBorderOptions(
            dashPattern: const [8, 6],
            strokeWidth: 5,
            color: XploreColors.secondary,
            radius: const Radius.circular(20),
          ),
          child: Container(
            width: bc.maxWidth,
            height: 100,
            decoration: BoxDecoration(
              color: XploreColors.secondary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Material(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              clipBehavior: Clip.hardEdge,
              color: Colors.transparent,
              child: InkWell(
                splashColor: XploreColors.secondary.withOpacity(0.1),
                highlightColor: XploreColors.secondary.withOpacity(0.1),
                onTap: () async {
                  await context.read<GalleryCubit>().uploadToGallery();
                }, // Open photos
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_rounded),
                      const SizedBox(width: paddingUnit / 2),
                      Text('Upload to trip', style: context.pText.labelSmall),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
