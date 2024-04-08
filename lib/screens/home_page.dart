import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/core/header.dart';
import 'package:xplore/core/icon_button.dart';
import 'package:xplore/core/layout_padding.dart';
import 'package:xplore/core/navbar.dart';
import 'package:xplore/features/gallery/bloc/gallery_cubit.dart';
import 'package:xplore/features/itinerary/bloc/itinerary_cubit.dart';
import 'package:xplore/features/itinerary/widgets/itinerary_card.dart';
import 'package:xplore/routes.dart';
import 'package:xplore/utilities/utilities.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const Navbar(),
      body: SafeArea(
        child: LayoutPadding(
          header: Header(
            leadingWidget: XploreIconBtn(
              onTapCallback: () => Navigator.pushNamed(context, Paths.profile),
              bgColor: XploreColors.darkBg,
              icon: const Icon(Icons.person_2_outlined, size: 35),
            ),
            trailingWidget: XploreIconBtn(
              bgColor: XploreColors.darkBg,
              onTapCallback: () => log('tapped'),
              icon: const Icon(Icons.notifications, size: 35),
            ),
          ),
          child: SingleChildScrollView(
            child: SizedBox(
              width: getScreenWidth(context: context),
              height: getScreenHeight(context: context),
              child: Column(
                children: [
                  //! Daily Plans Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Daily Plans', style: context.pText.headlineMedium),
                      TextButton(
                        onPressed: null,
                        child: Text(
                          'See all',
                          style: context.pText.bodySmall?.copyWith(color: XploreColors.alternate),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: paddingUnit),

                  //! Daily Plans Section Containers
                  BlocBuilder<ItineraryCubit, ItineraryStates>(
                    builder: (context, state) {
                      if (state is InitialItineraryState) {
                        return const SizedBox(
                          height: 300,
                          width: 230,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final itinerary = (state as LoadedItineraryState).itinerary;

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ...itinerary.dailyPlans.map(
                              (dailyPlan) => Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: SizedBox(
                                  width: ItineraryCard.width,
                                  height: ItineraryCard.height,
                                  child: ItineraryCard(dailyPlan: dailyPlan),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: paddingUnit),

                  //! Gallery Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Gallery', style: context.pText.headlineMedium),
                    ],
                  ),
                  const SizedBox(height: paddingUnit),

                  //! Gallery options
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            context.push(Paths.gallery);
                          },
                          child: Text(
                            'View gallery',
                            style: context.pText.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: paddingUnit),
                        OutlinedButton(
                          onPressed: () async {
                            await context.read<ItineraryCubit>().loadDemoItinerary();
                          },
                          child: Text(
                            'Load data',
                            style: context.pText.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: paddingUnit),
                        OutlinedButton(
                          onPressed: () async {
                            context.push(Paths.gallery);
                            await context.read<GalleryCubit>().uploadToGallery();
                          },
                          child: Text(
                            'Upload',
                            style: context.pText.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: paddingUnit),
                        OutlinedButton(
                          onPressed: () async {
                            await context.read<GalleryCubit>().deleteAll();
                          },
                          child: Text(
                            'Delete Hive',
                            style: context.pText.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
