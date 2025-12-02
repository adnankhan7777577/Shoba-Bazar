import 'package:equatable/equatable.dart';

abstract class AdminRequestsState extends Equatable {
  const AdminRequestsState();

  @override
  List<Object?> get props => [];
}

class AdminRequestsInitial extends AdminRequestsState {
  const AdminRequestsInitial();
}

class AdminRequestsLoading extends AdminRequestsState {
  const AdminRequestsLoading();
}

class AdminRequestsLoaded extends AdminRequestsState {
  final List<Map<String, dynamic>> requests;

  const AdminRequestsLoaded({required this.requests});

  @override
  List<Object?> get props => [requests];
}

class AdminRequestsError extends AdminRequestsState {
  final String message;

  const AdminRequestsError(this.message);

  @override
  List<Object?> get props => [message];
}

