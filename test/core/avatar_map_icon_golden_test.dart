// Golden for `AvatarMapIcon` — the widget `MarkerService` rasterises into the
// Google Maps marker bitmap, so its appearance is effectively shipped to peers.
//
// APPLE-ONLY: refresh with `make test-gold` on macOS.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/core/avatar_map_icon.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('AvatarMapIcon renders the default initial avatar', (tester) async {
    await pumpForGolden(
      tester,
      const Center(child: AvatarMapIcon(size: 100)),
      size: const Size(160, 160),
    );

    await expectLater(
      find.byType(AvatarMapIcon),
      matchesGoldenFile('goldens/avatar_map_icon.png'),
    );
  });
}
