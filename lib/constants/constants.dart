import 'dart:ui';

/// The dark-only, iOS-style palette: true black behind opaque grey cards, with
/// Jade as the single accent.
class XploreColors {
  static const background = Color(0xFF000000);
  static const card = Color(0xFF1C1C1E);
  static const raised = Color(0xFF2C2C2E);
  static const separator = Color(0xFF38383A);

  static const white = Color(0xFFFFFFFF);
  static const secondaryLabel = Color(0xFFA1A1A8);

  /// Disabled and decorative use only: it is below WCAG AA contrast as text.
  static const tertiaryLabel = Color(0xFF5A5A60);

  /// Unselected controls sitting on glass or cards (tab labels, input icons).
  static const inactiveControl = Color(0xFFD1D1D6);

  static const accent = Color(0xFF4FBF93);

  /// The accent as a tinted fill (about 17% opacity) behind accent-coloured content.
  static const accentSoft = Color(0x2B4FBF93);

  /// Text and icons placed on a solid accent fill.
  static const onAccent = Color(0xFF06201A);

  static const success = Color(0xFF00C853);
  static const error = Color(0xFFFF453A);
  static const warning = Color(0xFFFFC400);
  static const info = Color(0xFF00B0FF);

  // Floating chrome (tab bar, menus): a translucent raised fill over a blur.
  static const glassChrome = Color(0xC72C2C2E);
  static const glassChromeStrong = Color(0xEB2C2C2E);
  static const glassChromeBorder = Color(0x1FFFFFFF);

  // Names from the previous teal palette, repointed at the new tokens so the
  // screens that have not been redesigned yet inherit the new look. Prefer the
  // tokens above in new code.
  static const alternate = accent;
  static const primaryBg = background;
  static const darkBg = card;
  static const black = background;
  static const surface = card;
  static const surfaceElevated = raised;
  static const mutedText = secondaryLabel;
  static const subtleText = Color(0x75FFFFFF);
  static const divider = separator;
  static const glassFill = Color(0x1AFFFFFF);
  static const glassFillStrong = Color(0x29FFFFFF);
  static const glassBorder = Color(0x24FFFFFF);
  static const glassHighlight = Color(0x61FFFFFF);
}

const paddingUnit = 12.0;
const radiusSm = 12.0;
const radiusMd = 16.0;
const radiusLg = 22.0;
const radiusXl = 32.0;
const headerIconButtonSize = 44.0;
const headerIconSize = 22.0;

/// Smallest comfortable tap target, per the iOS Human Interface Guidelines.
const minTouchTarget = 44.0;

/// Vertical space scrolling content must leave clear above the bottom safe
/// area so it is not hidden behind the floating tab bar.
const navBarHeight = 84.0;

// Default backdrop blur strength for glass surfaces (logical px).
const glassBlur = 18.0;

// Identifier for the static demo itinerary/location fixtures. Used ONLY by the
// test-only `@visibleForTesting` demo loaders (`LocationCubit.loadDemoLocations`
// and `ItineraryCubit.loadDemoItinerary`) — no runtime path falls back to this.
const itineraryId = 'ph4kd';
