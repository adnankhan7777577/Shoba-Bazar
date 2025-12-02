import 'package:equatable/equatable.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

class ProfileLoaded extends ProfileState {
  final Map<String, dynamic> userData;
  final Map<String, dynamic>? roleSpecificData; // customer or seller data

  const ProfileLoaded({
    required this.userData,
    this.roleSpecificData,
  });

  @override
  List<Object?> get props => [userData, roleSpecificData];
}

class ProfileRefreshing extends ProfileState {
  final Map<String, dynamic> userData;
  final Map<String, dynamic>? roleSpecificData;

  const ProfileRefreshing({
    required this.userData,
    this.roleSpecificData,
  });

  @override
  List<Object?> get props => [userData, roleSpecificData];
}

class ProfileError extends ProfileState {
  final String message;

  const ProfileError(this.message);

  @override
  List<Object?> get props => [message];
}

