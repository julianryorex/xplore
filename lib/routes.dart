import 'package:flutter/material.dart';
import 'package:xplore/main.dart';
import 'package:xplore/screens/gallery_page.dart';
import 'package:xplore/screens/itinerary_overview_page.dart';

class Paths {
  static const home = '/';
  static const onboarding = '/onboarding-flow';
  static const gallery = '/gallery';

  static const itineraryOverview = '/itinerary-overview';
  static const itineraryFocusView = '/itinerary-focus-view';
  static const itineraryMapView = '/itinerary-map-view';
}

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    // final args = settings.arguments;

    switch (settings.name) {
      case Paths.home:
        return MaterialPageRoute(builder: (_) => const HomePage());
      case Paths.onboarding:
        return MaterialPageRoute(builder: (_) => Container());
      case Paths.gallery:
        return MaterialPageRoute(builder: (_) => const GalleryPage());
      case Paths.itineraryOverview:
        return MaterialPageRoute(builder: (_) => const ItineraryOverviewPage());

      default:
        return MaterialPageRoute(builder: (_) => Container());
    }
  }
}
