import 'package:equatable/equatable.dart';

abstract class LoginState extends Equatable {
  const LoginState();

  @override
  List<Object?> get props => [];
}

class LoginInitial extends LoginState {
  const LoginInitial();
}

class LoginLoading extends LoginState {
  const LoginLoading();
}

class LoginSuccess extends LoginState {
  final String userId;
  final String role;
  final String message;

  const LoginSuccess({
    required this.userId,
    required this.role,
    required this.message,
  });

  @override
  List<Object?> get props => [userId, role, message];
}

class LoginEmailUnverified extends LoginState {
  final String email;
  final String role;
  final String message;

  const LoginEmailUnverified({
    required this.email,
    required this.role,
    required this.message,
  });

  @override
  List<Object?> get props => [email, role, message];
}

class LoginSellerPendingApproval extends LoginState {
  const LoginSellerPendingApproval();

  @override
  List<Object?> get props => [];
}

class LoginError extends LoginState {
  final String message;

  const LoginError(this.message);

  @override
  List<Object?> get props => [message];
}

