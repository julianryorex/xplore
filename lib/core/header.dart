import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';

class Header extends StatelessWidget {
  final Widget? leadingWidget;
  final Widget? titleWidget;
  final Widget? trailingWidget;

  static const padding = paddingUnit * 4;

  const Header({
    this.leadingWidget,
    this.titleWidget,
    this.trailingWidget,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: padding,
      // Match the content's horizontal inset so header controls line up with
      // the section headers and cards below.
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: paddingUnit * 1.5),
        child: Row(
          children: [
            ?leadingWidget,
            if (titleWidget != null)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: paddingUnit),
                  child: titleWidget!,
                ),
              )
            else
              const Spacer(),
            ?trailingWidget,
          ],
        ),
      ),
    );
  }
}
