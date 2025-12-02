import 'package:equatable/equatable.dart';

abstract class AdminSellersState extends Equatable {
  const AdminSellersState();

  @override
  List<Object?> get props => [];
}

class AdminSellersInitial extends AdminSellersState {
  const AdminSellersInitial();
}

class AdminSellersLoading extends AdminSellersState {
  const AdminSellersLoading();
}

class AdminSellersLoaded extends AdminSellersState {
  final List<Map<String, dynamic>> sellers;

  const AdminSellersLoaded({required this.sellers});

  @override
  List<Object?> get props => [sellers];
}

class AdminSellersError extends AdminSellersState {
  final String message;

  const AdminSellersError(this.message);

  @override
  List<Object?> get props => [message];
}

