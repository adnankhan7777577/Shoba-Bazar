import 'package:equatable/equatable.dart';

abstract class ProductRatingState extends Equatable {
  const ProductRatingState();

  @override
  List<Object?> get props => [];
}

class ProductRatingInitial extends ProductRatingState {
  const ProductRatingInitial();
}

class ProductRatingLoading extends ProductRatingState {
  const ProductRatingLoading();
}

class ProductRatingChecked extends ProductRatingState {
  final bool hasRated;
  final int? rating;
  final String? comment;

  const ProductRatingChecked({
    required this.hasRated,
    this.rating,
    this.comment,
  });

  @override
  List<Object?> get props => [hasRated, rating, comment];
}

class ProductRatingSubmitted extends ProductRatingState {
  final int rating;
  final String comment;

  const ProductRatingSubmitted({
    required this.rating,
    required this.comment,
  });

  @override
  List<Object?> get props => [rating, comment];
}

class ProductRatingError extends ProductRatingState {
  final String message;

  const ProductRatingError(this.message);

  @override
  List<Object?> get props => [message];
}


