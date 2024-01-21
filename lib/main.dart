import 'dart:developer';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/constants/theme.dart';
import 'package:xplore/core/header.dart';
import 'package:xplore/core/icon_button.dart';
import 'package:xplore/features/itinerary/bloc/itinerary_cubit.dart';
import 'package:xplore/features/itinerary/widgets/itinerary_card.dart';
import 'package:xplore/firebase_options.dart';
import 'package:xplore/routes.dart';
import 'package:xplore/utilities/utilities.dart';

Future<void> init() async {
  try {
    await dotenv.load(fileName: 'assets/.env');
    log('Env file loaded');
  } catch (err) {
    log('Env file NOT found');
  }
}

Future<void> main() async {
  await init();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ItineraryCubit>(create: (_) => ItineraryCubit()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: getTheme(),
        onGenerateRoute: RouteGenerator.generateRoute,
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(top: paddingUnit * 4),
                child: SizedBox(
                  width: getScreenWidth(context: context),
                  height: getScreenHeight(context: context),
                  child: Padding(
                    padding: const EdgeInsets.only(left: paddingUnit * 2, right: paddingUnit * 2, top: paddingUnit * 3),
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
                        Row(
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
                                'Upload',
                                style: context.pText.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Header(
              leadingWidget: XploreIconBtn(
                onTapCallback: () => print('tapped'),
                bgColor: XploreColors.darkBg,
                icon: const Icon(Icons.person_2_outlined, size: 35),
              ),
              trailingWidget: XploreIconBtn(
                bgColor: XploreColors.darkBg,
                onTapCallback: () => print('tapped'),
                icon: const Icon(Icons.notifications, size: 35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
