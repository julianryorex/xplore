import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';

final defaultTextTheme = TextTheme(
  headlineLarge: TextStyle(fontSize: 40, fontWeight: FontWeight.w600, color: XploreColors.white), // H1
  headlineMedium: TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: XploreColors.white), // H2
  headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: XploreColors.white), // H3
  bodyLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: XploreColors.white), // Body 1
  bodyMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: XploreColors.white), // Body 2
  bodySmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: XploreColors.white), // Body 3
  labelLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: XploreColors.white), // Field Label
  labelMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: XploreColors.white), // Field Label
  labelSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: XploreColors.white), // Field Label Small
);

ThemeData getTheme() => ThemeData(
      colorScheme: ColorScheme(
        primary: XploreColors.primary,
        secondary: XploreColors.secondary,
        brightness: Brightness.dark,
        onPrimary: XploreColors.primaryText,
        onSecondary: XploreColors.secondaryText,
        error: XploreColors.error,
        onError: XploreColors.primaryText,
        surface: XploreColors.secondaryBg,
        onSurface: XploreColors.primaryText,
      ),
      scaffoldBackgroundColor: XploreColors.primaryBg,
      fontFamily: 'Poppins',
      textTheme: defaultTextTheme,
      progressIndicatorTheme: ProgressIndicatorThemeData(color: XploreColors.secondary),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          ),
          backgroundColor: WidgetStatePropertyAll(XploreColors.alternate),
          textStyle: WidgetStatePropertyAll(defaultTextTheme.bodyMedium),
          minimumSize: const WidgetStatePropertyAll(Size(250, 62)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          ),
          textStyle: WidgetStatePropertyAll(defaultTextTheme.bodyMedium),
          side: WidgetStatePropertyAll(
            BorderSide(color: XploreColors.alternate, width: 1),
          ),
          overlayColor: WidgetStatePropertyAll(XploreColors.primary),
          minimumSize: const WidgetStatePropertyAll(Size(140, 62)),
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    );
