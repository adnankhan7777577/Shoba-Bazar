import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'state.dart';

class ProductRatingCubit extends Cubit<ProductRatingState> {
  ProductRatingCubit() : super(const ProductRatingInitial());

  final SupabaseClient _supabase = Supabase.instance.client;

  // Get customer_id from current user
  Future<String?> _getCustomerId() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      // Get user_id from users table
      final userResponse = await _supabase
          .from('users')
          .select('id')
          .eq('auth_id', user.id)
          .single();

      final userId = userResponse['id'] as String;

      // Get customer_id from customers table
      final customerResponse = await _supabase
          .from('customers')
          .select('id')
          .eq('user_id', userId)
          .single();

      return customerResponse['id'] as String;
    } catch (e) {
      return null;
    }
  }

  // Check if product is rated by current customer
  Future<void> checkRatingStatus(String productId) async {
    emit(const ProductRatingLoading());

    try {
      final customerId = await _getCustomerId();
      if (customerId == null) {
        emit(const ProductRatingChecked(hasRated: false));
        return;
      }

      final response = await _supabase
          .from('product_ratings')
          .select('rating, comment')
          .eq('customer_id', customerId)
          .eq('product_id', productId)
          .maybeSingle();

      if (response != null) {
        emit(ProductRatingChecked(
          hasRated: true,
          rating: response['rating'] as int?,
          comment: response['comment'] as String?,
        ));
      } else {
        emit(const ProductRatingChecked(hasRated: false));
      }
    } catch (e) {
      emit(ProductRatingError('Failed to check rating status: ${e.toString()}'));
    }
  }

  // Submit or update rating
  Future<void> submitRating({
    required String productId,
    required int rating,
    required String comment,
  }) async {
    emit(const ProductRatingLoading());

    try {
      if (comment.trim().isEmpty) {
        emit(const ProductRatingError('Comment is required'));
        return;
      }

      if (rating < 1 || rating > 5) {
        emit(const ProductRatingError('Rating must be between 1 and 5'));
        return;
      }

      final customerId = await _getCustomerId();
      if (customerId == null) {
        emit(const ProductRatingError('User not logged in or not a customer'));
        return;
      }

      // Check if rating already exists
      final existing = await _supabase
          .from('product_ratings')
          .select('id')
          .eq('customer_id', customerId)
          .eq('product_id', productId)
          .maybeSingle();

      if (existing != null) {
        // Update existing rating
        await _supabase
            .from('product_ratings')
            .update({
              'rating': rating,
              'comment': comment.trim(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('customer_id', customerId)
            .eq('product_id', productId);
      } else {
        // Insert new rating
        await _supabase.from('product_ratings').insert({
          'customer_id': customerId,
          'product_id': productId,
          'rating': rating,
          'comment': comment.trim(),
        });
      }

      emit(ProductRatingSubmitted(rating: rating, comment: comment.trim()));
    } catch (e) {
      emit(ProductRatingError('Failed to submit rating: ${e.toString()}'));
    }
  }
}


