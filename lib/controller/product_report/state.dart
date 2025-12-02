import 'package:equatable/equatable.dart';

abstract class ProductReportState extends Equatable {
  const ProductReportState();

  @override
  List<Object?> get props => [];
}

class ProductReportInitial extends ProductReportState {
  const ProductReportInitial();
}

class ProductReportLoading extends ProductReportState {
  const ProductReportLoading();
}

class ProductReportSubmitted extends ProductReportState {
  final String message;

  const ProductReportSubmitted(this.message);

  @override
  List<Object?> get props => [message];
}

class ProductReportError extends ProductReportState {
  final String message;

  const ProductReportError(this.message);

  @override
  List<Object?> get props => [message];
}

