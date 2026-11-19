import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xplore/constants/theme.dart';
import 'package:xplore/core/enums.dart';
import 'package:xplore/features/gallery/bloc/gallery_cubit.dart';
import 'package:xplore/features/gallery/models/image_models.dart';
import 'package:xplore/features/trip/bloc/trip_cubit.dart';
import 'package:xplore/features/trip/bloc/trip_state.dart';
import 'package:xplore/features/trip/models/trip_model.dart';
import 'package:xplore/routes.dart';
import 'package:xplore/screens/gallery_page.dart';

final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

class _FakeGalleryCubit extends Cubit<GalleryState> implements GalleryCubit {
  _FakeGalleryCubit(super.initialState);

  final retried = <String>[];
  var dismissCalls = 0;

  @override
  String? get currentUid => 'me';

  @override
  Future<void> retryUpload(String id) async => retried.add(id);

  @override
  void dismissSaveProgress() {
    dismissCalls++;
    emit(state.copyWith(saveProgress: null));
  }

  /// Emits [next] and lets the page rebuild: bloc delivers states on a microtask, after the first frame.
  Future<void> show(WidgetTester tester, GalleryState next) async {
    emit(next);
    await tester.pump();
    await tester.pump();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedTripCubit extends Cubit<TripState> implements TripCubit {
  _FixedTripCubit(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ImageModel _photo(String id, DateTime createdAt, {EUploadStatus status = EUploadStatus.complete}) =>
    ImageModel(id: id, createdAt: createdAt, lowResImage: _pixel, isUploading: status, uploaderUid: 'me');

GalleryState _album(List<ImageModel> photos) => GalleryState(imageMap: {for (final photo in photos) photo.id: photo});

Future<({_FakeGalleryCubit cubit, List<Object?> openedWith})> _pumpGallery(
  WidgetTester tester,
  GalleryState state,
) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final cubit = _FakeGalleryCubit(state);
  final trip = _FixedTripCubit(
    TripState.loaded(
      active: const TripModel(id: 't', title: 'Amalfi Coast', memberIds: ['me', 'a', 'b'], createdBy: 'me'),
      all: const [],
    ),
  );
  addTearDown(cubit.close);
  addTearDown(trip.close);

  final openedWith = <Object?>[];
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<GalleryCubit>.value(value: cubit),
        BlocProvider<TripCubit>.value(value: trip),
      ],
      child: MaterialApp(
        theme: getTheme(),
        home: const GalleryPage(),
        onGenerateRoute: (settings) {
          if (settings.name == Paths.galleryFocusView) openedWith.add(settings.arguments);
          return MaterialPageRoute(builder: (_) => const SizedBox());
        },
      ),
    ),
  );
  await tester.pump();
  return (cubit: cubit, openedWith: openedWith);
}

void main() {
  final today = DateTime.now();

  testWidgets('opens the viewer at the tapped photo\'s newest-first index', (tester) async {
    final photos = [
      for (var i = 0; i < 4; i++) _photo('today-$i', today.subtract(Duration(minutes: i))),
      for (var i = 0; i < 3; i++) _photo('older-$i', DateTime(2020, 1, 10, 12 - i)),
    ];
    final semantics = tester.ensureSemantics();
    final harness = await _pumpGallery(tester, _album(photos));

    expect(find.text('7 photos'), findsOneWidget);
    expect(find.text('Fri 10 Jan'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp(r'^Photo 2 by You\.')));
    await tester.pump();

    final args = harness.openedWith.single! as Map<String, Object?>;
    expect(args['initialIndex'], 1);
    expect((args['gallery']! as List<ImageModel>).map((p) => p.id), photos.map((p) => p.id));
    semantics.dispose();
  });

  testWidgets('a failed tile retries its upload and the status bar counts it', (tester) async {
    final harness = await _pumpGallery(
      tester,
      _album([
        _photo('ok', today),
        _photo('broken', today.subtract(const Duration(minutes: 1)), status: EUploadStatus.failed),
        _photo('sending', today.subtract(const Duration(minutes: 2)), status: EUploadStatus.uploading),
      ]),
    );

    expect(find.text('1 photo didn\'t upload'), findsOneWidget);

    await tester.tap(find.text('Retry').first);
    expect(harness.cubit.retried, ['broken']);
  });

  testWidgets('shows the Photos access sheet once when access is denied', (tester) async {
    final harness = await _pumpGallery(tester, _album([_photo('a', today)]));

    await harness.cubit.show(
      tester,
      harness.cubit.state.copyWith(saveProgress: const PhotoSaveProgress(phase: EPhotoSavePhase.denied)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Xplore can\'t save to Photos'), findsOneWidget);
    expect(harness.cubit.dismissCalls, 1);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('Xplore can\'t save to Photos'), findsNothing);
  });

  testWidgets('renders the empty album, first sync and a save run', (tester) async {
    final harness = await _pumpGallery(tester, const GalleryState());
    expect(find.text('Start the shared album'), findsOneWidget);
    expect(find.text('2 others will see them'), findsOneWidget);

    await harness.cubit.show(tester, const GalleryState(status: EBlocStatus.loading));
    expect(find.text('Syncing the album…'), findsOneWidget);

    await harness.cubit.show(
      tester,
      _album([_photo('a', today)])
          .copyWith(saveProgress: const PhotoSaveProgress(phase: EPhotoSavePhase.saving, total: 4, saved: 1)),
    );
    expect(find.text('Saving 2 of 4'), findsOneWidget);
    expect(find.text('Saving'), findsOneWidget);

    await harness.cubit.show(tester, harness.cubit.state.copyWith(savedToPhotosIds: {'a'}, saveProgress: null));
    await tester.pumpAndSettle();
    expect(find.text('All saved'), findsOneWidget);
  });
}
