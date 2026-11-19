import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:xplore/constants/theme.dart';
import 'package:xplore/features/gallery/bloc/gallery_cubit.dart';
import 'package:xplore/features/gallery/models/image_models.dart';
import 'package:xplore/features/gallery/presentation/gallery_focus_view.dart';

// A valid 1x1 PNG so the pager can decode the "thumbnail".
final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

/// A [GalleryCubit] whose original-photo and save calls are controlled by the test.
class _FakeGalleryCubit extends Cubit<GalleryState> implements GalleryCubit {
  _FakeGalleryCubit() : super(const GalleryState());

  final saveResult = Completer<bool>();
  var saveCalls = 0;

  @override
  String? get currentUid => 'me';

  @override
  Future<File?> fetchFullResFile(String id) async => null;

  @override
  Future<bool> savePhotoToPhotos(String id) {
    saveCalls++;
    return saveResult.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ImageModel _photo(String id, {String? uploaderUid, String? uploaderName}) => ImageModel(
  id: id,
  createdAt: DateTime(2025, 9, 16, 18, 42),
  lowResImage: _pixel,
  isUploading: EUploadStatus.complete,
  uploaderUid: uploaderUid,
  uploaderName: uploaderName,
);

Future<_FakeGalleryCubit> _pumpViewer(WidgetTester tester) async {
  final cubit = _FakeGalleryCubit();
  addTearDown(cubit.close);
  await tester.pumpWidget(
    BlocProvider<GalleryCubit>.value(
      value: cubit,
      child: MaterialApp(
        theme: getTheme(),
        home: GalleryFocusView(
          images: [
            _photo('a', uploaderUid: 'me'),
            _photo('b', uploaderUid: 'mara', uploaderName: 'Mara'),
            _photo('c'),
          ],
          initialIndex: 1,
        ),
      ),
    ),
  );
  await tester.pump();
  return cubit;
}

void main() {
  testWidgets('counter and uploader follow the visible page', (tester) async {
    await _pumpViewer(tester);

    expect(find.text('2 of 3'), findsOneWidget);
    expect(find.text('Mara'), findsOneWidget);

    await tester.drag(find.byType(PhotoViewGallery), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('3 of 3'), findsOneWidget);
    expect(find.text('Member'), findsOneWidget);
  });

  testWidgets('Save ignores repeat taps while running, then confirms', (tester) async {
    final cubit = await _pumpViewer(tester);

    await tester.tap(find.bySemanticsLabel('Save to Photos'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Save to Photos'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    cubit.saveResult.complete(true);
    await tester.pump();
    expect(find.text('Saved to Photos'), findsOneWidget);
    expect(cubit.saveCalls, 1);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Saved to Photos'), findsNothing);
  });

  testWidgets('Share explains instead of sharing the thumbnail when the original is unavailable', (tester) async {
    await _pumpViewer(tester);

    await tester.tap(find.bySemanticsLabel('Share'));
    await tester.pump();

    expect(find.textContaining('Couldn’t load the full-quality photo'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}
