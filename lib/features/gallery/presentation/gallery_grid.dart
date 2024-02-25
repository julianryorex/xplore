import 'dart:math';

import 'package:flutter/material.dart';

class GalleryGrid extends StatelessWidget {
  final List<dynamic> gallery;

  const GalleryGrid({
    required this.gallery,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final itemNum = gallery.length;

    return LayoutBuilder(
      builder: (context, bc) {
        const spacing = 3.0;

        final colWidth = bc.maxWidth; // padding

        final colCalc = (colWidth / (85 + spacing));
        final col = colCalc.floor();

        final rowCalc = itemNum / col;
        final rows = rowCalc.ceil();
        return Column(
          children: [
            ...List.generate(rows, (i) => i).map(
              (i) {
                final itemsLeftInCurrentRow = (itemNum - col * i);

                return Padding(
                  padding: const EdgeInsets.only(bottom: spacing),
                  child: SizedBox(
                    height: 86,
                    child: Row(
                      children: [
                        ...List.generate(min(itemsLeftInCurrentRow, col), ((colIndex) => colIndex)).map(
                          (el) {
                            return Container(
                              margin: el == col - 1 ? null : const EdgeInsets.only(right: spacing),
                              color: Colors.blue,
                              height: 85,
                              width: 85,
                              child: Center(
                                child: Text(el.toString()),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
