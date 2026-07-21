import 'package:animations/animations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/core/app_tab.dart';
import 'package:xplore/core/root_shell.dart';
import 'package:xplore/features/auth/presentation/onboarding_page.dart';
import 'package:xplore/features/auth/presentation/sign_in_page.dart';
import 'package:xplore/features/auth/services/auth_service.dart';
import 'package:xplore/features/dev/presentation/dev_tools_page.dart';
import 'package:xplore/features/gallery/presentation/gallery_focus_view.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/features/notifications/presentation/notifications_page.dart';
import 'package:xplore/features/trip/bloc/join_trip_cubit.dart';
import 'package:xplore/features/trip/bloc/trip_creation_cubit.dart';
import 'package:xplore/features/trip/presentation/create_trip/create_trip_flow_page.dart';
import 'package:xplore/features/trip/presentation/join_trip_page.dart';
import 'package:xplore/features/trip/services/invite_link.dart';
import 'package:xplore/features/trip/services/itinerary_generator.dart';
import 'package:xplore/features/trip/services/trip_service.dart';
import 'package:xplore/screens/gallery_page.dart';
import 'package:xplore/screens/generic_error_page.dart';
import 'package:xplore/screens/itinerary_focus_page.dart';
import 'package:xplore/screens/itinerary_overview_page.dart';
import 'package:xplore/screens/profile_page.dart';
import 'package:xplore/utilities/utilities.dart';

class Paths {
  static const home = '/';
  static const map = '/map';
  static const onboarding = '/onboarding-flow';
  static const signIn = '/sign-in';
  static const gallery = '/gallery';
  static const galleryFocusView = '/gallery-focus';

  static const itineraryOverview = '/itinerary-overview';
  static const itineraryFocusView = '/itinerary-focus-view';
  static const itineraryMapView = '/itinerary-map-view';

  static const profile = '/profile';
  static const notifications = '/notifications';

  /// Developer tools page (FEAT-008), gated behind `kDebugMode` at its
  /// entry-points.
  static const dev = '/dev';

  /// Multi-step generative trip-creation flow (FEAT-007).
  static const createTrip = '/create-trip';

  /// Invite join-confirmation screen. Reached via an invite deep link
  /// (`https://xplore.app/join?trip=...&token=...`); expects an
  /// [InviteLinkData] as its route argument.
  static const joinTrip = '/join';
}

class RouteGenerator {
  static final Logger _logger = createLogger('Router');

  static Route<dynamic> generateRoute(RouteSettings settings) {
    final args = settings.arguments;

    switch (settings.name) {
      case Paths.home:
      case Paths.map:
        // Home/Map are top-level siblings in RootShell's tab stack. Legacy
        // route entries still resolve to the shell, with `/map` selecting the
        // Map tab for deep links and old callers.
        return MaterialPageRoute(
          builder: (_) => RootShell(initialTab: settings.name == Paths.map ? AppTab.map : AppTab.home),
          settings: settings,
        );
      case Paths.profile:
        return MaterialPageRoute(builder: (_) => const ProfilePage(), settings: settings);
      case Paths.dev:
        // Defense-in-depth: the only entry point is kDebugMode-gated, but a
        // deep link could still target /dev — never expose it in release.
        if (!kDebugMode) {
          return MaterialPageRoute(builder: (_) => const ErrorScreen(), settings: settings);
        }
        return MaterialPageRoute(builder: (_) => const DevToolsPage(), settings: settings);
      case Paths.notifications:
        return MaterialPageRoute(builder: (_) => const NotificationsPage());
      case Paths.joinTrip:
        return MaterialPageRoute(
          settings: settings,
          builder: (context) {
            if (args is InviteLinkData) {
              return BlocProvider<JoinTripCubit>(
                create: (ctx) => JoinTripCubit(
                  ctx.read<TripService>(),
                  ctx.read<AuthService>(),
                  tripId: args.tripId,
                  token: args.token,
                ),
                child: const JoinTripPage(),
              );
            }

            _logger.e('argument is not of type "InviteLinkData"');
            return const ErrorScreen();
          },
        );
      case Paths.createTrip:
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => BlocProvider<TripCreationCubit>(
            create: (ctx) => TripCreationCubit(ctx.read<ItineraryGenerator>()),
            child: const CreateTripFlowPage(),
          ),
        );
      case Paths.onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingPage());
      case Paths.signIn:
        return MaterialPageRoute(builder: (_) => const SignInPage());
      case Paths.gallery:
        return MaterialPageRoute(builder: (_) => const GalleryPage());
      case Paths.galleryFocusView:
        // A photo viewer reads as "opening media", so it fades through rather
        // than sliding in sideways like the hierarchical drill-down screens.
        return FadeThroughPageRoute(
          settings: settings,
          builder: (_) {
            if (args is Map<String, dynamic> && args.containsKey('gallery') && args.containsKey('initialIndex')) {
              return GalleryFocusView(images: args['gallery'], initialIndex: args['initialIndex']);
            }

            _logger.e('argument is not of type "ImageModel"');
            return const ErrorScreen();
          },
        );
      case Paths.itineraryOverview:
        return MaterialPageRoute(
          builder: (_) {
            if (args is int) {
              return ItineraryOverviewPage(dayIndex: args);
            }

            _logger.e('argument is not of type "int" (itinerary day index)');
            return const ErrorScreen();
          },
        );
      case Paths.itineraryFocusView:
        return MaterialPageRoute(
          builder: (_) {
            if (args is LocationPlanModel) {
              return ItineraryFocusPage(locationPlan: args);
            }

            _logger.e('argument is not of type "LocationPlanModel"');
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

/// A route that uses Material's "fade through" motion — the outgoing screen
/// fades out while the incoming one fades and scales up. Best for destinations
/// without a clear spatial/back relationship (e.g. opening a media viewer).
///
/// Hierarchical drill-down pushes don't need a custom route: they go through
/// [MaterialPageRoute] and inherit the app-wide shared-axis transition
/// configured in `pageTransitionsTheme` (see `constants/theme.dart`).
class FadeThroughPageRoute<T> extends PageRouteBuilder<T> {
  FadeThroughPageRoute({required WidgetBuilder builder, super.settings})
    : super(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (context, animation, secondaryAnimation) => builder(context),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeThroughTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            fillColor: XploreColors.primaryBg,
            child: child,
          );
        },
      );
}
