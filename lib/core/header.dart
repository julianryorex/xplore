import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';

class Header extends StatelessWidget {
  final Widget? leadingWidget;
  final Widget? trailingWidget;

  static const padding = paddingUnit * 5;

  const Header({
    this.leadingWidget,
    this.trailingWidget,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: padding,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: paddingUnit * 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            leadingWidget != null ? leadingWidget! : Container(),
            trailingWidget != null ? trailingWidget! : Container(),
          ],
        ),
      ),
    );
  }
}
