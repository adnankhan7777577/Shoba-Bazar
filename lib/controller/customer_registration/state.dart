import 'package:equatable/equatable.dart';

abstract class CustomerRegistrationState extends Equatable {
  const CustomerRegistrationState();

  @override
  List<Object?> get props => [];
}

class CustomerRegistrationInitial extends CustomerRegistrationState {
  const CustomerRegistrationInitial();
}

class CustomerRegistrationLoading extends CustomerRegistrationState {
  const CustomerRegistrationLoading();
}

class CustomerRegistrationSuccess extends CustomerRegistrationState {
  final String message;
  final String userId;

  const CustomerRegistrationSuccess({
    required this.message,
    required this.userId,
  });

  @override
  List<Object?> get props => [message, userId];
}

class CustomerRegistrationError extends CustomerRegistrationState {
  final String message;

  const CustomerRegistrationError(this.message);

  @override
  List<Object?> get props => [message];
}

class CustomerRegistrationImageSelected extends CustomerRegistrationState {
  final String imagePath;

  const CustomerRegistrationImageSelected(this.imagePath);

  @override
  List<Object?> get props => [imagePath];
}

