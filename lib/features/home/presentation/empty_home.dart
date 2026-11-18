import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xplore/features/agent/widgets/agent_composer.dart';
import 'package:xplore/features/agent/widgets/agent_hero.dart';
import 'package:xplore/features/home/widgets/empty_home_start_tiles.dart';
import 'package:xplore/features/profile/bloc/profile_cubit.dart';
import 'package:xplore/features/trip/presentation/join_by_link_sheet.dart';
import 'package:xplore/routes.dart';

/// Home's body when the user has no trips yet: ways to start a first trip and
/// a text field that opens trip creation with the description pre-filled.
class EmptyHome extends StatefulWidget {
  const EmptyHome({super.key});

  @override
  State<EmptyHome> createState() => _EmptyHomeState();
}

class _EmptyHomeState extends State<EmptyHome> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // There is no free-text trip parser, so the description travels as the
  // draft's notes; the create flow still asks for destination and dates.
  void _createFromDescription() {
    final description = _controller.text.trim();
    if (description.isEmpty) {
      return;
    }
    _focusNode.unfocus();
    // The text is kept so backing out of trip creation does not lose it.
    Navigator.pushNamed(context, Paths.createTrip, arguments: description);
  }

  @override
  Widget build(BuildContext context) {
    final name = context.select<ProfileCubit, String>((cubit) => cubit.state.name);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 36, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AgentHero(title: greetingFor('Where to first', name)),
                ),
                const SizedBox(height: 24),
                EmptyHomeStartTiles(
                  onDescribe: _focusNode.requestFocus,
                  onStepByStep: () => Navigator.pushNamed(context, Paths.createTrip),
                  onJoin: () => showJoinByLinkSheet(context),
                ),
              ],
            ),
          ),
        ),
        ComposerDock(
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) => AgentComposer(
              controller: _controller,
              focusNode: _focusNode,
              placeholder: '5 days in Tokyo in April',
              borderColor: const Color(0xFF3A3A3C),
              onSend: value.text.trim().isEmpty ? null : _createFromDescription,
            ),
          ),
        ),
      ],
    );
  }
}
