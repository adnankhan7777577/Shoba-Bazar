import 'package:equatable/equatable.dart';

abstract class ProductFavoriteState extends Equatable {
  const ProductFavoriteState();

  @override
  List<Object?> get props => [];
}

class ProductFavoriteInitial extends ProductFavoriteState {
  const ProductFavoriteInitial();
}

class ProductFavoriteLoading extends ProductFavoriteState {
  const ProductFavoriteLoading();
}

class ProductFavoriteChecked extends ProductFavoriteState {
  final bool isFavorited;

  const ProductFavoriteChecked({required this.isFavorited});

  @override
  List<Object?> get props => [isFavorited];
}

class ProductFavoriteToggled extends ProductFavoriteState {
  final bool isFavorited;

  const ProductFavoriteToggled({required this.isFavorited});

  @override
  List<Object?> get props => [isFavorited];
}

class ProductFavoriteError extends ProductFavoriteState {
  final String message;

  const ProductFavoriteError(this.message);

  @override
  List<Object?> get props => [message];
}


