import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';

class Header extends StatelessWidget {
  final Widget? leadingWidget;
  final Widget? trailingWidget;

  const Header({
    this.leadingWidget,
    this.trailingWidget,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: paddingUnit * 5,
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
