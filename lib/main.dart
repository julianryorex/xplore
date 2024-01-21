import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/constants/theme.dart';
import 'package:xplore/core/header.dart';
import 'package:xplore/features/itinerary/bloc/itinerary_cubit.dart';
import 'package:xplore/features/itinerary/widgets/itinerary_card.dart';
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
                              return Container(color: Colors.red);
                            }

                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  ItineraryCard(
                                    title: 'SkyTree Day',
                                    location: 'Tokyo',
                                    onTap: () => Navigator.pushNamed(context, Paths.itineraryOverview),
                                  ),
                                  const SizedBox(width: 10),
                                  ItineraryCard(title: 'Shinjuku Day', location: 'Tokyo', onTap: () {}),
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
            const SizedBox(height: paddingUnit * 4, child: Header()),
          ],
        ),
      ),
    );
  }
}
