import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';

/// The family name Flutter's engine registers for the platform system font on
/// Apple platforms (San Francisco). Named explicitly because raw [TextStyle]s
/// handed to button themes skip the typography defaults.
const systemFontFamily = 'CupertinoSystemText';

/// Bundled only for the "xplore" wordmark; everything else is the system font.
const wordmarkFontFamily = 'Manrope';

// Flutter does not apply San Francisco's size-specific tracking, which leaves
// text looser than native iOS. The body and label styles carry the system's
// tracking for their size; `bodyMedium` is also the default every `Text`
// inherits, so unstyled text is tightened too.
final defaultTextTheme = const TextTheme(
  headlineLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, height: 1.08, letterSpacing: -0.8),
  headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.12, letterSpacing: -0.6),
  headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.18, letterSpacing: -0.4),
  bodyLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w400, height: 1.4, letterSpacing: -0.41),
  bodyMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, height: 1.4, letterSpacing: -0.23),
  bodySmall: TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: -0.15,
    color: XploreColors.secondaryLabel,
  ),
  labelLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.3, letterSpacing: -0.41),
  labelMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3, letterSpacing: -0.23),
  labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.3, color: XploreColors.secondaryLabel),
).apply(fontFamily: systemFontFamily, bodyColor: XploreColors.white, displayColor: XploreColors.white);

const _capsule = StadiumBorder();

/// White capsule with black text: the one primary button style in the app.
final _primaryButtonStyle = ButtonStyle(
  shape: const WidgetStatePropertyAll(_capsule),
  backgroundColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.disabled) ? XploreColors.raised : XploreColors.white,
  ),
  foregroundColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.disabled) ? XploreColors.tertiaryLabel : XploreColors.background,
  ),
  overlayColor: WidgetStatePropertyAll(XploreColors.background.withValues(alpha: 0.08)),
  elevation: const WidgetStatePropertyAll(0),
  textStyle: WidgetStatePropertyAll(defaultTextTheme.labelLarge),
);

/// The app's single (dark) theme.
ThemeData getTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: const ColorScheme.dark(
    primary: XploreColors.accent,
    onPrimary: XploreColors.onAccent,
    secondary: XploreColors.accent,
    onSecondary: XploreColors.onAccent,
    // Opaque [XploreColors.accentSoft] over a card. M3 falls back to solid
    // Jade here, which turns the date range picker's in-range band (white day
    // numbers on secondaryContainer) unreadable and hides the start/end circles.
    secondaryContainer: Color(0xFF253832),
    onSecondaryContainer: XploreColors.white,
    error: XploreColors.error,
    onError: XploreColors.white,
    surface: XploreColors.card,
    onSurface: XploreColors.white,
    onSurfaceVariant: XploreColors.secondaryLabel,
    surfaceContainerHighest: XploreColors.raised,
    outline: XploreColors.separator,
    outlineVariant: XploreColors.separator,
  ),
  scaffoldBackgroundColor: XploreColors.background,
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
  fontFamily: systemFontFamily,
  textTheme: defaultTextTheme,
  dividerColor: XploreColors.separator,
  dividerTheme: const DividerThemeData(color: XploreColors.separator, thickness: 1, space: 1),
  cardTheme: CardThemeData(
    color: XploreColors.card,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg)),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(color: XploreColors.accent),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: XploreColors.raised,
    contentTextStyle: defaultTextTheme.bodyMedium,
    actionTextColor: XploreColors.accent,
    closeIconColor: XploreColors.secondaryLabel,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: _primaryButtonStyle.copyWith(minimumSize: const WidgetStatePropertyAll(Size(250, 54))),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: _primaryButtonStyle.copyWith(minimumSize: const WidgetStatePropertyAll(Size(64, 50))),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: ButtonStyle(
      shape: const WidgetStatePropertyAll(_capsule),
      foregroundColor: const WidgetStatePropertyAll(XploreColors.white),
      textStyle: WidgetStatePropertyAll(defaultTextTheme.labelMedium),
      side: const WidgetStatePropertyAll(BorderSide(color: XploreColors.separator)),
      overlayColor: WidgetStatePropertyAll(XploreColors.white.withValues(alpha: 0.08)),
      minimumSize: const WidgetStatePropertyAll(Size(132, 50)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) ? XploreColors.tertiaryLabel : XploreColors.accent,
      ),
      textStyle: WidgetStatePropertyAll(defaultTextTheme.labelMedium),
    ),
  ),
  iconTheme: const IconThemeData(color: XploreColors.white),
);
