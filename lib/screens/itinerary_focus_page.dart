import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/core/header.dart';
import 'package:xplore/core/icon_button.dart';
import 'package:xplore/core/layout_padding.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';

class ItineraryFocusPage extends StatelessWidget {
  final LocationPlanModel locationPlan;

  const ItineraryFocusPage({
    required this.locationPlan,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: LayoutPadding(
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
                    Container(height: 120, color: Colors.green),
                    const SizedBox(height: paddingUnit),

                    //! Vibes
                    Text('Vibes', style: context.pText.headlineMedium),
                  ],
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
        ),
      ),
    );
  }
}
