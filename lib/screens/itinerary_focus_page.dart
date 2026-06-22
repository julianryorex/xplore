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
              icon: const Icon(Icons.arrow_back, size: headerIconSize),
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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(paddingUnit * 2),
                  decoration: BoxDecoration(
                    color: XploreColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(radiusLg),
                    border: Border.all(color: XploreColors.divider),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.photo_camera_outlined, color: XploreColors.alternate, size: 32),
                      const SizedBox(height: paddingUnit),
                      Text(
                        'Photos from this stop will appear here.',
                        textAlign: TextAlign.center,
                        style: context.pText.bodySmall,
                      ),
                    ],
                  ),
                ),
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
