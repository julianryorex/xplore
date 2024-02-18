import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part '../../../generated/features/gallery/bloc/gallery_cubit.freezed.dart';
part 'gallery_states.dart';

class GalleryCubit extends Cubit<GalleryStates> {
  GalleryCubit() : super(InitialGalleryState()) {
    init();
  }

  Future<void> init() async {
    emit(const LoadedGalleryState());
  }
}
