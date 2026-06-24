import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';
import 'package:xplore/constants/theme.dart';
import 'package:xplore/features/auth/bloc/auth_cubit.dart';
import 'package:xplore/features/auth/presentation/auth_gate.dart';
import 'package:xplore/features/auth/services/auth_service.dart';
import 'package:xplore/features/gallery/bloc/gallery_cubit.dart';
import 'package:xplore/features/gallery/models/image_models_adapters.dart';
import 'package:xplore/features/itinerary/bloc/itinerary_cubit.dart';
import 'package:xplore/features/location/bloc/location_cubit.dart';
import 'package:xplore/features/map/bloc/map_cubit.dart';
import 'package:xplore/features/nav/bloc/nav_cubit.dart';
import 'package:xplore/features/profile/bloc/profile_cubit.dart';
import 'package:xplore/features/trip/bloc/trip_cubit.dart';
import 'package:xplore/features/trip/services/trip_service.dart';
import 'package:xplore/firebase_options.dart';
import 'package:xplore/routes.dart';
import 'package:xplore/utilities/utilities.dart';

Future<void> init(Logger logger) async {
  try {
    await dotenv.load(fileName: 'assets/.env');
    logger.d('Env file loaded');
  } catch (err) {
    logger.e('Env file NOT found');
  }
}

Future<void> initHive(Logger logger) async {
  await Hive.initFlutter();
  Hive.registerAdapter(ImageModelAdapter());
  Hive.registerAdapter(EUploadStatusAdapter());
  logger.d('Hive initialized');
}

Future<void> main() async {
  final logger = createLogger('main');

  await init(logger);
  await initHive(logger);
  await initFirebase(logger);

  runApp(const MyApp());
}

Future<void> initFirebase(Logger logger) async {
  // firebase_core 4.x auto-initializes the default app natively on iOS when a
  // GoogleService-Info.plist is present, so a second initializeApp() throws
  // `duplicate-app`. Reuse the existing default app when that happens.
  if (Firebase.apps.isNotEmpty) {
    logger.d('Firebase already initialized (using existing default app)');
    return;
  }

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    logger.d('Firebase initialized');
  } on FirebaseException catch (err) {
    if (err.code == 'duplicate-app') {
      logger.d('Firebase already initialized (using existing default app)');
    } else {
      rethrow;
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // One AuthService instance is the single source of UID truth, composed into
    // every cubit (constructor injection) so none of them import another cubit.
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthService>(create: (_) => AuthService()),
        RepositoryProvider<TripService>(create: (_) => TripService()),
      ],
      child: Builder(
        builder: (context) {
          final authService = context.read<AuthService>();
          final tripService = context.read<TripService>();
          return MultiBlocProvider(
            providers: [
              BlocProvider<AuthCubit>(create: (_) => AuthCubit(authService), lazy: false),
              BlocProvider<TripCubit>(create: (_) => TripCubit(tripService, authService), lazy: false),
              BlocProvider<LocationCubit>(create: (_) => LocationCubit(authService), lazy: false),
              BlocProvider<NavbarCubit>(create: (_) => NavbarCubit()),
              BlocProvider<ItineraryCubit>(create: (_) => ItineraryCubit()),
              BlocProvider<MapCubit>(create: (_) => MapCubit(authService)),
              BlocProvider<GalleryCubit>(create: (_) => GalleryCubit(authService)),
              BlocProvider<ProfileCubit>(create: (_) => ProfileCubit(authService)),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: getTheme(),
              home: const AuthGate(),
              onGenerateRoute: RouteGenerator.generateRoute,
            ),
          );
        },
      ),
    );
  }
}
