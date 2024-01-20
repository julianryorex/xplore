import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/constants/theme.dart';
import 'package:xplore/core/header.dart';
import 'package:xplore/core/icon_button.dart';
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: getTheme(),
      onGenerateRoute: RouteGenerator.generateRoute,
    );

    // return MultiBlocProvider(
    //   providers: const [
    //     // BlocProvider<AuthCubit>(create: (_) => AuthCubit(), lazy: false),
    //   ],
    //   child: MaterialApp(
    //     debugShowCheckedModeBanner: false,
    //     theme: getTheme(),
    //     onGenerateRoute: RouteGenerator.generateRoute,
    //   ),
    // );
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
                        SingleChildScrollView(
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
                              onPressed: () {},
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

class ItineraryCard extends StatelessWidget {
  final String title;
  final String location;
  final void Function() onTap;

  const ItineraryCard({
    required this.title,
    required this.location,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 291,
      width: 230,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: XploreColors.alternate,
      ),
      child: Material(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        clipBehavior: Clip.hardEdge,
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(paddingUnit),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    XploreIconBtn(
                      onTapCallback: () => print('liked!'),
                      bgColor: XploreColors.tertiary,
                      icon: Icon(
                        Icons.favorite_border_rounded,
                        color: XploreColors.alternate,
                        size: 25,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        title,
                        style: context.pText.headlineSmall?.copyWith(height: 1),
                      ),
                      Text(
                        location,
                        style: context.pText.headlineSmall?.copyWith(fontSize: 20, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
