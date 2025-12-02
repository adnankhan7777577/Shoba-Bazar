import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'state.dart';

class SellerProductsCubit extends Cubit<SellerProductsState> {
  SellerProductsCubit() : super(const SellerProductsInitial());

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> fetchSellerProducts() async {
    emit(const SellerProductsLoading());

    try {
      // Get current user
      final user = _supabase.auth.currentUser;
      if (user == null) {
        emit(const SellerProductsError('User not logged in'));
        return;
      }

      // Get user data to find seller_id
      final userResponse = await _supabase
          .from('users')
          .select('id')
          .eq('auth_id', user.id)
          .single();

      final userId = userResponse['id'];

      // Get seller_id from sellers table
      final sellerResponse = await _supabase
          .from('sellers')
          .select('id')
          .eq('user_id', userId)
          .single();

      final sellerId = sellerResponse['id'] as String;

      // Fetch products with related data
      final productsResponse = await _supabase
          .from('products')
          .select('''
            id,
            name,
            description,
            usage,
            origin,
            price,
            created_at,
            updated_at,
            category_id,
            type_id,
            brand_id,
            model_id,
            year_id,
            price_type_id,
            product_categories(name),
            product_types(name),
            product_brands(name),
            product_models(name),
            product_years(year),
            price_types(name)
          ''')
          .eq('seller_id', sellerId)
          .order('created_at', ascending: false);

      // Fetch images for each product
      final List<Map<String, dynamic>> productsWithImages = [];
      
      for (var product in productsResponse) {
        final productId = product['id'] as String;
        
        // Fetch images for this product, ordered by display_order
        final imagesResponse = await _supabase
            .from('product_images')
            .select('image_url')
            .eq('product_id', productId)
            .order('display_order', ascending: true);

        final images = (imagesResponse as List)
            .map((img) => img['image_url'] as String)
            .toList();

        productsWithImages.add({
          ...product,
          'images': images,
        });
      }

      emit(SellerProductsLoaded(productsWithImages));
    } on PostgrestException catch (e) {
      emit(SellerProductsError('Failed to fetch products: ${e.message}'));
    } catch (e) {
      emit(SellerProductsError('Failed to fetch products: ${e.toString()}'));
    }
  }

  void refreshProducts() {
    fetchSellerProducts();
  }
}


