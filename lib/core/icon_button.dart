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
  final Icon? icon;
  final Function() onTapCallback;
  final double size;
  final String? name;
  final bool hasVibrations;
  final Color? bgColor;
  final double borderRadius;
  final Color? borderColor;

  const XploreIconBtn({
    required this.onTapCallback,
    this.icon,
    this.hasVibrations = false,
    this.size = headerIconButtonSize,
    this.borderRadius = radiusMd,
    this.borderColor,
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
      child: Column(mainAxisSize: MainAxisSize.min, children: [_renderButton(), if (name != null) _renderButtonName()]),
    );
  }

  Widget _renderButton() {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: bgColor ?? XploreColors.alternate,
        borderRadius: BorderRadius.circular(borderRadius),
        border: borderColor != null ? Border.all(color: borderColor!, width: 2) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.24), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Material(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(borderRadius))),
        clipBehavior: Clip.hardEdge,
        color: Colors.transparent,
        child: InkWell(onTap: _onTapCallback, child: icon),
      ),
    );
  }

  Widget _renderButtonName() {
    return Container(
      padding: const EdgeInsets.all(5),
      child: Text(name!, textAlign: TextAlign.center),
    );
  }
}
