import 'package:flutter/material.dart';
import 'package:xplore/constants/constants.dart';
import 'package:xplore/constants/extensions.dart';

class AvatarMapIcon extends StatelessWidget {
  final double size;
  final ImageProvider<Object>? image;

  const AvatarMapIcon({this.size = 100, this.image, super.key});

  static final GlobalKey globalKeyAvatarMapIcon = GlobalKey(debugLabel: 'globalKeyAvatarMapIcon');

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: globalKeyAvatarMapIcon,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: CircleAvatar(
          foregroundImage: image,
          backgroundColor: XploreColors.secondary,
          child: Text('J', style: context.pText.headlineMedium),
        ),
      ),
    );
  }
}
