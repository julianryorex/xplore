import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Allow small cross-platform text/icon rasterization differences in headless
/// golden tests (e.g. Linux CI vs macOS dev machines). Issue #16 observed ~1.7%
/// drift on the itinerary card golden after the liquid-glass UI refresh.
const _kGoldenPrecisionTolerance = 0.02;

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  if (goldenFileComparator is LocalFileComparator) {
    goldenFileComparator = _TolerantGoldenFileComparator(
      Uri.parse('test/flutter_test_config.dart'),
      precisionTolerance: _kGoldenPrecisionTolerance,
    );
  }
  await testMain();
}

class _TolerantGoldenFileComparator extends LocalFileComparator {
  _TolerantGoldenFileComparator(
    super.testFile, {
    required double precisionTolerance,
  }) : assert(
         0 <= precisionTolerance && precisionTolerance <= 1,
         'precisionTolerance must be between 0 and 1',
       ),
       _precisionTolerance = precisionTolerance;

  final double _precisionTolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );

    final passed = result.passed || result.diffPercent <= _precisionTolerance;
    if (passed) {
      if (!result.passed) {
        debugPrint(
          'Golden "$golden" differed by ${(result.diffPercent * 100).toStringAsFixed(2)}%, '
          'within the ${_kGoldenPrecisionTolerance * 100}% tolerance.',
        );
      }
      result.dispose();
      return true;
    }

    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
