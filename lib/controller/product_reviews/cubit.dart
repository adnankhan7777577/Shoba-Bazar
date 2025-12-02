import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'state.dart';

class ProductReviewsCubit extends Cubit<ProductReviewsState> {
  ProductReviewsCubit() : super(const ProductReviewsInitial());

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> fetchProductReviews(String productId) async {
    emit(const ProductReviewsLoading());

    try {
      // Fetch all ratings for this product with customer and user information
      final ratingsResponse = await _supabase
          .from('product_ratings')
          .select('''
            id,
            rating,
            comment,
            created_at,
            customer_id,
            customers(
              user_id,
              users(
                id,
                name,
                profile_picture_url
              )
            )
          ''')
          .eq('product_id', productId)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> reviews = [];
      double totalRating = 0.0;
      
      for (var rating in ratingsResponse) {
        final customerData = rating['customers'] as Map<String, dynamic>?;
        final userData = customerData?['users'] as Map<String, dynamic>?;
        
        final userName = userData?['name'] as String? ?? 'Anonymous';
        final profilePictureUrl = userData?['profile_picture_url'] as String?;
        final ratingValue = rating['rating'] as int? ?? 0;
        final comment = rating['comment'] as String? ?? '';
        final createdAt = rating['created_at'] as String?;

        totalRating += ratingValue;

        reviews.add({
          'userName': userName,
          'rating': ratingValue,
          'comment': comment,
          'avatar': profilePictureUrl,
          'createdAt': createdAt,
        });
      }

      double? averageRating;
      if (reviews.isNotEmpty) {
        averageRating = totalRating / reviews.length;
      }

      emit(ProductReviewsLoaded(
        reviews: reviews,
        averageRating: averageRating,
      ));
    } catch (e) {
      emit(ProductReviewsError('Failed to load reviews: ${e.toString()}'));
    }
  }

  Future<void> fetchProductReviewsWithUserCheck(String productId) async {
    emit(const ProductReviewsLoading());

    try {
      // Get current user info to check if they have rated
      final currentUser = _supabase.auth.currentUser;
      String? currentUserId;
      
      if (currentUser != null) {
        try {
          final userResponse = await _supabase
              .from('users')
              .select('id')
              .eq('auth_id', currentUser.id)
              .single();
          currentUserId = userResponse['id'] as String?;
        } catch (e) {
          // User not found or error, continue without user check
        }
      }

      // Fetch all ratings for this product with customer and user information
      final ratingsResponse = await _supabase
          .from('product_ratings')
          .select('''
            id,
            rating,
            comment,
            created_at,
            customer_id,
            customers(
              user_id,
              users(
                id,
                name,
                profile_picture_url
              )
            )
          ''')
          .eq('product_id', productId)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> reviews = [];
      double totalRating = 0.0;
      
      for (var rating in ratingsResponse) {
        final customerData = rating['customers'] as Map<String, dynamic>?;
        final userData = customerData?['users'] as Map<String, dynamic>?;
        
        final userId = userData?['id'] as String?;
        final userName = userData?['name'] as String? ?? 'Anonymous';
        final profilePictureUrl = userData?['profile_picture_url'] as String?;
        final ratingValue = rating['rating'] as int? ?? 0;
        final comment = rating['comment'] as String? ?? '';
        final createdAt = rating['created_at'] as String?;

        totalRating += ratingValue;

        reviews.add({
          'userName': userName,
          'rating': ratingValue,
          'comment': comment,
          'avatar': profilePictureUrl,
          'createdAt': createdAt,
          'isCurrentUser': currentUserId != null && userId == currentUserId,
        });
      }

      double? averageRating;
      if (reviews.isNotEmpty) {
        averageRating = totalRating / reviews.length;
      }

      emit(ProductReviewsLoaded(
        reviews: reviews,
        averageRating: averageRating,
      ));
    } catch (e) {
      emit(ProductReviewsError('Failed to load reviews: ${e.toString()}'));
    }
  }
}

