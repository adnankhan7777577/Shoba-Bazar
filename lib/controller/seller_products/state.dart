import 'package:equatable/equatable.dart';

abstract class SellerProductsState extends Equatable {
  const SellerProductsState();

  @override
  List<Object?> get props => [];
}

class SellerProductsInitial extends SellerProductsState {
  const SellerProductsInitial();
}

class SellerProductsLoading extends SellerProductsState {
  const SellerProductsLoading();
}

class SellerProductsLoaded extends SellerProductsState {
  final List<Map<String, dynamic>> products;

  const SellerProductsLoaded(this.products);

  @override
  List<Object?> get props => [products];
}

class SellerProductsError extends SellerProductsState {
  final String message;

  const SellerProductsError(this.message);

  @override
  List<Object?> get props => [message];
}


