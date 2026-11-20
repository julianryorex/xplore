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
  _FakeGalleryCubit({this.original}) : super(const GalleryState());

  /// What [fetchFullResFile] returns; `null` behaves like being offline.
  final File? original;
  final fetchedIds = <String>[];
  final _saveResults = <String, Completer<bool>>{};
  var saveCalls = 0;

  /// Completes the save of photo [id].
  Completer<bool> saveResult(String id) => _saveResults.putIfAbsent(id, Completer.new);

  @override
  String? get currentUid => 'me';

  @override
  Future<File?> fetchFullResFile(String id) async {
    fetchedIds.add(id);
    return original;
  }

  @override
  Future<bool> savePhotoToPhotos(String id) {
    saveCalls++;
    return saveResult(id).future;
  }

  /// Ids of photos the signed-in member uploaded.
  var ownPhotoIds = <String>{};
  var deleteSucceeds = true;
  final deletedIds = <String>[];

  @override
  bool canDeletePhoto(String id) => ownPhotoIds.contains(id);

  @override
  Future<bool> deletePhoto(String id) async {
    if (deleteSucceeds) deletedIds.add(id);
    return deleteSucceeds;
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

/// A tiny real file standing in for a downloaded original.
File _originalFile() {
  final dir = Directory.systemTemp.createTempSync('focus_view_test');
  addTearDown(() => dir.deleteSync(recursive: true));
  return File('${dir.path}/original.png')..writeAsBytesSync(_pixel);
}

Future<void> _swipeToNextPhoto(WidgetTester tester) =>
    tester.drag(find.byType(PhotoViewGallery), const Offset(-600, 0));

Future<_FakeGalleryCubit> _pumpViewer(WidgetTester tester, {File? original, Set<String> ownPhotoIds = const {}}) async {
  final cubit = _FakeGalleryCubit(original: original)..ownPhotoIds = ownPhotoIds;
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

    await _swipeToNextPhoto(tester);
    await tester.pumpAndSettle();

    expect(find.text('3 of 3'), findsOneWidget);
    expect(find.text('Member'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('only your own photos offer Delete, and it asks before deleting', (tester) async {
    final cubit = await _pumpViewer(tester, ownPhotoIds: {'c'});
    // Photo b is Mara's.
    expect(find.byTooltip('Delete photo'), findsNothing);

    await _swipeToNextPhoto(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete photo'));
    await tester.pumpAndSettle();
    expect(cubit.deletedIds, isEmpty);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(cubit.deletedIds, ['c']);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('originals load only for pages the user settles on', (tester) async {
    final cubit = await _pumpViewer(tester);
    expect(cubit.fetchedIds, ['b']);

    // Passing through photo c without stopping must not download it.
    await _swipeToNextPhoto(tester);
    await tester.drag(find.byType(PhotoViewGallery), const Offset(600, 0));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(cubit.fetchedIds, isNot(contains('c')));

    await _swipeToNextPhoto(tester);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(cubit.fetchedIds.last, 'c');
  });

  testWidgets('Save ignores repeat taps while running, then confirms', (tester) async {
    final cubit = await _pumpViewer(tester, original: _originalFile());

    await tester.tap(find.bySemanticsLabel('Save to Photos'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Save to Photos'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    cubit.saveResult('b').complete(true);
    await tester.pump();
    expect(find.text('Saved to Photos'), findsOneWidget);
    expect(cubit.saveCalls, 1);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Saved to Photos'), findsNothing);
  });

  testWidgets('Save says the photo is unavailable, not blocked, when the original can’t load', (tester) async {
    final cubit = await _pumpViewer(tester);

    await tester.tap(find.bySemanticsLabel('Save to Photos'));
    await tester.pump();

    expect(find.textContaining('Couldn’t load the full-quality photo'), findsOneWidget);
    expect(find.textContaining('photo access'), findsNothing);
    expect(cubit.saveCalls, 0);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Save blames photo access only when the original was available', (tester) async {
    final cubit = await _pumpViewer(tester, original: _originalFile());

    await tester.tap(find.bySemanticsLabel('Save to Photos'));
    await tester.pump();
    cubit.saveResult('b').complete(false);
    await tester.pump();

    expect(find.textContaining('Check photo access in Settings'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a running Save stays with its photo after swiping away', (tester) async {
    final cubit = await _pumpViewer(tester, original: _originalFile());

    await tester.tap(find.bySemanticsLabel('Save to Photos'));
    await tester.pump();
    await _swipeToNextPhoto(tester);
    await tester.pumpAndSettle();

    // Photo c's Save is idle and usable while b's save is still running.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.bySemanticsLabel('Save to Photos'));
    await tester.pump();
    expect(cubit.saveCalls, 2);

    // b's confirmation must not appear over c.
    cubit.saveResult('b').complete(true);
    await tester.pump();
    expect(find.text('Saved to Photos'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Share explains instead of sharing the thumbnail when the original is unavailable', (tester) async {
    await _pumpViewer(tester);

    await tester.tap(find.bySemanticsLabel('Share'));
    await tester.pump();

    expect(find.textContaining('Couldn’t load the full-quality photo'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}
