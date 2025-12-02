import 'package:equatable/equatable.dart';

abstract class PasswordChangeState extends Equatable {
  const PasswordChangeState();

  @override
  List<Object?> get props => [];
}

class PasswordChangeInitial extends PasswordChangeState {
  const PasswordChangeInitial();
}

class PasswordChangeLoading extends PasswordChangeState {
  const PasswordChangeLoading();
}

class PasswordChangeSuccess extends PasswordChangeState {
  final String message;

  const PasswordChangeSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class PasswordChangeError extends PasswordChangeState {
  final String message;

  const PasswordChangeError(this.message);

  @override
  List<Object?> get props => [message];
}

