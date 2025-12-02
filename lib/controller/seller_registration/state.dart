import 'package:equatable/equatable.dart';

abstract class SellerRegistrationState extends Equatable {
  const SellerRegistrationState();

  @override
  List<Object?> get props => [];
}

class SellerRegistrationInitial extends SellerRegistrationState {
  const SellerRegistrationInitial();
}

class SellerRegistrationLoading extends SellerRegistrationState {
  const SellerRegistrationLoading();
}

class SellerRegistrationSuccess extends SellerRegistrationState {
  final String message;
  final String userId;

  const SellerRegistrationSuccess({
    required this.message,
    required this.userId,
  });

  @override
  List<Object?> get props => [message, userId];
}

class SellerRegistrationError extends SellerRegistrationState {
  final String message;

  const SellerRegistrationError(this.message);

  @override
  List<Object?> get props => [message];
}

class SellerRegistrationImageSelected extends SellerRegistrationState {
  final String imagePath;

  const SellerRegistrationImageSelected(this.imagePath);

  @override
  List<Object?> get props => [imagePath];
}

