import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'state.dart';

class AdminSellerProductsCubit extends Cubit<AdminSellerProductsState> {
  AdminSellerProductsCubit() : super(const AdminSellerProductsInitial());

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> fetchSellerProducts(String sellerId) async {
    emit(const AdminSellerProductsLoading());

    try {
      // Fetch all products for this seller
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

      final List<Map<String, dynamic>> productsWithDetails = [];
      
      for (var product in productsResponse) {
        final productId = product['id'] as String;
        
        // Fetch first image
        final imagesResponse = await _supabase
            .from('product_images')
            .select('image_url')
            .eq('product_id', productId)
            .order('display_order', ascending: true)
            .limit(1);

        String? firstImage;
        if (imagesResponse.isNotEmpty) {
          firstImage = imagesResponse[0]['image_url'] as String?;
        }

        // Fetch average rating
        double averageRating = 0.0;
        try {
          final ratingsResponse = await _supabase
              .from('product_ratings')
              .select('rating')
              .eq('product_id', productId);
          
          if (ratingsResponse.isNotEmpty) {
            final ratings = ratingsResponse
                .map((rating) => (rating['rating'] as num?) ?? 0.0)
                .toList();
            if (ratings.isNotEmpty) {
              averageRating = ratings.reduce((a, b) => a + b) / ratings.length;
            }
          }
        } catch (e) {
          // Rating calculation failed, use default 0.0
        }

        // Format price
        final price = product['price'] as num? ?? 0.0;
        final priceType = product['price_types'] as Map<String, dynamic>?;
        final priceTypeName = priceType?['name'] as String? ?? 'PKR';
        final formattedPrice = '$priceTypeName ${price.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';

        // Build tags
        final usage = product['usage'] as String? ?? '';
        final origin = product['origin'] as String? ?? '';
        final tags = <String>[];
        if (usage.isNotEmpty) tags.add(usage);
        if (origin.isNotEmpty) tags.add(origin);

        productsWithDetails.add({
          ...product,
          'first_image': firstImage,
          'rating': averageRating,
          'formatted_price': formattedPrice,
          'tags': tags,
        });
      }

      emit(AdminSellerProductsLoaded(products: productsWithDetails));
    } catch (e) {
      emit(AdminSellerProductsError('Failed to load products: ${e.toString()}'));
    }
  }
}

