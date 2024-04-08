import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';
import 'package:xplore/constants/theme.dart';
import 'package:xplore/features/gallery/bloc/gallery_cubit.dart';
import 'package:xplore/features/gallery/models/image_models.dart';
import 'package:xplore/features/itinerary/bloc/itinerary_cubit.dart';
import 'package:xplore/features/location/bloc/location_cubit.dart';
import 'package:xplore/features/map/bloc/map_cubit.dart';
import 'package:xplore/features/nav/bloc/nav_cubit.dart';
import 'package:xplore/features/profile/bloc/profile_cubit.dart';
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

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  logger.d('Firebase initialized');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<LocationCubit>(create: (_) => LocationCubit(), lazy: false),
        BlocProvider<NavbarCubit>(create: (_) => NavbarCubit()),
        BlocProvider<ItineraryCubit>(create: (_) => ItineraryCubit()),
        BlocProvider<MapCubit>(create: (_) => MapCubit()),
        BlocProvider<GalleryCubit>(create: (_) => GalleryCubit()),
        BlocProvider<ProfileCubit>(create: (_) => ProfileCubit()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: getTheme(),
        onGenerateRoute: RouteGenerator.generateRoute,
      ),
    );
  }
}
