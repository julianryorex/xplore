import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/core/fade_indexed_stack.dart';

void main() {
  testWidgets('lazily builds tabs and preserves activated tab state', (tester) async {
    var homeInitCount = 0;
    var mapInitCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _FadeIndexedStackHarness(onHomeInit: () => homeInitCount++, onMapInit: () => mapInitCount++),
        ),
      ),
    );

    expect(homeInitCount, 1);
    expect(mapInitCount, 0);
    expect(find.text('Home tab'), findsOneWidget);
    expect(find.text('Map tab'), findsNothing);

    await tester.tap(find.byKey(_FadeIndexedStackHarness.mapButtonKey));
    await tester.pumpAndSettle();

    expect(homeInitCount, 1);
    expect(mapInitCount, 1);
    expect(find.text('Map tab'), findsOneWidget);

    await tester.tap(find.byKey(_FadeIndexedStackHarness.homeButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_FadeIndexedStackHarness.mapButtonKey));
    await tester.pumpAndSettle();

    expect(homeInitCount, 1);
    expect(mapInitCount, 1);
    expect(find.text('Map tab'), findsOneWidget);
  });
}

class _FadeIndexedStackHarness extends StatefulWidget {
  const _FadeIndexedStackHarness({required this.onHomeInit, required this.onMapInit});

  static const homeButtonKey = ValueKey('show-home-tab');
  static const mapButtonKey = ValueKey('show-map-tab');

  final VoidCallback onHomeInit;
  final VoidCallback onMapInit;

  @override
  State<_FadeIndexedStackHarness> createState() => _FadeIndexedStackHarnessState();
}

class _FadeIndexedStackHarnessState extends State<_FadeIndexedStackHarness> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            TextButton(
              key: _FadeIndexedStackHarness.homeButtonKey,
              onPressed: () => setState(() => _index = 0),
              child: const Text('Home'),
            ),
            TextButton(
              key: _FadeIndexedStackHarness.mapButtonKey,
              onPressed: () => setState(() => _index = 1),
              child: const Text('Map'),
            ),
          ],
        ),
        Expanded(
          child: FadeIndexedStack(
            index: _index,
            children: [
              _CountingTab(label: 'Home tab', onInit: widget.onHomeInit),
              _CountingTab(label: 'Map tab', onInit: widget.onMapInit),
            ],
          ),
        ),
      ],
    );
  }
}

class _CountingTab extends StatefulWidget {
  const _CountingTab({required this.label, required this.onInit});

  final String label;
  final VoidCallback onInit;

  @override
  State<_CountingTab> createState() => _CountingTabState();
}

class _CountingTabState extends State<_CountingTab> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => Center(child: Text(widget.label));
}
