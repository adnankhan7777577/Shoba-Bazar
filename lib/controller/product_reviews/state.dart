import 'package:equatable/equatable.dart';

abstract class ProductReviewsState extends Equatable {
  const ProductReviewsState();

  @override
  List<Object?> get props => [];
}

class ProductReviewsInitial extends ProductReviewsState {
  const ProductReviewsInitial();
}

class ProductReviewsLoading extends ProductReviewsState {
  const ProductReviewsLoading();
}

class ProductReviewsLoaded extends ProductReviewsState {
  final List<Map<String, dynamic>> reviews;
  final double? averageRating;

  const ProductReviewsLoaded({
    required this.reviews,
    this.averageRating,
  });

  @override
  List<Object?> get props => [reviews, averageRating];
}

class ProductReviewsError extends ProductReviewsState {
  final String message;

  const ProductReviewsError(this.message);

  @override
  List<Object?> get props => [message];
}

