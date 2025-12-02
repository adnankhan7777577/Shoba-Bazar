import 'package:equatable/equatable.dart';

abstract class ProfileEditState extends Equatable {
  const ProfileEditState();

  @override
  List<Object?> get props => [];
}

class ProfileEditInitial extends ProfileEditState {
  const ProfileEditInitial();
}

class ProfileEditLoading extends ProfileEditState {
  const ProfileEditLoading();
}

class ProfileEditSuccess extends ProfileEditState {
  final String message;

  const ProfileEditSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class ProfileEditError extends ProfileEditState {
  final String message;

  const ProfileEditError(this.message);

  @override
  List<Object?> get props => [message];
}

class ProfileEditImageSelected extends ProfileEditState {
  final String imagePath;

  const ProfileEditImageSelected(this.imagePath);

  @override
  List<Object?> get props => [imagePath];
}

