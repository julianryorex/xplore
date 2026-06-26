import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';

// `.apply(fontFamily: ...)` ensures Poppins is baked into every style, including
// the ones referenced directly by the component themes below (buttons). Relying
// on `ThemeData.fontFamily` alone leaves those raw TextStyles on the platform
// default font, which breaks typographic consistency across controls.
final defaultTextTheme = TextTheme(
  headlineLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.w600, height: 1.08, color: XploreColors.white),
  headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, height: 1.12, color: XploreColors.white),
  headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.18, color: XploreColors.white),
  bodyLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, height: 1.45, color: XploreColors.white),
  bodyMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, height: 1.45, color: XploreColors.white),
  bodySmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.45, color: XploreColors.mutedText),
  labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.3, color: XploreColors.white),
  labelMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.3, color: XploreColors.white),
  labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.3, color: XploreColors.mutedText),
).apply(fontFamily: 'Poppins');

ThemeData getTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme(
    primary: XploreColors.primary,
    secondary: XploreColors.secondary,
    brightness: Brightness.dark,
    onPrimary: XploreColors.white,
    onSecondary: XploreColors.white,
    error: XploreColors.error,
    onError: XploreColors.white,
    surface: XploreColors.surface,
    onSurface: XploreColors.white,
  ),
  scaffoldBackgroundColor: XploreColors.primaryBg,
  // Every hierarchical push (gallery, itinerary, profile, sign-in, errors) gets
  // the same coordinated slide + fade ("shared axis") that reverses correctly
  // on back, on every platform — replacing the inconsistent mix of platform
  // Cupertino slides and one-off fades. Top-level tab switches don't use this:
  // they fade in place inside RootShell instead of pushing routes.
  pageTransitionsTheme: PageTransitionsTheme(
    builders: {
      for (final platform in TargetPlatform.values)
        platform: const SharedAxisPageTransitionsBuilder(
          transitionType: SharedAxisTransitionType.horizontal,
          fillColor: Colors.transparent,
        ),
    },
  ),
  fontFamily: 'Poppins',
  textTheme: defaultTextTheme,
  dividerColor: XploreColors.divider,
  cardTheme: CardThemeData(
    color: XploreColors.surfaceElevated,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg)),
  ),
  progressIndicatorTheme: ProgressIndicatorThemeData(color: XploreColors.secondary),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ButtonStyle(
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd))),
      backgroundColor: WidgetStatePropertyAll(XploreColors.alternate),
      foregroundColor: WidgetStatePropertyAll(XploreColors.white),
      textStyle: WidgetStatePropertyAll(defaultTextTheme.labelLarge),
      minimumSize: const WidgetStatePropertyAll(Size(250, 62)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: ButtonStyle(
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd))),
      foregroundColor: WidgetStatePropertyAll(XploreColors.white),
      textStyle: WidgetStatePropertyAll(defaultTextTheme.labelMedium),
      side: WidgetStatePropertyAll(BorderSide(color: XploreColors.alternate.withValues(alpha: 0.72), width: 1)),
      overlayColor: WidgetStatePropertyAll(XploreColors.alternate.withValues(alpha: 0.08)),
      minimumSize: const WidgetStatePropertyAll(Size(132, 54)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) ? XploreColors.subtleText : XploreColors.alternate,
      ),
      textStyle: WidgetStatePropertyAll(defaultTextTheme.labelMedium),
    ),
  ),
  iconTheme: const IconThemeData(color: Colors.white),
);
