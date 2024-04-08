part of 'profile_cubit.dart';

@freezed
class ProfileState with _$ProfileState {
  const factory ProfileState({
    required String id,
    required String name,
    Uint8List? profilePicture,
  }) = _ProfileState;
}
