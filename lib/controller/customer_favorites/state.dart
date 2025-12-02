import 'package:equatable/equatable.dart';

abstract class CustomerFavoritesState extends Equatable {
  const CustomerFavoritesState();

  @override
  List<Object?> get props => [];
}

class CustomerFavoritesInitial extends CustomerFavoritesState {
  const CustomerFavoritesInitial();
}

class CustomerFavoritesLoading extends CustomerFavoritesState {
  const CustomerFavoritesLoading();
}

class CustomerFavoritesLoaded extends CustomerFavoritesState {
  final List<Map<String, dynamic>> favorites;

  const CustomerFavoritesLoaded({required this.favorites});

  @override
  List<Object?> get props => [favorites];
}

class CustomerFavoritesError extends CustomerFavoritesState {
  final String message;

  const CustomerFavoritesError(this.message);

  @override
  List<Object?> get props => [message];
}

