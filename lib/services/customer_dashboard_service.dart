import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerDashboardService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Load hot deals products (only from active sellers)
  Future<List<Map<String, dynamic>>> loadHotDeals() async {
    try {
      final productsResponse = await _supabase
          .from('products')
          .select('''
            id,
            name,
            price,
            seller_id,
            price_types(name),
            product_categories(name),
            product_brands(name),
            product_types(name),
            product_models(name),
            product_years(year),
            sellers(user_id, users(is_active, role))
          ''')
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> productsWithImages = [];
      
      for (var product in productsResponse) {
        // Filter: only include products from active sellers
        // Admin products should always be shown regardless of active status
        final sellerData = product['sellers'] as Map<String, dynamic>?;
        final userData = sellerData?['users'] as Map<String, dynamic>?;
        final isActive = userData?['is_active'] as bool? ?? false;
        final userRole = userData?['role'] as String?;
        final isAdminProduct = userRole == 'admin';
        
        if (!isAdminProduct && !isActive) {
          continue; // Skip products from blocked sellers (unless it's an admin product)
        }
        
        final productId = product['id'] as String;
        
        // Fetch first image for this product
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

        // Format price with currency
        final price = product['price'] as num? ?? 0.0;
        final priceType = product['price_types'] as Map<String, dynamic>?;
        final currency = priceType?['name'] as String? ?? 'PKR';
        final priceString = price.toStringAsFixed(0);
        final formattedPriceValue = priceString.replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
        final formattedPrice = '$currency $formattedPriceValue';

        productsWithImages.add({
          ...product,
          'first_image': firstImage,
          'rating': averageRating,
          'formatted_price': formattedPrice,
        });
      }

      return productsWithImages;
    } catch (e) {
      print('Error loading hot deals: $e');
      return [];
    }
  }
}

