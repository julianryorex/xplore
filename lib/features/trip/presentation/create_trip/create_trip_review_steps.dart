import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/core/glass.dart';
import 'package:xplore/features/auth/services/auth_service.dart';
import 'package:xplore/features/trip/bloc/trip_creation_cubit.dart';
import 'package:xplore/features/trip/bloc/trip_creation_state.dart';
import 'package:xplore/features/trip/services/trip_service.dart';

/// Bucket 5 — Generate + review. Phase 1 produces a deterministic day skeleton
/// and the review is read-only (see the days and confirm).
class GenerateReviewStep extends StatelessWidget {
  const GenerateReviewStep({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TripCreationCubit, TripCreationState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ReviewHeader(state: state),
            const SizedBox(height: paddingUnit * 1.5),
            switch (state.phase) {
              TripCreationPhase.generating => const _GeneratingPlaceholder(),
              TripCreationPhase.generated ||
              TripCreationPhase.submitting ||
              TripCreationPhase.submitted => _ItinerarySkeletonList(state: state),
              _ => _BeforeGenerate(state: state),
            },
          ],
        );
      },
    );
  }
}

class _ReviewHeader extends StatelessWidget {
  const _ReviewHeader({required this.state});

  final TripCreationState state;

  @override
  Widget build(BuildContext context) {
    final generated = state.phase == TripCreationPhase.generated;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('STEP 5', style: context.pText.labelSmall?.copyWith(color: XploreColors.alternate, letterSpacing: 1.4)),
        const SizedBox(height: paddingUnit * 0.5),
        Text(
          generated ? 'Here\u2019s your plan' : 'Build your itinerary',
          style: context.pText.headlineMedium?.copyWith(letterSpacing: -0.5, height: 1.05),
        ),
        const SizedBox(height: paddingUnit * 0.5),
        Text(
          generated
              ? 'A day-by-day starting point for ${state.draft.destination}. You can refine it once the trip is created.'
              : 'We\u2019ll turn your choices into a day-by-day skeleton you can build on.',
          style: context.pText.bodyMedium?.copyWith(color: XploreColors.mutedText),
        ),
      ],
    );
  }
}

class _BeforeGenerate extends StatelessWidget {
  const _BeforeGenerate({required this.state});

  final TripCreationState state;

  @override
  Widget build(BuildContext context) {
    final draft = state.draft;
    final interests = draft.interests.isEmpty ? 'A bit of everything' : draft.interests.map((i) => i.label).join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SummaryRow(icon: Icons.place_rounded, label: 'Destination', value: draft.destination),
              const _SummaryDivider(),
              _SummaryRow(
                icon: Icons.event_rounded,
                label: 'Length',
                value: '${draft.durationDays} ${draft.durationDays == 1 ? 'day' : 'days'}',
              ),
              const _SummaryDivider(),
              _SummaryRow(icon: Icons.groups_rounded, label: 'Travelling', value: draft.groupKind.label),
              const _SummaryDivider(),
              _SummaryRow(icon: Icons.interests_rounded, label: 'Vibe', value: interests),
              const _SummaryDivider(),
              _SummaryRow(
                icon: Icons.speed_rounded,
                label: 'Pace & budget',
                value: '${draft.pace.label} · ${draft.budget.label}',
              ),
            ],
          ),
        ),
        if (state.phase == TripCreationPhase.error && state.errorMessage != null) ...[
          const SizedBox(height: paddingUnit),
          Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 18, color: XploreColors.error),
              const SizedBox(width: paddingUnit * 0.5),
              Expanded(
                child: Text(state.errorMessage!, style: context.pText.bodySmall?.copyWith(color: XploreColors.error)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: paddingUnit * 0.6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: XploreColors.alternate),
          const SizedBox(width: paddingUnit),
          Text(label, style: context.pText.bodySmall?.copyWith(color: XploreColors.subtleText)),
          const SizedBox(width: paddingUnit),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: context.pText.bodyMedium?.copyWith(color: XploreColors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(height: paddingUnit, thickness: 1, color: XploreColors.divider);
  }
}

class _GeneratingPlaceholder extends StatelessWidget {
  const _GeneratingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: paddingUnit),
          Text('Building your itinerary…', style: context.pText.bodyMedium?.copyWith(color: XploreColors.mutedText)),
        ],
      ),
    );
  }
}

class _ItinerarySkeletonList extends StatelessWidget {
  const _ItinerarySkeletonList({required this.state});

  final TripCreationState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < state.itinerary.length; i++) ...[
          _DayRow(index: i, title: state.itinerary[i].title, location: state.itinerary[i].location),
          if (i != state.itinerary.length - 1) const SizedBox(height: paddingUnit * 0.75),
        ],
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.index, required this.title, required this.location});

  final int index;
  final String title;
  final String location;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      padding: const EdgeInsets.all(paddingUnit),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: XploreColors.alternate.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(radiusSm),
              border: Border.all(color: XploreColors.alternate.withValues(alpha: 0.3)),
            ),
            child: Text(
              '${index + 1}',
              style: context.pText.labelLarge?.copyWith(color: XploreColors.white, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: paddingUnit),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.pText.labelLarge?.copyWith(color: XploreColors.white)),
                const SizedBox(height: 2),
                Text(location, style: context.pText.bodySmall?.copyWith(color: XploreColors.subtleText)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bucket 6 — Finishing touches. Name + cover, auto-suggested from destination.
class FinishingStep extends StatefulWidget {
  const FinishingStep({super.key});

  @override
  State<FinishingStep> createState() => _FinishingStepState();
}

class _FinishingStepState extends State<FinishingStep> {
  late final TextEditingController _title;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<TripCreationCubit>();
    final draft = cubit.state.draft;
    final initial = draft.title.trim().isEmpty ? draft.suggestedTitle : draft.title;
    _title = TextEditingController(text: initial);
    // Persist the auto-suggested name so submission has a title even if the
    // user never edits the field.
    if (draft.title.trim().isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => cubit.setTitle(initial));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TripCreationCubit>();
    final destination = cubit.state.draft.destination;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('STEP 6', style: context.pText.labelSmall?.copyWith(color: XploreColors.alternate, letterSpacing: 1.4)),
        const SizedBox(height: paddingUnit * 0.5),
        Text('Finishing touches', style: context.pText.headlineMedium?.copyWith(letterSpacing: -0.5, height: 1.05)),
        const SizedBox(height: paddingUnit * 0.5),
        Text(
          'Give your trip a name. We\u2019ve suggested one — tweak it however you like.',
          style: context.pText.bodyMedium?.copyWith(color: XploreColors.mutedText),
        ),
        const SizedBox(height: paddingUnit * 1.5),
        _CoverPreview(destination: destination),
        const SizedBox(height: paddingUnit * 1.5),
        TextField(
          controller: _title,
          textCapitalization: TextCapitalization.words,
          onChanged: cubit.setTitle,
          decoration: const InputDecoration(labelText: 'Trip name', prefixIcon: Icon(Icons.luggage_outlined)),
        ),
      ],
    );
  }
}

/// A gradient cover stand-in keyed to the destination. Real cover-image
/// selection is a phase-2 wrinkle; for now the hero card shows this gradient.
class _CoverPreview extends StatelessWidget {
  const _CoverPreview({required this.destination});

  final String destination;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radiusLg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(XploreColors.alternate, XploreColors.primary, 0.1)!,
            Color.lerp(XploreColors.secondary, XploreColors.primary, 0.3)!,
            XploreColors.primary,
          ],
        ),
        border: Border.all(color: XploreColors.white.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(paddingUnit * 1.25),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.photo_camera_back_outlined, color: XploreColors.white.withValues(alpha: 0.7), size: 20),
            const Spacer(),
            Text(
              destination.isEmpty ? 'Your trip' : destination,
              style: context.pText.headlineSmall?.copyWith(color: XploreColors.white, letterSpacing: -0.3),
            ),
            Text(
              'Cover art',
              style: context.pText.bodySmall?.copyWith(color: XploreColors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bucket 7 — Invite your crew. Genuinely skippable so solo travellers sail
/// through; the trip already exists so there's something worth sharing.
class InviteStep extends StatefulWidget {
  const InviteStep({super.key});

  @override
  State<InviteStep> createState() => _InviteStepState();
}

class _InviteStepState extends State<InviteStep> {
  bool _isCreating = false;

  Future<void> _share() async {
    final trip = context.read<TripCreationCubit>().state.createdTrip;
    if (trip == null || _isCreating) {
      return;
    }
    setState(() => _isCreating = true);

    final messenger = ScaffoldMessenger.of(context);
    final tripService = context.read<TripService>();
    final uid = context.read<AuthService>().currentUid;
    if (uid == null) {
      setState(() => _isCreating = false);
      return;
    }

    try {
      final handle = await tripService.createInvite(trip.id, uid);
      HapticFeedback.lightImpact();
      await SharePlus.instance.share(
        ShareParams(text: 'Join "${trip.title}" on Xplore:\n${handle.link}', subject: 'Join my trip on Xplore'),
      );
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Couldn\u2019t create an invite link. Please try again.')));
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = context.read<TripCreationCubit>().state.draft;
    final solo = draft.isSolo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: XploreColors.success.withValues(alpha: 0.18),
            border: Border.all(color: XploreColors.success.withValues(alpha: 0.4)),
          ),
          child: Icon(Icons.check_rounded, color: XploreColors.success, size: 28),
        ),
        const SizedBox(height: paddingUnit),
        Text('Your trip is ready', style: context.pText.headlineMedium?.copyWith(letterSpacing: -0.5, height: 1.05)),
        const SizedBox(height: paddingUnit * 0.5),
        Text(
          solo
              ? 'All set. Travelling with others later? You can invite them anytime from the trip.'
              : 'Share a link so your crew can join. No rush — you can invite anytime later too.',
          style: context.pText.bodyMedium?.copyWith(color: XploreColors.mutedText),
        ),
        const SizedBox(height: paddingUnit * 1.5),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isCreating ? null : _share,
            icon: _isCreating
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.ios_share_rounded, size: 18),
            label: Text(solo ? 'Share invite link' : 'Invite your crew'),
          ),
        ),
      ],
    );
  }
}
