import 'package:equatable/equatable.dart';

abstract class OtpVerificationState extends Equatable {
  const OtpVerificationState();

  @override
  List<Object?> get props => [];
}

class OtpVerificationInitial extends OtpVerificationState {
  const OtpVerificationInitial();
}

class OtpVerificationLoading extends OtpVerificationState {
  const OtpVerificationLoading();
}

class OtpVerificationSuccess extends OtpVerificationState {
  final String message;
  final String userId;
  final String role;

  const OtpVerificationSuccess({
    required this.message,
    required this.userId,
    required this.role,
  });

  @override
  List<Object?> get props => [message, userId, role];
}

class OtpVerificationError extends OtpVerificationState {
  final String message;

  const OtpVerificationError(this.message);

  @override
  List<Object?> get props => [message];
}

class OtpResendLoading extends OtpVerificationState {
  const OtpResendLoading();
}

class OtpResendSuccess extends OtpVerificationState {
  final String message;

  const OtpResendSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class OtpResendError extends OtpVerificationState {
  final String message;

  const OtpResendError(this.message);

  @override
  List<Object?> get props => [message];
}

