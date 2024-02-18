import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';
import 'package:xplore/core/header.dart';
import 'package:xplore/core/icon_button.dart';
import 'package:xplore/core/layout_padding.dart';

class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            LayoutPadding(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Trip Gallery', style: context.pText.headlineLarge, textAlign: TextAlign.start),
                    const SizedBox(height: paddingUnit * 2),
                    DottedBorder(
                      color: XploreColors.secondary,
                      strokeWidth: 5,
                      borderType: BorderType.RRect,
                      dashPattern: const [8, 6],
                      radius: const Radius.circular(20),
                      child: Container(
                        width: 350,
                        height: 100,
                        decoration: BoxDecoration(
                          color: XploreColors.secondary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Material(
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                          ),
                          clipBehavior: Clip.hardEdge,
                          color: Colors.transparent,
                          child: InkWell(
                            splashColor: XploreColors.secondary.withOpacity(0.1),
                            highlightColor: XploreColors.secondary.withOpacity(0.1),
                            onTap: () {}, // Open photos
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.add_rounded),
                                  const SizedBox(width: paddingUnit / 2),
                                  Text('Upload to trip', style: context.pText.labelSmall),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Header(
              leadingWidget: XploreIconBtn(
                bgColor: XploreColors.darkBg,
                onTapCallback: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, size: 45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
