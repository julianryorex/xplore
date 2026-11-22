import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/features/auth/bloc/auth_cubit.dart';
import 'package:xplore/features/home/models/trip_overview.dart';
import 'package:xplore/features/onboarding/bloc/onboarding_cubit.dart';
import 'package:xplore/features/onboarding/presentation/widgets/onboarding_buttons.dart';
import 'package:xplore/features/onboarding/presentation/widgets/onboarding_labels.dart';
import 'package:xplore/features/onboarding/presentation/widgets/onboarding_map_art.dart';
import 'package:xplore/features/onboarding/presentation/widgets/onboarding_rise_in.dart';
import 'package:xplore/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:xplore/features/trip/models/trip_window.dart';

/// The organizer's send-off: a map hero with their pin, a countdown to the trip
/// and what is ready, then "Open {place}" to finish onboarding.
class AllSetStep extends StatefulWidget {
  const AllSetStep({this.clock, super.key});

  /// The current time, defaulting to [DateTime.now]; tests pin it to fix the countdown.
  final DateTime Function()? clock;

  @override
  State<AllSetStep> createState() => _AllSetStepState();
}

class _AllSetStepState extends State<AllSetStep> with TickerProviderStateMixin {
  static const _entranceSeconds = 1.5;

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  late final Animation<double> _pinDrop = _slice(0, 0.6);
  late final Animation<double> _overlineIn = _slice(0.2, 0.5);
  late final Animation<double> _titleIn = _slice(0.25, 0.5);
  late final Animation<double> _countdownIn = _slice(0.4, 0.5);
  late final Animation<double> _statusIn = _slice(0.5, 0.5);
  late final List<Animation<double>> _ticksIn = [_slice(0.8, 0.3), _slice(1, 0.3), _slice(1.2, 0.3)];

  bool _motionStarted = false;

  /// The part of the entrance from [start] for [length] seconds, eased out.
  Animation<double> _slice(double start, double length) => _entrance.drive(
    CurveTween(curve: Interval(start / _entranceSeconds, (start + length) / _entranceSeconds, curve: Curves.easeOut)),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Done here rather than in initState because it needs MediaQuery.
    if (_motionStarted) {
      return;
    }
    _motionStarted = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();
    final state = context.watch<OnboardingCubit>().state;
    final firstName = context.select((AuthCubit auth) => onboardingFirstName(auth.state));
    final now = (widget.clock ?? DateTime.now)();
    final window = tripWindowOn(now, start: state.startDate, end: state.endDate);
    final placeName = state.destination?.name ?? state.createdTrip?.title;
    final heroHeight = _AllSetHero.heightFor(MediaQuery.sizeOf(context));

    return Scaffold(
      backgroundColor: XploreColors.background,
      body: Stack(
        children: [
          _AllSetHero(
            height: heroHeight,
            pinDrop: _pinDrop,
            pulse: MediaQuery.disableAnimationsOf(context) ? null : _pulse,
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: paddingUnit * 2),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: onboardingGutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      // The hero stays put, so the content must not rubber-band over it.
                      physics: const ClampingScrollPhysics(),
                      padding: EdgeInsets.only(top: heroHeight * _AllSetHero.contentStart, bottom: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OnboardingRiseIn(
                            animation: _overlineIn,
                            child: Text('ALL SET', style: XploreText.overline.copyWith(color: XploreColors.accent)),
                          ),
                          const SizedBox(height: 10),
                          OnboardingRiseIn(
                            animation: _titleIn,
                            child: Semantics(
                              header: true,
                              child: Text(_title(placeName, firstName), style: XploreText.display),
                            ),
                          ),
                          const SizedBox(height: 22),
                          OnboardingRiseIn(
                            animation: _countdownIn,
                            child: _CountdownCard(window: window, state: state, now: now),
                          ),
                          const SizedBox(height: 14),
                          OnboardingRiseIn(
                            animation: _statusIn,
                            child: _StatusCard(state: state, window: window, ticksIn: _ticksIn),
                          ),
                        ],
                      ),
                    ),
                  ),
                  OnboardingPrimaryButton(
                    label: placeName == null ? 'Open your trip' : 'Open $placeName',
                    onPressed: cubit.next,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _title(String? placeName, String? firstName) {
    final where = placeName == null ? 'See you there' : 'See you in $placeName';
    return firstName == null ? '$where.' : '$where, $firstName.';
  }
}

/// The drawn map bleeding off the top and sides, fading into the page, with the
/// organizer's Jade pin dropping onto it inside a pulsing halo.
class _AllSetHero extends StatelessWidget {
  const _AllSetHero({required this.height, required this.pinDrop, required this.pulse});

  final double height;
  final Animation<double> pinDrop;

  /// Drives the repeating halo; null leaves it out, for reduced motion.
  final Animation<double>? pulse;

  /// The pin's centre, as a fraction of the hero's height.
  static const _pinCentre = 142 / 330;

  /// Where the page content starts, as a fraction of the hero's height; it overlaps the fade.
  static const contentStart = 236 / 330;

  /// The fade to black covers the hero below this fraction of its height.
  static const _fadeStart = 180 / 330;

  static const _haloSize = 120.0;
  static const _pinSize = 36.0;

  /// The design's 330pt hero on a 844pt screen, scaled down on shorter ones.
  static double heightFor(Size screen) => (screen.height * 330 / 844).clamp(220.0, 330.0);

  static final _drop = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: -40, end: 4), weight: 70),
    TweenSequenceItem(tween: Tween(begin: 4, end: 0), weight: 30),
  ]);

  static final _dropOpacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 70),
    TweenSequenceItem(tween: ConstantTween(1), weight: 30),
  ]);

  @override
  Widget build(BuildContext context) {
    final pinY = height * _pinCentre;
    final pulse = this.pulse;

    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            OnboardingMapArt(height: height, borderRadius: 0, highlight: Alignment(0, _pinCentre * 2 - 1)),
            Positioned(
              left: 0,
              right: 0,
              top: height * _fadeStart,
              bottom: 0,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), XploreColors.background],
                  ),
                ),
              ),
            ),
            if (pulse != null)
              Positioned(
                left: 0,
                right: 0,
                top: pinY - _haloSize / 2,
                child: Center(
                  child: _PulsingHalo(animation: pulse, size: _haloSize),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              top: pinY - _pinSize / 2,
              child: Center(
                child: AnimatedBuilder(
                  animation: pinDrop,
                  builder: (context, child) => Opacity(
                    opacity: _dropOpacity.transform(pinDrop.value),
                    child: Transform.translate(offset: Offset(0, _drop.transform(pinDrop.value)), child: child),
                  ),
                  child: const _Pin(size: _pinSize),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingHalo extends StatelessWidget {
  const _PulsingHalo({required this.animation, required this.size});

  final Animation<double> animation;
  final double size;

  static final _scale = Tween<double>(begin: 0.6, end: 1.5).chain(CurveTween(curve: Curves.easeOut));
  static final _opacity = Tween<double>(begin: 0.9, end: 0).chain(CurveTween(curve: Curves.easeOut));

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation.drive(_opacity),
      child: ScaleTransition(
        scale: animation.drive(_scale),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: XploreColors.accent.withValues(alpha: 0.28), shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: XploreColors.accent,
        shape: BoxShape.circle,
        border: Border.all(color: XploreColors.background, width: 3),
      ),
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(color: XploreColors.onAccent, shape: BoxShape.circle),
      ),
    );
  }
}

/// How long until the trip: a big Jade day count when it is ahead, otherwise
/// a line saying it is under way or still needs dates.
class _CountdownCard extends StatelessWidget {
  const _CountdownCard({required this.window, required this.state, required this.now});

  final TripWindow window;
  final OnboardingState state;
  final DateTime now;

  // Bespoke size: the countdown is the card's one figure, between a title and the display type.
  static const _countStyle = TextStyle(
    fontFamily: systemFontFamily,
    fontSize: 44,
    fontWeight: FontWeight.w700,
    height: 1,
    letterSpacing: -1.6,
    color: XploreColors.accent,
  );

  @override
  Widget build(BuildContext context) {
    final start = state.startDate;
    final end = state.endDate;
    final dateLine = start == null || end == null
        ? 'Pick your dates when you’re ready.'
        : '${tripDatesLabel(start, end)} · ${tripLengthLabel(start, end)}';

    final days = start == null ? 0 : daysUntil(start, now: now);
    final (Widget leading, String headline) = switch (window) {
      TripWindow.upcoming => (Text('$days', style: _countStyle), days == 1 ? 'day to go' : 'days to go'),
      TripWindow.underWay => (
        const Icon(Icons.near_me_rounded, size: 32, color: XploreColors.accent),
        'Your trip is under way',
      ),
      TripWindow.ended => (
        const Icon(Icons.event_available_rounded, size: 32, color: XploreColors.secondaryLabel),
        'These dates have passed',
      ),
      TripWindow.undated => (
        const Icon(Icons.calendar_today_rounded, size: 32, color: XploreColors.secondaryLabel),
        'No dates yet',
      ),
    };

    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(color: XploreColors.card, borderRadius: BorderRadius.circular(radiusLg)),
        child: Row(
          spacing: 16,
          children: [
            leading,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 3,
                children: [
                  Text(headline, style: XploreText.bodyStrong.copyWith(fontWeight: FontWeight.w600)),
                  Text(dateLine, style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What is ready: the trip, the invite and location sharing, one row each.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.state, required this.window, required this.ticksIn});

  final OnboardingState state;
  final TripWindow window;

  /// One pop-in animation per row's icon, in order.
  final List<Animation<double>> ticksIn;

  @override
  Widget build(BuildContext context) {
    final rows = [_tripRow(), _inviteRow(), _locationRow()];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(color: XploreColors.card, borderRadius: BorderRadius.circular(radiusLg)),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0) const _RowSeparator(),
            _StatusRow(icon: rows[index].$1, label: rows[index].$2, popIn: ticksIn[index]),
          ],
        ],
      ),
    );
  }

  (Widget, String) _tripRow() => switch (state.tripSetup) {
    TripSetupStatus.created => (const _Tick(), 'Trip saved'),
    TripSetupStatus.idle || TripSetupStatus.creating => (const _Spinner(), 'Saving your trip…'),
    TripSetupStatus.failed => (
      const _MutedIcon(Icons.error_outline_rounded, color: XploreColors.error),
      'Couldn’t save your trip',
    ),
  };

  (Widget, String) _inviteRow() => state.inviteShared
      ? (const _Tick(), 'Invite link shared')
      : (const _MutedIcon(Icons.person_add_alt_outlined), 'Invite your group any time');

  // Location is only shared while a trip runs, so nothing here may suggest
  // the user is on the map before it starts.
  (Widget, String) _locationRow() => switch (window) {
    TripWindow.underWay => (const _Tick(), 'Location sharing is on for this trip'),
    TripWindow.upcoming => (
      const _MutedIcon(Icons.schedule_rounded),
      'Location sharing starts ${formatMonthDay(state.startDate!)}',
    ),
    TripWindow.ended => (const _MutedIcon(Icons.location_off_outlined), 'Location sharing is off for this trip'),
    TripWindow.undated => (const _MutedIcon(Icons.location_off_outlined), 'Location stays off until you set dates'),
  };
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.icon, required this.label, required this.popIn});

  final Widget icon;
  final String label;
  final Animation<double> popIn;

  static const _minHeight = 46.0;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _minHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          spacing: paddingUnit,
          children: [
            ExcludeSemantics(
              child: ScaleTransition(
                scale: popIn.drive(Tween(begin: 0.4, end: 1)),
                child: FadeTransition(
                  opacity: popIn,
                  child: SizedBox.square(
                    dimension: _Tick.size,
                    child: Center(child: icon),
                  ),
                ),
              ),
            ),
            Expanded(child: Text(label, style: XploreText.body)),
          ],
        ),
      ),
    );
  }
}

class _RowSeparator extends StatelessWidget {
  const _RowSeparator();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.only(left: _Tick.size + paddingUnit),
      color: XploreColors.separator,
    );
  }
}

class _Tick extends StatelessWidget {
  const _Tick();

  static const size = 24.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: XploreColors.accent, shape: BoxShape.circle),
      child: const Icon(Icons.check_rounded, size: 16, color: XploreColors.onAccent),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 16,
      child: CircularProgressIndicator(strokeWidth: 2, color: XploreColors.accent),
    );
  }
}

class _MutedIcon extends StatelessWidget {
  const _MutedIcon(this.icon, {this.color = XploreColors.secondaryLabel});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Icon(icon, size: 20, color: color);
}
