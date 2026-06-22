import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/core/header.dart';
import 'package:xplore/core/icon_button.dart';
import 'package:xplore/core/layout_padding.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';

class ItineraryFocusPage extends StatelessWidget {
  final LocationPlanModel locationPlan;

  const ItineraryFocusPage({required this.locationPlan, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutPadding(
          header: Header(
            leadingWidget: XploreIconBtn(
              bgColor: XploreColors.darkBg,
              onTapCallback: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, size: 45),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                //! Heading
                Text(locationPlan.name, style: context.pText.headlineMedium),
                const SizedBox(height: paddingUnit),
                Text(locationPlan.description, style: context.pText.bodySmall),
                const SizedBox(height: paddingUnit * 4),

                //! Gallery
                Text('Gallery', style: context.pText.headlineMedium),
                const SizedBox(height: paddingUnit),
                const _LocationGalleryEmptyState(),
                const SizedBox(height: paddingUnit),

                //! Vibes
                Text('Vibes', style: context.pText.headlineMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationGalleryEmptyState extends StatelessWidget {
  const _LocationGalleryEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(paddingUnit * 1.5),
      decoration: BoxDecoration(
        color: XploreColors.tertiary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: XploreColors.alternate.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: XploreColors.alternate.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.photo_library_outlined, color: XploreColors.alternate, size: 28),
          ),
          const SizedBox(width: paddingUnit),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No photos here yet', style: context.pText.labelSmall),
                const SizedBox(height: paddingUnit / 3),
                Text(
                  'Photos from this stop will appear here once your group adds them.',
                  style: context.pText.bodySmall?.copyWith(color: XploreColors.white.withValues(alpha: 0.72)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
