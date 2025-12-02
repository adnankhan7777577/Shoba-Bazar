import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'state.dart';

class ProductFavoriteCubit extends Cubit<ProductFavoriteState> {
  ProductFavoriteCubit() : super(const ProductFavoriteInitial());

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

  // Check if product is favorited by current customer
  Future<void> checkFavoriteStatus(String productId) async {
    emit(const ProductFavoriteLoading());

    try {
      final customerId = await _getCustomerId();
      if (customerId == null) {
        emit(const ProductFavoriteChecked(isFavorited: false));
        return;
      }

      final response = await _supabase
          .from('product_favorites')
          .select('id')
          .eq('customer_id', customerId)
          .eq('product_id', productId)
          .maybeSingle();

      emit(ProductFavoriteChecked(isFavorited: response != null));
    } catch (e) {
      emit(ProductFavoriteError('Failed to check favorite status: ${e.toString()}'));
    }
  }

  // Toggle favorite status (add or remove) - Optimistic update for real-time UI
  Future<void> toggleFavorite(String productId, {bool? currentFavoriteStatus}) async {
    // Get customer ID first
    final customerId = await _getCustomerId();
    if (customerId == null) {
      emit(const ProductFavoriteError('User not logged in or not a customer'));
      return;
    }

    // Determine the new favorite status
    // If currentFavoriteStatus is provided, use it; otherwise check from database
    bool isCurrentlyFavorited;
    if (currentFavoriteStatus != null) {
      isCurrentlyFavorited = currentFavoriteStatus;
    } else {
      // Fallback: check from database if status not provided
      try {
        final existing = await _supabase
            .from('product_favorites')
            .select('id')
            .eq('customer_id', customerId)
            .eq('product_id', productId)
            .maybeSingle();
        isCurrentlyFavorited = existing != null;
      } catch (e) {
        emit(ProductFavoriteError('Failed to check favorite status: ${e.toString()}'));
        return;
      }
    }

    // Optimistic update: emit new state immediately
    final newFavoriteStatus = !isCurrentlyFavorited;
    emit(ProductFavoriteToggled(isFavorited: newFavoriteStatus));

    // Perform database operation in background
    try {
      if (isCurrentlyFavorited) {
        // Remove from favorites
        await _supabase
            .from('product_favorites')
            .delete()
            .eq('customer_id', customerId)
            .eq('product_id', productId);
      } else {
        // Add to favorites
        await _supabase.from('product_favorites').insert({
          'customer_id': customerId,
          'product_id': productId,
        });
      }
      // Success - state already emitted optimistically, no need to emit again
    } catch (e) {
      // Revert on error - emit reverted state (error state will be handled by listener)
      emit(ProductFavoriteToggled(isFavorited: isCurrentlyFavorited));
      // Emit error after a brief delay to allow UI to update first
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!isClosed) {
          emit(ProductFavoriteError('Failed to toggle favorite: ${e.toString()}'));
        }
      });
    }
  }
}


