import 'package:equatable/equatable.dart';

abstract class AddProductState extends Equatable {
  const AddProductState();

  @override
  List<Object?> get props => [];
}

class AddProductInitial extends AddProductState {
  const AddProductInitial();
}

class AddProductLoading extends AddProductState {
  const AddProductLoading();
}

class AddProductSuccess extends AddProductState {
  final String message;
  final String productId;

  const AddProductSuccess({
    required this.message,
    required this.productId,
  });

  @override
  List<Object?> get props => [message, productId];
}

class AddProductError extends AddProductState {
  final String message;

  const AddProductError(this.message);

  @override
  List<Object?> get props => [message];
}


