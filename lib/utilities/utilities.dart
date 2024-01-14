import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// gets the screen width of the current device
///
/// (optional) `percent` : percent of the height
///
/// (ex: `percent: 0.3` is 30%)
double getScreenWidth({required BuildContext context, double? percent}) {
  return (percent != null) ? MediaQuery.of(context).size.width * percent : MediaQuery.of(context).size.width;
}

/// gets the screen height of the current device
///
/// (optional) `percent` : percent of the height
///
/// (ex: `percent: 0.3` is 30%)
double getScreenHeight({required BuildContext context, double? percent}) {
  if (percent != null) {
    return MediaQuery.of(context).size.height * percent;
  } else {
    return MediaQuery.of(context).size.height;
  }
}

Future<Uint8List> getBytesFromAsset(String path, int width) async {
  ByteData data = await rootBundle.load(path);
  ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
  ui.FrameInfo fi = await codec.getNextFrame();
  return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
}

void unfocusKeyboard() => WidgetsBinding.instance.focusManager.primaryFocus?.unfocus();
