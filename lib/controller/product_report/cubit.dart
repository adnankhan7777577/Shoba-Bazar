import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'state.dart';

class ProductReportCubit extends Cubit<ProductReportState> {
  ProductReportCubit() : super(const ProductReportInitial());

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

  // Submit product report
  Future<void> submitReport({
    required String productId,
    required String reason,
  }) async {
    emit(const ProductReportLoading());

    try {
      if (reason.trim().isEmpty) {
        emit(const ProductReportError('Report reason is required'));
        return;
      }

      final customerId = await _getCustomerId();
      if (customerId == null) {
        emit(const ProductReportError('User not logged in or not a customer'));
        return;
      }

      // Check if customer has already reported this product
      final existing = await _supabase
          .from('product_reports')
          .select('id')
          .eq('customer_id', customerId)
          .eq('product_id', productId)
          .maybeSingle();

      if (existing != null) {
        // Update existing report
        await _supabase
            .from('product_reports')
            .update({
              'reason': reason.trim(),
              'resolved': false, // Reset resolved status if updating
              'created_at': DateTime.now().toIso8601String(),
            })
            .eq('customer_id', customerId)
            .eq('product_id', productId);

        emit(const ProductReportSubmitted('Report updated successfully'));
      } else {
        // Insert new report
        await _supabase.from('product_reports').insert({
          'customer_id': customerId,
          'product_id': productId,
          'reason': reason.trim(),
          'resolved': false,
        });

        emit(const ProductReportSubmitted('Product reported successfully'));
      }
    } catch (e) {
      emit(ProductReportError('Failed to submit report: ${e.toString()}'));
    }
  }

  // Check if product is already reported by current customer
  Future<bool> checkReportStatus(String productId) async {
    try {
      final customerId = await _getCustomerId();
      if (customerId == null) return false;

      final response = await _supabase
          .from('product_reports')
          .select('id')
          .eq('customer_id', customerId)
          .eq('product_id', productId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  void reset() {
    emit(const ProductReportInitial());
  }
}

