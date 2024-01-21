import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/core/header.dart';
import 'package:xplore/core/icon_button.dart';
import 'package:xplore/features/itinerary/widgets/itinerary_tile.dart';
import 'package:xplore/utilities/utilities.dart';

class ItineraryOverviewPage extends StatelessWidget {
  const ItineraryOverviewPage({super.key});

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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SkyTree Day', style: context.pText.headlineMedium),
                        const SizedBox(height: 30),

                        //! Checklist goes here
                        LayoutBuilder(
                          builder: (context, bc) {
                            const rowSize = 60.0;

                            return SizedBox(
                              width: bc.maxWidth,
                              child: Row(
                                children: [
                                  Column(
                                    children: [
                                      //* checklist Column
                                      XploreIconBtn(
                                        icon: const Icon(Icons.abc),
                                        onTapCallback: () {},
                                        size: rowSize,
                                        borderRadius: 100,
                                      ),
                                      const SizedBox(height: 50),
                                      XploreIconBtn(
                                        icon: const Icon(Icons.abc),
                                        onTapCallback: () {},
                                        size: rowSize,
                                        borderRadius: 100,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: paddingUnit * 2),
                                  Column(
                                    children: [
                                      ItineraryTile(width: bc.maxWidth, height: rowSize),
                                      const SizedBox(height: 30),
                                      ItineraryTile(width: bc.maxWidth, height: rowSize),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SafeArea(child: SizedBox(height: paddingUnit * 4, child: Header())),
          ],
        ),
      ),
    );
  }
}
