import 'package:flutter/material.dart';
import 'package:xplore/main.dart';
import 'package:xplore/screens/gallery_page.dart';

class Paths {
  static const home = '/';
  static const onboarding = '/onboarding-flow';
  static const gallery = '/gallery';
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

      default:
        return MaterialPageRoute(builder: (_) => Container());
    }
  }
}
