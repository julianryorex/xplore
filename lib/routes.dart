import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:xplore/features/gallery/presentation/gallery_focus_view.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/main.dart';
import 'package:xplore/screens/gallery_page.dart';
import 'package:xplore/screens/generic_error_page.dart';
import 'package:xplore/screens/itinerary_focus_page.dart';
import 'package:xplore/screens/itinerary_overview_page.dart';
import 'package:xplore/screens/map_canvas.dart';

class Paths {
  static const home = '/';
  static const map = '/map';
  static const onboarding = '/onboarding-flow';
  static const gallery = '/gallery';
  static const galleryFocusView = '/gallery-focus';

  static const itineraryOverview = '/itinerary-overview';
  static const itineraryFocusView = '/itinerary-focus-view';
  static const itineraryMapView = '/itinerary-map-view';
}

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    final args = settings.arguments;

    switch (settings.name) {
      case Paths.home:
        return FadePageRoute(page: const HomePage());
      case Paths.map:
        return FadePageRoute(page: const MapCanvas());
      case Paths.onboarding:
        return MaterialPageRoute(builder: (_) => Container());
      case Paths.gallery:
        return MaterialPageRoute(builder: (_) => const GalleryPage());
      case Paths.galleryFocusView:
        return MaterialPageRoute(builder: (_) {
          if (args is Map<String, dynamic> && args.containsKey('gallery') && args.containsKey('initialIndex')) {
            return GalleryFocusView(
              images: args['gallery'],
              initialIndex: args['initialIndex'],
            );
          }

          log('argument is not of type "ImageModel"');
          return const ErrorScreen();
        });
      case Paths.itineraryOverview:
        return MaterialPageRoute(
          builder: (_) {
            if (args is DailyPlanModel) {
              return ItineraryOverviewPage(dailyPlan: args);
            }

            log('argument is not of type "DailyPlanModel"');
            return const ErrorScreen();
          },
        );
      case Paths.itineraryFocusView:
        return MaterialPageRoute(
          builder: (_) {
            if (args is LocationPlanModel) {
              return ItineraryFocusPage(locationPlan: args);
            }

            log('argument is not of type "LocationPlanModel"');
            return const ErrorScreen();
          },
        );

      default:
        return MaterialPageRoute(builder: (_) => const ErrorScreen());
    }
  }
}

//! ---------------------------------------------------------------------------
//! Custom Routes
//! ---------------------------------------------------------------------------

class FadePageRoute extends PageRouteBuilder {
  final Widget page;

  FadePageRoute({required this.page})
      : super(
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) {
            return page;
          },
          transitionsBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        );
}
