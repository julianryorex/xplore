import 'package:flutter/material.dart';

extension ThemeContextExtension on BuildContext {
  ThemeData get theme => Theme.of(this);

  TextTheme get pText => Theme.of(this).textTheme;

  void push(String path) {
    Navigator.pushNamed(this, path);
  }
}

extension BoolCheck on String? {
  bool toBool() {
    return this == 'true';
  }
}
