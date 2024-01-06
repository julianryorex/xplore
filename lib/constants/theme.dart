import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';

final defaultTextTheme = TextTheme(
  headlineLarge: TextStyle(fontSize: 40, fontWeight: FontWeight.w600, color: XploreColors.white), // H1
  headlineMedium: TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: XploreColors.white), // H2
  headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: XploreColors.white), // H3
  bodyLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: XploreColors.white), // Body 1
  bodyMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: XploreColors.white), // Body 2
  bodySmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: XploreColors.white), // Body 3
  labelLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: XploreColors.white), // Field Label
  labelMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: XploreColors.white), // Field Label
  labelSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: XploreColors.white), // Field Label Small
);

ThemeData getTheme() => ThemeData(
      colorScheme: ColorScheme(
        primary: XploreColors.primary,
        secondary: XploreColors.secondary,
        background: XploreColors.primaryBg,
        brightness: Brightness.dark,
        onPrimary: XploreColors.primaryText,
        onSecondary: XploreColors.secondaryText,
        error: XploreColors.accent1,
        onError: XploreColors.primaryText,
        onBackground: XploreColors.primaryText,
        surface: XploreColors.secondaryBg,
        onSurface: XploreColors.primaryText,
      ),
      // primaryColor: XploreColors.darkGrey,
      scaffoldBackgroundColor: XploreColors.primaryBg,
      textTheme: defaultTextTheme,
      // progressIndicatorTheme: ProgressIndicatorThemeData(color: XploreColors.pupCyan),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          shape: MaterialStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
          ),
          // backgroundColor: MaterialStatePropertyAll(XploreColors.pupCyan),
          textStyle: MaterialStatePropertyAll(defaultTextTheme.bodyMedium),
          minimumSize: const MaterialStatePropertyAll(Size(250, 62)),
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    );
