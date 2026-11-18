// Pure-Dart unit tests for the string extensions in `constants/extensions.dart`.

import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/constants/extensions.dart';

void main() {
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
