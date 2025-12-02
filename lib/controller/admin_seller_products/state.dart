import 'package:equatable/equatable.dart';

abstract class AdminSellerProductsState extends Equatable {
  const AdminSellerProductsState();

  @override
  List<Object?> get props => [];
}

class AdminSellerProductsInitial extends AdminSellerProductsState {
  const AdminSellerProductsInitial();
}

class AdminSellerProductsLoading extends AdminSellerProductsState {
  const AdminSellerProductsLoading();
}

class AdminSellerProductsLoaded extends AdminSellerProductsState {
  final List<Map<String, dynamic>> products;

  const AdminSellerProductsLoaded({required this.products});

  @override
  List<Object?> get props => [products];
}

class AdminSellerProductsError extends AdminSellerProductsState {
  final String message;

  const AdminSellerProductsError(this.message);

  @override
  List<Object?> get props => [message];
}

