import 'dart:convert';
import 'dart:developer';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:logger/logger.dart';

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

Future<T> loadJsonAsset<T>(String pathToAsset) async {
  try {
    final jsonResponse = await rootBundle.loadString(pathToAsset);
    final T decodedObj = await json.decode(jsonResponse);
    log('Loaded json from asset: "$pathToAsset"');

    return decodedObj;
  } catch (err, stackTrace) {
    return Future.error(err, stackTrace);
  }
}

/// Logs are always enabled unless it's in release mode - then only info/warning/error logs are captured
Logger createLogger(String pref) {
  final prefix = '[$pref]';
  return Logger(
    level: kReleaseMode ? Level.info : Level.all,
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      colors: false,
      printEmojis: !kReleaseMode,
      noBoxingByDefault: true,
      levelEmojis: {
        Level.error: '📕 $prefix',
        Level.warning: '📙 $prefix',
        Level.info: '📘 $prefix',
        Level.debug: '📗 $prefix',
        Level.trace: '📓 $prefix',
      },
    ),
  );
}

final wlog = Logger(
  level: kReleaseMode ? Level.info : Level.all,
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    colors: false,
    printEmojis: !kReleaseMode,
    noBoxingByDefault: true,
    levelEmojis: {
      Level.error: '📕 [widget]',
      Level.warning: '📙 [widget]',
      Level.info: '📘 [widget]',
      Level.debug: '📗 [widget]',
      Level.trace: '📓 [widget]',
    },
  ),
);
