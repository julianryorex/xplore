import 'package:flutter/widgets.dart';

/// The family name Flutter's engine registers for the platform system font on
/// Apple platforms (San Francisco). Named explicitly because raw [TextStyle]s
/// handed to button themes skip the typography defaults.
const systemFontFamily = 'CupertinoSystemText';

/// The app's type scale. Sizes are deliberately small, so hierarchy comes from
/// weight, colour and spacing rather than size. Styles carry no colour: they
/// inherit white, and callers `copyWith` a colour where the text is secondary.
abstract final class XploreText {
  /// The home hero's trip title: the one place large type is the point.
  static const display = TextStyle(
    fontFamily: systemFontFamily,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 1,
    letterSpacing: -1.2,
  );

  /// Screen and step titles ("Where to?", "What are we planning?").
  static const title = TextStyle(
    fontFamily: systemFontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.08,
    letterSpacing: -0.8,
  );

  /// Section headings inside a screen ("Itinerary", "Shared gallery").
  static const heading = TextStyle(
    fontFamily: systemFontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: -0.3,
  );

  /// Headline numbers in summary cards ("0 of 3").
  static const stat = TextStyle(
    fontFamily: systemFontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.3,
  );

  /// Row titles, menu items and button labels.
  static const bodyStrong = TextStyle(
    fontFamily: systemFontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: -0.2,
  );

  /// Running text and input text.
  static const body = TextStyle(
    fontFamily: systemFontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: -0.2,
  );

  /// Supporting lines under a title; usually in the secondary label colour.
  static const footnote = TextStyle(
    fontFamily: systemFontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.35,
    letterSpacing: -0.1,
  );

  /// Emphasised small text: accent links, chips and stat captions.
  static const footnoteStrong = TextStyle(
    fontFamily: systemFontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.1,
  );

  /// The smallest running text: timestamps and tab labels.
  static const caption = TextStyle(
    fontFamily: systemFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  /// Uppercase tracked labels ("STEP 1 OF 4", "DAY").
  static const overline = TextStyle(
    fontFamily: systemFontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 1.2,
  );
}
