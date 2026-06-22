import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/core/header.dart';
import 'package:xplore/core/icon_button.dart';
import 'package:xplore/core/layout_padding.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/features/itinerary/widgets/itinerary_tile.dart';
import 'package:xplore/utilities/utilities.dart';

class ItineraryOverviewPage extends StatelessWidget {
  final DailyPlanModel dailyPlan;

  const ItineraryOverviewPage({required this.dailyPlan, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: getScreenHeight(context: context, percent: 0.45),
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/placeholders/skytree.jpeg'),
                        fit: BoxFit.fitWidth,
                      ),
                    ),
                  ),
                  LayoutPadding(
                    enableHeaderPadding: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dailyPlan.title, style: context.pText.headlineMedium),
                        const SizedBox(height: 30),
                        _renderChecklist(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              child: Header(
                leadingWidget: XploreIconBtn(
                  bgColor: XploreColors.darkBg,
                  onTapCallback: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: headerIconSize),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _renderChecklist() {
    return LayoutBuilder(
      builder: (context, bc) {
        const rowSize = 60.0;

        return SizedBox(
          width: bc.maxWidth,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  ...dailyPlan.plan.locations.map(
                    (el) => Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 40),
                      child: _renderCheckOrCircle(el, rowSize),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: paddingUnit * 2),
              Column(
                children: [
                  ...dailyPlan.plan.locations.map(
                    (el) => Padding(
                      padding: const EdgeInsets.only(bottom: 30),
                      child: ItineraryTile(locationPlan: el, width: bc.maxWidth, height: rowSize),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _renderCheckOrCircle(LocationPlanModel locationPlan, double rowSize) {
    if (locationPlan.completed) {
      return XploreIconBtn(
        icon: Icon(Icons.check, color: XploreColors.darkBg, size: 30),
        onTapCallback: () {},
        size: rowSize,
        borderRadius: 100,
      );
    }
    return XploreIconBtn(
      onTapCallback: () {},
      size: rowSize,
      borderColor: XploreColors.alternate,
      bgColor: XploreColors.darkBg,
      borderRadius: 100,
    );
  }
}
