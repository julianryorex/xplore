import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/core/glass.dart';
import 'package:xplore/features/gallery/bloc/gallery_cubit.dart';

class GalleryPicker extends StatelessWidget {
  const GalleryPicker({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      borderRadius: radiusLg,
      padding: EdgeInsets.zero,
      onTap: () async {
        await context.read<GalleryCubit>().uploadToGallery();
      },
      child: DottedBorder(
        options: RoundedRectDottedBorderOptions(
          dashPattern: const [7, 6],
          strokeWidth: 1.5,
          padding: EdgeInsets.zero,
          color: XploreColors.alternate.withValues(alpha: 0.55),
          radius: const Radius.circular(radiusLg),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 104,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(paddingUnit * 0.75),
                decoration: BoxDecoration(
                  color: XploreColors.alternate.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(radiusSm),
                  border: Border.all(color: XploreColors.alternate.withValues(alpha: 0.32)),
                ),
                child: Icon(Icons.add_a_photo_outlined, size: 22, color: XploreColors.alternate),
              ),
              const SizedBox(width: paddingUnit),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Upload to trip', style: context.pText.labelLarge),
                  const SizedBox(height: 2),
                  Text(
                    'Add photos to the shared gallery.',
                    style: context.pText.bodySmall?.copyWith(color: XploreColors.mutedText),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
