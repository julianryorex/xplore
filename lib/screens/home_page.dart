import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/core/header.dart';
import 'package:xplore/core/icon_button.dart';
import 'package:xplore/core/layout_padding.dart';
import 'package:xplore/core/navbar.dart';
import 'package:xplore/core/section_header.dart';
import 'package:xplore/features/gallery/bloc/gallery_cubit.dart';
import 'package:xplore/features/itinerary/bloc/itinerary_cubit.dart';
import 'package:xplore/features/itinerary/widgets/itinerary_card.dart';
import 'package:xplore/features/profile/bloc/profile_cubit.dart';
import 'package:xplore/routes.dart';

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
              icon: const Icon(Icons.person_2_outlined, size: headerIconSize),
            ),
            trailingWidget: XploreIconBtn(
              bgColor: XploreColors.darkBg,
              onTapCallback: () => log('tapped'),
              icon: const Icon(Icons.notifications_none_rounded, size: headerIconSize),
            ),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(bottom: paddingUnit * 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'Daily Plans', actionLabel: 'See all'),
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
                  const SizedBox(height: paddingUnit * 2),

                  //! Gallery Section Header
                  const SectionHeader(title: 'Gallery'),
                  const SizedBox(height: paddingUnit),

                  //! Gallery options
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(paddingUnit * 1.5),
                    decoration: BoxDecoration(
                      color: XploreColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(radiusLg),
                      border: Border.all(color: XploreColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Keep every trip moment in one shared place.', style: context.pText.bodyMedium),
                        const SizedBox(height: paddingUnit),
                        OutlinedButton.icon(
                          onPressed: () => context.push(Paths.gallery),
                          icon: const Icon(Icons.photo_library_outlined, size: 20),
                          label: const Text('View gallery'),
                        ),
                      ],
                    ),
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: paddingUnit),
                    Wrap(
                      spacing: paddingUnit,
                      runSpacing: paddingUnit,
                      children: [
                        OutlinedButton(
                          onPressed: () async {
                            await context.read<ItineraryCubit>().loadDemoItinerary();
                          },
                          child: const Text('Load data'),
                        ),
                        OutlinedButton(
                          onPressed: () async {
                            context.push(Paths.gallery);
                            await context.read<GalleryCubit>().uploadToGallery();
                          },
                          child: const Text('Upload'),
                        ),
                        OutlinedButton(
                          onPressed: () async {
                            context.read<GalleryCubit>().deleteAll();
                            // context.read<LocationCubit>().deleteAll();
                            context.read<ProfileCubit>().deleteAll();
                          },
                          child: const Text('Delete Hive'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
