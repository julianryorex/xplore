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
                  children: [
                    Text('Trip Gallery', style: context.pText.headlineLarge),
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
