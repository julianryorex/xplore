import 'package:flutter/material.dart';
import 'package:xplore/main.dart';

class Paths {
  static const login = '/login-flow';
  static const onboarding = '/onboarding-flow';
  static const home = '/';
}

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    // final args = settings.arguments;

    switch (settings.name) {
      case Paths.login:
        return MaterialPageRoute(builder: (_) => Container());
      case Paths.onboarding:
        return MaterialPageRoute(builder: (_) => Container());
      case Paths.home:
        return MaterialPageRoute(builder: (_) => const Scaffold(body: HomePage()));

      default:
        return MaterialPageRoute(builder: (_) => Container());
    }
  }
}
