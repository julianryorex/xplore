import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/features/agent/models/agent_status_line.dart';
import 'package:xplore/features/agent/models/agent_suggestions.dart';
import 'package:xplore/features/agent/widgets/agent_composer.dart';
import 'package:xplore/features/agent/widgets/agent_hero.dart';
import 'package:xplore/features/agent/widgets/agent_suggestion_list.dart';
import 'package:xplore/features/agent/widgets/trip_switcher.dart';
import 'package:xplore/features/home/models/trip_overview.dart';
import 'package:xplore/features/itinerary/bloc/itinerary_cubit.dart';
import 'package:xplore/features/profile/bloc/profile_cubit.dart';
import 'package:xplore/features/trip/bloc/trip_cubit.dart';
import 'package:xplore/features/trip/bloc/trip_state.dart';
import 'package:xplore/features/trip/models/trip_model.dart';

/// Route arguments for [AgentPage].
class AgentPageArgs {
  const AgentPageArgs({this.initialPrompt});

  /// Text to pre-fill the agent's text field with (e.g. "Plan Apr 5 for me").
  final String? initialPrompt;
}

/// The full-screen agent ("Ask anything"): a greeting, the active trip's
/// status, and prompts drawn from its itinerary.
///
/// No backend can answer questions or edit an existing itinerary yet, so the
/// text field can be filled but sending stays disabled, and a caption says so.
class AgentPage extends StatefulWidget {
  const AgentPage({this.args = const AgentPageArgs(), super.key});

  final AgentPageArgs args;

  @override
  State<AgentPage> createState() => _AgentPageState();
}

class _AgentPageState extends State<AgentPage> {
  late final _controller = TextEditingController(text: widget.args.initialPrompt);
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _useSuggestion(String text) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final tripState = context.watch<TripCubit>().state;
    final trips = tripState is TripLoaded ? tripState : null;

    return Scaffold(
      backgroundColor: XploreColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _Header(trips: trips),
            ),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
                child: _AgentIntro(activeTrip: trips?.active, onSuggestionSelected: _useSuggestion),
              ),
            ),
            const _UnavailableCaption(),
            ComposerDock(
              child: AgentComposer(
                controller: _controller,
                focusNode: _focusNode,
                placeholder: 'Describe what you want',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.trips});

  final TripLoaded? trips;

  @override
  Widget build(BuildContext context) {
    final trips = this.trips;
    return Row(
      children: [
        const _CloseButton(),
        const SizedBox(width: 8),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: trips == null ? null : TripSwitcher(active: trips.active, trips: trips.all),
          ),
        ),
      ],
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Close',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => Navigator.maybePop(context),
        child: const SizedBox.square(
          dimension: minTouchTarget,
          child: DecoratedBox(
            decoration: BoxDecoration(color: XploreColors.card, shape: BoxShape.circle),
            child: Icon(CupertinoIcons.xmark, size: 16, color: XploreColors.white),
          ),
        ),
      ),
    );
  }
}

/// Greeting, trip status and "Try asking", built from the active trip's
/// itinerary when it has loaded.
class _AgentIntro extends StatelessWidget {
  const _AgentIntro({required this.activeTrip, required this.onSuggestionSelected});

  final TripModel? activeTrip;
  final ValueChanged<String> onSuggestionSelected;

  @override
  Widget build(BuildContext context) {
    final name = context.select<ProfileCubit, String>((cubit) => cubit.state.name);
    final itineraryState = context.watch<ItineraryCubit>().state;
    final itinerary = itineraryState is LoadedItineraryState ? itineraryState.itinerary : null;
    final trip = activeTrip;
    final overview = trip == null ? null : TripOverview(trip: trip, dailyPlans: itinerary?.dailyPlans ?? const []);
    final suggestions = overview != null && itinerary != null ? agentSuggestions(overview) : const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AgentHero(
            title: greetingFor('What are we planning', name),
            subtitle: agentStatusLine(overview, itineraryLoaded: itinerary != null),
          ),
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 28),
          AgentSuggestionList(suggestions: suggestions, onSelected: onSuggestionSelected),
        ],
      ],
    );
  }
}

class _UnavailableCaption extends StatelessWidget {
  const _UnavailableCaption();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Text(
        'xplore can’t reply here yet. To get a day-by-day draft from a description, create a new trip.',
        style: TextStyle(fontSize: 13, height: 1.35, color: XploreColors.secondaryLabel),
      ),
    );
  }
}
