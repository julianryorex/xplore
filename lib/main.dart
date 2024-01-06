import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:xplore/constants/theme.dart';
import 'package:xplore/routes.dart';

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
    return Container(color: Colors.red);
  }
}
