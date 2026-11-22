import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/typography.dart';

/// Opens one of the itinerary editing sheets: card-coloured, with a drag
/// handle, sized to its content and lifted above the keyboard. Completes with
/// the value the sheet pops.
Future<T?> showEditSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: XploreColors.card,
    builder: (sheetContext) => Padding(
      // The keyboard overlaps the sheet; lift the content so the focused field stays visible.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
      child: builder(sheetContext),
    ),
  );
}

/// The content of an editing sheet: a heading over [children], scrollable so
/// it still fits with the keyboard up or at large text sizes.
class EditSheetBody extends StatelessWidget {
  const EditSheetBody({required this.title, required this.children, this.subtitle, super.key});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: XploreText.heading.copyWith(color: XploreColors.white)),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle, style: XploreText.footnote.copyWith(color: XploreColors.secondaryLabel)),
          ],
          ...children,
        ],
      ),
    );
  }
}

/// An uppercase tracked label above a field or a list ("NOTE FOR THE GROUP").
class EditOverline extends StatelessWidget {
  const EditOverline(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: XploreText.overline.copyWith(color: XploreColors.secondaryLabel));
  }
}

/// A filled, borderless text field. [fillColor] defaults to the raised grey
/// used inside sheets; pass [XploreColors.card] on a black page.
class EditTextField extends StatelessWidget {
  const EditTextField({
    required this.controller,
    required this.semanticLabel,
    this.hintText,
    this.maxLines = 1,
    this.maxLength,
    this.autofocus = false,
    this.fillColor = XploreColors.raised,
    this.textInputAction,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;

  /// Read by screen readers; the visible label is a separate [EditOverline].
  final String semanticLabel;
  final String? hintText;
  final int maxLines;
  final int? maxLength;
  final bool autofocus;
  final Color fillColor;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        minLines: maxLines,
        maxLines: maxLines,
        maxLength: maxLength,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: textInputAction,
        textCapitalization: TextCapitalization.sentences,
        style: XploreText.body.copyWith(color: XploreColors.white),
        cursorColor: XploreColors.accent,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: XploreText.body.copyWith(color: XploreColors.secondaryLabel),
          // The length limit is enforced silently; a counter would crowd the sheet.
          counterText: '',
          filled: true,
          fillColor: fillColor,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusSm), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}
