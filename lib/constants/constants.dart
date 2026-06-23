import 'package:xplore/constants/extensions.dart';

class XploreColors {
  static final primary = '23272A'.toColor();
  static final secondary = '1F8565'.toColor();
  static final tertiary = '282D30'.toColor();
  static final alternate = '0EA78D'.toColor();

  // static final accent1 = '265A3A'.toColor();
  // static final accent2 = '08120E'.toColor();
  // static final accent3 = 'CEE5E0'.toColor();

  static final primaryText = '2D2936'.toColor();
  static final secondaryText = '2BA0A0'.toColor();
  static final primaryBg = '1E1A22'.toColor();
  static final secondaryBg = '1A7474'.toColor();

  static final success = '00C853'.toColor();
  static final error = 'D50000'.toColor();
  static final warning = 'FFC400'.toColor();
  static final info = '00B0FF'.toColor();

  static final white = 'FFFFFF'.toColor();
  static final lineColor = 'DBE2E7'.toColor();
  static final darkBg = '1A1F24'.toColor();
  static final black = '131619'.toColor();
  static final surface = '211D28'.toColor();
  static final surfaceElevated = '29242F'.toColor();
  static final mutedText = white.withValues(alpha: 0.68);
  static final subtleText = white.withValues(alpha: 0.46);
  static final divider = white.withValues(alpha: 0.08);

  // Liquid-glass material tokens: a translucent fill, a hairline "rim" border,
  // and a bright specular edge used for the top highlight.
  static final glassFill = white.withValues(alpha: 0.10);
  static final glassFillStrong = white.withValues(alpha: 0.16);
  static final glassBorder = white.withValues(alpha: 0.14);
  static final glassHighlight = white.withValues(alpha: 0.38);
}

const paddingUnit = 12.0;
const radiusSm = 12.0;
const radiusMd = 16.0;
const radiusLg = 24.0;
const radiusXl = 32.0;
const headerIconButtonSize = 48.0;
const headerIconSize = 24.0;
const navBarHeight = 84.0;

// Default backdrop blur strength for glass surfaces (logical px).
const glassBlur = 18.0;

// TODO(FEAT-002): replace with the active trip id from TripCubit. Until the
// trip entity lands this placeholder scopes the demo itinerary / location /
// gallery data.
const itineraryId = 'ph4kd';
