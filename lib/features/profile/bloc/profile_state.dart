part of 'profile_cubit.dart';

@freezed
abstract class ProfileState with _$ProfileState {
  const factory ProfileState({
    required String id,
    required String name,
    String? username,
    String? photoUrl,
    Uint8List? profilePicture,
    @Default(false) bool isSaving,
  }) = _ProfileState;
}
