import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xplore/constants/constants.dart';

/// Round Button that is used on the Map Canvas
///
/// `icon`: Icon of the button type [IonData]
///
/// `onTapCallback`: Callback of the Map Button
///
/// `size`: size of the button - default: 46
///
/// `name`: if [XploreIconBtn] has a name, it will be displayed under the button
///
class XploreIconBtn extends StatelessWidget {
  final Icon icon;
  final Function() onTapCallback;
  final double size;
  final String? name;
  final bool hasVibrations;
  final Color? bgColor;
  final double borderRadius;

  const XploreIconBtn({
    required this.icon,
    required this.onTapCallback,
    this.hasVibrations = false,
    this.size = 46.0,
    this.borderRadius = 10,
    this.bgColor,
    this.name,
    super.key,
  });

  void _onTapCallback() {
    if (hasVibrations) {
      HapticFeedback.mediumImpact();
    }

    onTapCallback();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTapCallback,
      child: Column(
        children: [
          _renderButton(),
          if (name != null) _renderButtonName(),
        ],
      ),
    );
  }

  Widget _renderButtonName() {
    return Container(
      padding: const EdgeInsets.all(5),
      child: Text(name!),
    );
  }

  Widget _renderButton() {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: bgColor ?? XploreColors.alternate,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
        ),
        clipBehavior: Clip.hardEdge,
        color: Colors.transparent,
        child: InkWell(
          onTap: _onTapCallback,
          child: icon,
        ),
      ),
    );
  }
}
