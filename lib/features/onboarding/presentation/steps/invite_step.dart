import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/features/auth/bloc/auth_cubit.dart';
import 'package:xplore/features/onboarding/bloc/onboarding_cubit.dart';
import 'package:xplore/features/onboarding/presentation/widgets/dashed_circle.dart';
import 'package:xplore/features/onboarding/presentation/widgets/onboarding_buttons.dart';
import 'package:xplore/features/onboarding/presentation/widgets/onboarding_labels.dart';
import 'package:xplore/features/onboarding/presentation/widgets/onboarding_map_art.dart';
import 'package:xplore/features/onboarding/presentation/widgets/onboarding_rise_in.dart';
import 'package:xplore/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:xplore/features/trip/models/trip_model.dart';
import 'package:xplore/features/trip/presentation/trip_invite_sharer.dart';

/// Timings from the design, in seconds, so they read the same as the mockup.
abstract final class _Motion {
  /// Overline, title, pass and caption arriving.
  static const entrance = 1.0;

  /// The stamp, once the trip is saved.
  static const celebration = 1.4;

  /// Long enough for the last piece of confetti to fall off the screen.
  static const confetti = 3.6;
  static const stampStart = 0.75;
  static const stampLength = 0.45;

  /// The stamp is fully opaque and at its smallest here, which is when it "hits".
  static const stampImpact = stampStart + stampLength * 0.7;

  static Duration duration(double seconds) => Duration(milliseconds: (seconds * 1000).round());

  /// The part of [parent]'s timeline from [start] for [length] seconds, out of [total], eased by [curve].
  static Animation<double> slice(
    AnimationController parent, {
    required double start,
    required double length,
    required double total,
    Curve curve = Curves.easeOut,
  }) {
    return parent.drive(
      CurveTween(curve: Interval(start / total, math.min((start + length) / total, 1), curve: curve)),
    );
  }
}

/// Organizer step: celebrates the trip that was saved in the background after
/// sign-in as a boarding pass, and asks the user to share an invite link to it.
/// Shows that save's progress, and a retry through [onRetryTripSetup] when it failed.
class InviteStep extends StatefulWidget {
  const InviteStep({required this.onRetryTripSetup, this.shareInvite = shareTripInvite, super.key});

  /// Saves the organizer's trip again after a failed attempt.
  final Future<void> Function() onRetryTripSetup;

  /// Opens the share sheet for the trip's invite link and reports whether the
  /// link was shared. Replaceable so tests need no platform share sheet.
  final Future<bool> Function(BuildContext context, TripModel trip) shareInvite;

  @override
  State<InviteStep> createState() => _InviteStepState();
}

class _InviteStepState extends State<InviteStep> with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: _Motion.duration(_Motion.entrance),
  );
  late final AnimationController _celebration = AnimationController(
    vsync: this,
    duration: _Motion.duration(_Motion.celebration),
  )..addListener(_onCelebrationTick);
  late final AnimationController _confetti = AnimationController(
    vsync: this,
    duration: _Motion.duration(_Motion.confetti),
  );

  late final Animation<double> _headingIn = _Motion.slice(_entrance, start: 0, length: 0.5, total: _Motion.entrance);
  late final Animation<double> _passIn = _Motion.slice(
    _entrance,
    start: 0.15,
    length: 0.6,
    total: _Motion.entrance,
    curve: const Cubic(0.2, 0.9, 0.3, 1.1),
  );
  late final Animation<double> _captionIn = _Motion.slice(_entrance, start: 0.5, length: 0.5, total: _Motion.entrance);
  late final Animation<double> _stampIn = _Motion.slice(
    _celebration,
    start: _Motion.stampStart,
    length: _Motion.stampLength,
    total: _Motion.celebration,
  );

  bool _motionStarted = false;
  bool _celebrationStarted = false;
  bool _stampLanded = false;
  bool _sharing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Done here rather than in initState because it needs MediaQuery.
    if (_motionStarted) {
      return;
    }
    _motionStarted = true;
    if (_reduceMotion) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
    }
    if (context.read<OnboardingCubit>().state.tripSetup == TripSetupStatus.created) {
      _celebrate();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _celebration.dispose();
    _confetti.dispose();
    super.dispose();
  }

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  /// Plays the confetti and stamp, once, the first time the trip shows as saved.
  void _celebrate() {
    if (_celebrationStarted) {
      return;
    }
    _celebrationStarted = true;
    if (_reduceMotion) {
      // The stamp shows in place; confetti is motion only, so it is left out.
      _celebration.value = 1;
    } else {
      _celebration.forward();
      _confetti.forward();
    }
  }

  void _onCelebrationTick() {
    if (!_stampLanded && _celebration.value >= _Motion.stampImpact / _Motion.celebration) {
      _stampLanded = true;
      unawaited(HapticFeedback.mediumImpact());
    }
  }

  Future<void> _share(OnboardingState state) async {
    final cubit = context.read<OnboardingCubit>();
    setState(() => _sharing = true);
    var shared = false;
    try {
      shared = await widget.shareInvite(context, state.createdTrip!);
    } finally {
      if (mounted) {
        setState(() => _sharing = false);
      }
    }
    // Backing out of the share sheet leaves the user here to try again or skip.
    if (shared) {
      cubit
        ..inviteShared()
        ..next();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();
    final state = context.watch<OnboardingCubit>().state;
    final organizer = context.select((AuthCubit auth) => onboardingFirstName(auth.state));
    final failed = state.tripSetup == TripSetupStatus.failed;
    final saved = state.tripSetup == TripSetupStatus.created;
    final saving = !failed && !saved;
    final placeName = state.destination?.name ?? state.createdTrip?.title ?? 'Your trip';

    return BlocListener<OnboardingCubit, OnboardingState>(
      listenWhen: (previous, current) =>
          previous.tripSetup != TripSetupStatus.created && current.tripSetup == TripSetupStatus.created,
      listener: (_, _) => _celebrate(),
      child: OnboardingStepScaffold(
        skippable: true,
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 6,
          children: [
            if (failed)
              OnboardingPrimaryButton(label: 'Try again', onPressed: widget.onRetryTripSetup)
            else
              OnboardingPrimaryButton(
                label: 'Invite your group',
                icon: Icons.ios_share_rounded,
                loading: saving || _sharing,
                onPressed: () => _share(state),
              ),
            OnboardingTextButton(label: 'I’ll do this later', onPressed: _sharing ? null : cubit.skip),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                OnboardingRiseIn(
                  animation: _headingIn,
                  distance: 0,
                  child: failed ? const _SaveFailedLine() : _Overline(saved: saved),
                ),
                const SizedBox(height: 10),
                OnboardingRiseIn(
                  animation: _headingIn,
                  distance: 36,
                  child: Semantics(header: true, child: Text('$placeName is happening.', style: XploreText.display)),
                ),
                const SizedBox(height: 26),
                OnboardingRiseIn(
                  animation: _passIn,
                  distance: 36,
                  child: _BoardingPass(
                    placeName: placeName,
                    country: state.destination?.country,
                    dates: tripDatesLabel(state.startDate, state.endDate),
                    length: state.hasDates ? tripLengthLabel(state.startDate!, state.endDate!) : null,
                    organizer: organizer,
                    stamp: saved ? _stampIn : null,
                  ),
                ),
                const SizedBox(height: 20),
                OnboardingRiseIn(
                  animation: _captionIn,
                  distance: 0,
                  child: Text(
                    'A trip is better with company. Send one link and your friends fill the empty seats.',
                    style: XploreText.body.copyWith(color: XploreColors.secondaryLabel),
                  ),
                ),
              ],
            ),
            // On top of the content and out to the screen's edges, so the pieces
            // fall across the pass before leaving the screen.
            Positioned(
              left: -onboardingGutter,
              right: -onboardingGutter,
              top: -_ConfettiPainter.overhang,
              bottom: 0,
              child: IgnorePointer(
                child: CustomPaint(painter: _ConfettiPainter(progress: _confetti)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Overline extends StatelessWidget {
  const _Overline({required this.saved});

  final bool saved;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Text(
        saved ? 'YOUR TRIP IS LIVE' : 'SAVING YOUR TRIP…',
        style: XploreText.overline.copyWith(color: XploreColors.accent),
      ),
    );
  }
}

class _SaveFailedLine extends StatelessWidget {
  const _SaveFailedLine();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.error_outline_rounded, size: 16, color: XploreColors.error),
          ),
          Expanded(
            child: Text(
              'Couldn’t save your trip. Check your connection and try again.',
              style: XploreText.footnote.copyWith(color: XploreColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

/// The trip as a boarding pass: destination, dates and organizer above a
/// perforation, and the group's seats on the stub below it.
class _BoardingPass extends StatelessWidget {
  const _BoardingPass({
    required this.placeName,
    required this.country,
    required this.dates,
    required this.length,
    required this.organizer,
    required this.stamp,
  });

  final String placeName;
  final String? country;

  /// Null for a trip without exact dates.
  final String? dates;
  final String? length;
  final String? organizer;

  /// Drives the "SAVED" stamp landing; null hides the stamp.
  final Animation<double>? stamp;

  // Bespoke size: the pass's destination is its headline, between the display title and a row title.
  static const _destinationStyle = TextStyle(
    fontFamily: systemFontFamily,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    height: 1.05,
    letterSpacing: -1,
  );

  @override
  Widget build(BuildContext context) {
    final stamp = this.stamp;
    return Container(
      decoration: BoxDecoration(color: XploreColors.card, borderRadius: BorderRadius.circular(radiusLg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 18,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 4,
                      children: [
                        const _FieldLabel('DESTINATION'),
                        Text(placeName, style: _destinationStyle),
                        if (country != null)
                          Text(country!, style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel)),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: paddingUnit,
                      children: [
                        Expanded(
                          child: _Field(label: 'DATES', value: dates ?? 'Flexible'),
                        ),
                        if (length != null)
                          Expanded(
                            child: _Field(label: 'LENGTH', value: length!),
                          ),
                        Expanded(
                          child: _Field(label: 'ORGANIZER', value: organizer ?? 'You'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (stamp != null) Positioned(right: 18, top: 22, child: _SavedStamp(animation: stamp)),
            ],
          ),
          const _Perforation(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Row(
              spacing: paddingUnit,
              children: [
                const Expanded(
                  child: _Field(label: 'YOUR GROUP', value: 'Just you so far'),
                ),
                _MemberSlots(name: organizer),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: XploreText.overline.copyWith(color: XploreColors.secondaryLabel));
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 3,
        children: [
          _FieldLabel(label),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: XploreText.bodyStrong.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// A tilted Jade "SAVED" stamp that lands from large to its resting size.
class _SavedStamp extends StatelessWidget {
  const _SavedStamp({required this.animation});

  final Animation<double> animation;

  static const _tilt = -12 * math.pi / 180;

  static final _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 2.2, end: 0.92), weight: 70),
    TweenSequenceItem(tween: Tween(begin: 0.92, end: 1), weight: 30),
  ]);

  static final _opacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 70),
    TweenSequenceItem(tween: ConstantTween(1), weight: 30),
  ]);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Saved',
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, child) => Opacity(
            opacity: _opacity.transform(animation.value),
            child: Transform.rotate(
              angle: _tilt,
              child: Transform.scale(scale: _scale.transform(animation.value), child: child),
            ),
          ),
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: XploreColors.accent, width: 2),
            ),
            child: Text(
              'SAVED',
              style: XploreText.overline.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
                color: XploreColors.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The tear line between the pass and its stub: a notch cut into each side of
/// the card with a dashed line between them.
class _Perforation extends StatelessWidget {
  const _Perforation();

  static const _notch = 24.0;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: _notch,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // The notches are page-coloured circles centred on the card's edges.
            const Positioned(
              left: -_notch / 2,
              top: 0,
              child: _Notch(size: _notch),
            ),
            const Positioned(
              right: -_notch / 2,
              top: 0,
              child: _Notch(size: _notch),
            ),
            Positioned.fill(left: 22, right: 22, child: CustomPaint(painter: _DashedLinePainter())),
          ],
        ),
      ),
    );
  }
}

class _Notch extends StatelessWidget {
  const _Notch({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: XploreColors.background, shape: BoxShape.circle),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  static const _dash = 6.0;
  static const _gap = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = XploreColors.separator
      ..strokeWidth = 2;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += _dash + _gap) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + _dash, size.width), y), paint);
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) => false;
}

/// The user's avatar overlapping three dashed seats for the friends to come.
class _MemberSlots extends StatelessWidget {
  const _MemberSlots({required this.name});

  /// The user's first name, or null to show a generic person icon.
  final String? name;

  static const _size = 40.0;
  static const _overlap = 8.0;
  static const _emptySlots = 3;

  @override
  Widget build(BuildContext context) {
    const step = _size - _overlap;
    return SizedBox(
      width: _size + step * _emptySlots,
      height: _size,
      child: Stack(
        children: [
          Semantics(
            label: 'You',
            child: ExcludeSemantics(
              child: _OwnAvatar(name: name, size: _size),
            ),
          ),
          for (var slot = 1; slot <= _emptySlots; slot++)
            Positioned(
              left: step * slot,
              child: _EmptySlot(size: _size, showPlus: slot == _emptySlots),
            ),
        ],
      ),
    );
  }
}

class _OwnAvatar extends StatelessWidget {
  const _OwnAvatar({required this.name, required this.size});

  final String? name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final name = this.name;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: XploreColors.raised,
        shape: BoxShape.circle,
        border: Border.all(color: XploreColors.accent, width: 2),
      ),
      child: name == null
          ? const Icon(Icons.person_rounded, size: 20, color: XploreColors.white)
          : Text(
              name.characters.first.toUpperCase(),
              style: XploreText.bodyStrong.copyWith(fontWeight: FontWeight.w600),
            ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.size, required this.showPlus});

  final double size;
  final bool showPlus;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: DashedCircle(
        size: size,
        color: XploreColors.tertiaryLabel,
        fillColor: XploreColors.card,
        strokeWidth: 1.5,
        child: showPlus ? const Icon(Icons.add_rounded, size: 16, color: XploreColors.secondaryLabel) : null,
      ),
    );
  }
}

/// One piece of confetti and how it falls.
class _ConfettiPiece {
  const _ConfettiPiece({
    required this.x,
    required this.width,
    required this.height,
    required this.color,
    required this.delay,
    required this.fallSeconds,
    required this.sway,
    required this.turns,
  });

  /// Horizontal start, as a fraction of the screen's width.
  final double x;
  final double width;
  final double height;
  final Color color;

  /// Seconds after the celebration starts before this piece appears.
  final double delay;

  /// Seconds it takes to fall from the top edge to below the bottom edge.
  final double fallSeconds;

  /// How far it drifts sideways as it falls, in points.
  final double sway;

  /// Full rotations over the fall.
  final double turns;

  /// Round dots are as wide as they are tall; the rest are slips.
  bool get isDot => width == height;
}

/// Confetti that falls from the top of the step, turning and drifting, until
/// every piece has left the screen. Nothing is left behind once it finishes.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress}) : super(repaint: progress);

  final Animation<double> progress;

  /// How far above the step's content the pieces start, so they enter from
  /// behind the top bar instead of appearing mid-air.
  static const overhang = 122.0;
  static const _pieceCount = 28;
  static const _colors = [
    XploreColors.accent,
    OnboardingAvatarColors.sand,
    OnboardingAvatarColors.blue,
    OnboardingAvatarColors.coral,
  ];

  /// Seeded so every run of the celebration looks the same.
  static final List<_ConfettiPiece> _pieces = _buildPieces(math.Random(7));

  static List<_ConfettiPiece> _buildPieces(math.Random random) {
    return List.generate(_pieceCount, (index) {
      final isDot = random.nextInt(3) == 0;
      final width = 6 + random.nextDouble() * 4;
      return _ConfettiPiece(
        x: random.nextDouble(),
        width: width,
        height: isDot ? width : width + 5,
        color: _colors[index % _colors.length],
        delay: random.nextDouble() * 0.9,
        fallSeconds: 1.8 + random.nextDouble() * 0.9,
        sway: 10 + random.nextDouble() * 22,
        turns: 0.8 + random.nextDouble() * 1.6,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final elapsed = progress.value * _Motion.confetti;
    for (final piece in _pieces) {
      final t = (elapsed - piece.delay) / piece.fallSeconds;
      if (t <= 0 || t >= 1) {
        continue;
      }
      // Starts slow and speeds up, like something light being pulled down.
      final fall = t * (0.55 + 0.45 * t);
      final centre = Offset(
        piece.x * size.width + piece.sway * math.sin(t * 3 * math.pi),
        -piece.height + (size.height + 2 * piece.height) * fall,
      );
      final rect = Rect.fromCenter(center: Offset.zero, width: piece.width, height: piece.height);
      canvas
        ..save()
        ..translate(centre.dx, centre.dy)
        ..rotate(piece.turns * 2 * math.pi * t)
        ..drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(piece.isDot ? piece.width / 2 : 2)),
          Paint()..color = piece.color,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => oldDelegate.progress != progress;
}
