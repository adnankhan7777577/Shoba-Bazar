import 'package:equatable/equatable.dart';

abstract class AuthSessionState extends Equatable {
  const AuthSessionState();

  @override
  List<Object?> get props => [];
}

class AuthSessionInitial extends AuthSessionState {
  const AuthSessionInitial();
}

class AuthSessionLoading extends AuthSessionState {
  const AuthSessionLoading();
}

class AuthSessionAuthenticated extends AuthSessionState {
  final String userId;
  final String role; // 'customer' or 'seller'

  const AuthSessionAuthenticated({
    required this.userId,
    required this.role,
  });

  @override
  List<Object?> get props => [userId, role];
}

class AuthSessionUnauthenticated extends AuthSessionState {
  const AuthSessionUnauthenticated();
}

class AuthSessionEmailUnverified extends AuthSessionState {
  final String email;
  final String role;

  const AuthSessionEmailUnverified({
    required this.email,
    required this.role,
  });

  @override
  List<Object?> get props => [email, role];
}

class AuthSessionSellerPendingApproval extends AuthSessionState {
  const AuthSessionSellerPendingApproval();

  @override
  List<Object?> get props => [];
}

class AuthSessionError extends AuthSessionState {
  final String message;

  const AuthSessionError(this.message);

  @override
  List<Object?> get props => [message];
}

