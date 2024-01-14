import 'dart:developer';

import 'package:flutter/material.dart';

extension ThemeContextExtension on BuildContext {
  ThemeData get theme => Theme.of(this);

  TextTheme get pText => Theme.of(this).textTheme;

  void push(String path) {
    Navigator.pushNamed(this, path);
  }
}

extension HexConversion on String {
  Color toColor() {
    String hexColor = toUpperCase().replaceAll('#', '');

    if (hexColor.isEmpty || hexColor.length != 6) {
      log('Unable to read color $this');
      return Colors.white;
    }

    hexColor = 'FF$hexColor';
    return Color(int.parse(hexColor, radix: 16));
  }
}
