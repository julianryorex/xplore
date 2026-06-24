// Pure-Dart unit tests for the string extensions in `constants/extensions.dart`.
//
// `toColor()` underpins the entire `XploreColors` palette, so a regression here
// silently recolours the whole app — cheap to guard, high blast radius.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/constants/extensions.dart';

void main() {
  group('HexConversion.toColor', () {
    test('parses a 6-digit hex string as an opaque colour', () {
      final color = '1F8565'.toColor();
      expect(color, const Color(0xFF1F8565));
      expect(color.a, 1.0);
    });

    test('is case-insensitive and tolerates a leading #', () {
      expect('#1f8565'.toColor(), '1F8565'.toColor());
    });

    test('falls back to white for malformed input', () {
      expect(''.toColor(), Colors.white);
      expect('12345'.toColor(), Colors.white);
      expect('1234567'.toColor(), Colors.white);
    });
  });

  group('BoolCheck.toBool', () {
    test('only the literal string "true" is truthy', () {
      expect('true'.toBool(), isTrue);
      expect('false'.toBool(), isFalse);
      expect('True'.toBool(), isFalse);
      expect(null.toBool(), isFalse);
      expect(''.toBool(), isFalse);
    });
  });
}
