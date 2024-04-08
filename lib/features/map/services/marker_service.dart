import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/rendering.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xplore/core/avatar_map_icon.dart';
import 'package:xplore/utilities/utilities.dart';

class MarkerService {
  late final HiveInterface _hive;
  late final Logger _logger;

  static const markerHiveBox = 'markers';

  MarkerService({HiveInterface? hiveInterface}) {
    _hive = hiveInterface ?? Hive;
    _logger = createLogger('MarkerService');
  }

  Future<Uint8List?> convertMarkerWidgetToBytes() async {
    try {
      final RenderRepaintBoundary boundary =
          AvatarMapIcon.globalKeyAvatarMapIcon.currentContext?.findRenderObject() as RenderRepaintBoundary;

      final ui.Image image = await boundary.toImage(pixelRatio: 2);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      return pngBytes;
    } catch (err, stack) {
      _logger.e('Error converting image to bytes', error: err, stackTrace: stack);
      return null;
    }
  }

  Future<Uint8List?> fetchMarkerIcon(String markerId) async {
    final box = await _hive.openBox(markerHiveBox);
    final Uint8List? markers = await box.get(markerId, defaultValue: null);
    _logger.d('marker fetched for $markerId (${markers?.length} bytes)');
    return markers;
  }

  Future<void> updateMarkerIcon(String id, Uint8List markerAsBytes) async {
    final box = await _hive.openBox(markerHiveBox);
    await box.put(id, markerAsBytes);
    _logger.d('Updated marker icon in cache');

    uploadMarkerIcon(id, markerAsBytes);
  }

  //! -------------------------------------------------------------------------
  //! Private Methods
  //! -------------------------------------------------------------------------

  @visibleForTesting
  Future<String> uploadMarkerIcon(String id, Uint8List markerAsBytes) async {
    // create file to go from Uint8List -> File
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/marker.png');
    await file.writeAsBytes(markerAsBytes);

    // upload to cloud
    try {
      FirebaseStorage storage = FirebaseStorage.instance;
      Reference ref = storage.ref().child('markers/$id/marker');

      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot taskSnapshot = await uploadTask;
      String downloadURL = await taskSnapshot.ref.getDownloadURL();

      _logger.d('Updated marker icon in GCP');
      return downloadURL;
    } catch (e) {
      return Future.error(e);
    }
  }
}
