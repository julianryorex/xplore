import 'package:flutter/material.dart';
import 'package:xplore/core/header.dart';

// TODO: add header within with flag as param
class LayoutPadding extends StatelessWidget {
  final Widget child;
  final bool enableHeaderPadding;

  const LayoutPadding({
    required this.child,
    this.enableHeaderPadding = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, bottom: 20, top: 30 + (enableHeaderPadding ? Header.padding : 0)),
      child: child,
    );
  }
}
