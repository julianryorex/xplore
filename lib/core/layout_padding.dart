import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/core/header.dart';

class LayoutPadding extends StatelessWidget {
  final Widget child;
  final Widget? header;
  final bool enableHeaderPadding;

  const LayoutPadding({
    required this.child,
    this.enableHeaderPadding = true,
    this.header,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: paddingUnit * 1.5,
            right: paddingUnit * 1.5,
            bottom: paddingUnit * 1.5,
            top: paddingUnit * 1.5 + (enableHeaderPadding && header != null ? Header.padding : 0),
          ),
          child: child,
        ),
        ?header,
      ],
    );
  }
}
