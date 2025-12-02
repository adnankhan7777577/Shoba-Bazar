import 'package:equatable/equatable.dart';

abstract class AdminReportedProductsState extends Equatable {
  const AdminReportedProductsState();

  @override
  List<Object?> get props => [];
}

class AdminReportedProductsInitial extends AdminReportedProductsState {
  const AdminReportedProductsInitial();
}

class AdminReportedProductsLoading extends AdminReportedProductsState {
  const AdminReportedProductsLoading();
}

class AdminReportedProductsLoaded extends AdminReportedProductsState {
  final List<Map<String, dynamic>> reportedProducts;

  const AdminReportedProductsLoaded({required this.reportedProducts});

  @override
  List<Object?> get props => [reportedProducts];
}

class AdminReportedProductsError extends AdminReportedProductsState {
  final String message;

  const AdminReportedProductsError(this.message);

  @override
  List<Object?> get props => [message];
}

