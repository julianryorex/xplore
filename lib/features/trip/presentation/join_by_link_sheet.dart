import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';
import 'package:xplore/features/trip/services/invite_link.dart';
import 'package:xplore/routes.dart';

/// Lets the user paste a friend's invite link and, when it parses, opens the
/// same join screen an invite universal link would.
Future<void> showJoinByLinkSheet(BuildContext context) async {
  final invite = await pickInviteLink(context);
  if (invite != null && context.mounted) {
    Navigator.pushNamed(context, Paths.joinTrip, arguments: invite);
  }
}

/// Shows the paste-an-invite-link sheet and returns the parsed link, or null
/// when the user dismisses it. Does not navigate.
Future<InviteLinkData?> pickInviteLink(BuildContext context) {
  return showModalBottomSheet<InviteLinkData>(
    context: context,
    isScrollControlled: true,
    backgroundColor: XploreColors.card,
    showDragHandle: true,
    builder: (_) => const _JoinByLinkSheet(),
  );
}

class _JoinByLinkSheet extends StatefulWidget {
  const _JoinByLinkSheet();

  @override
  State<_JoinByLinkSheet> createState() => _JoinByLinkSheetState();
}

class _JoinByLinkSheetState extends State<_JoinByLinkSheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final invite = InviteLink.parsePasted(_controller.text);
    if (invite == null) {
      setState(() => _error = 'That doesn’t look like an Xplore invite link.');
      return;
    }
    Navigator.pop(context, invite);
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty || !mounted) {
      return;
    }
    _controller.text = text;
    _submit();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Join a trip', style: XploreText.heading.copyWith(color: XploreColors.white)),
            const SizedBox(height: 4),
            Text(
              'Paste the invite link a friend shared with you.',
              style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel),
            ),
            const SizedBox(height: 16),
            _LinkField(controller: _controller, onSubmitted: _submit, onPaste: _paste),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: XploreText.footnote.copyWith(color: XploreColors.error)),
            ],
            const SizedBox(height: 16),
            _JoinButton(onPressed: _submit),
          ],
        ),
      ),
    );
  }
}

class _LinkField extends StatelessWidget {
  const _LinkField({required this.controller, required this.onSubmitted, required this.onPaste});

  final TextEditingController controller;
  final VoidCallback onSubmitted;
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.only(left: 16, right: 2),
      decoration: BoxDecoration(color: XploreColors.raised, borderRadius: BorderRadius.circular(radiusSm)),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              autocorrect: false,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => onSubmitted(),
              cursorColor: XploreColors.accent,
              style: XploreText.body.copyWith(color: XploreColors.white),
              decoration: InputDecoration.collapsed(
                hintText: 'Invite link',
                hintStyle: XploreText.body.copyWith(color: XploreColors.secondaryLabel),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'Paste invite link',
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPaste,
              child: const SizedBox.square(
                dimension: minTouchTarget,
                child: Icon(CupertinoIcons.doc_on_clipboard, size: 18, color: XploreColors.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JoinButton extends StatelessWidget {
  const _JoinButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: FilledButton(onPressed: onPressed, child: const Text('Join')),
    );
  }
}
