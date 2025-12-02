import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSellerProductsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get admin user ID from the current authenticated user
  Future<String?> getAdminUserId() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final userResponse = await _supabase
          .from('users')
          .select('id')
          .eq('auth_id', user.id)
          .single();

      return userResponse['id'] as String;
    } catch (e) {
      print('Error loading admin user ID: $e');
      return null;
    }
  }

  /// Load all seller products (excluding admin products) with related data
  /// Optimized to use batch queries instead of N+1 queries
  Future<List<Map<String, dynamic>>> loadSellerProducts(String adminUserId) async {
    try {
      // First, get seller_id for the admin user to exclude admin products
      final adminSellerResponse = await _supabase
          .from('sellers')
          .select('id')
          .eq('user_id', adminUserId)
          .maybeSingle();

      String? adminSellerId;
      if (adminSellerResponse != null) {
        adminSellerId = adminSellerResponse['id'] as String;
      }

      // Fetch products with seller information, excluding admin products at database level if possible
      var query = _supabase
          .from('products')
          .select('''
            id,
            name,
            description,
            usage,
            origin,
            price,
            seller_id,
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
            price_types(name),
            sellers(user_id, users(name))
          ''');

      // If we have admin seller_id, exclude it at database level
      if (adminSellerId != null) {
        query = query.neq('seller_id', adminSellerId);
      }

      final productsResponse = await query.order('created_at', ascending: false);

      // Filter products that don't belong to admin (in case adminSellerId is null)
      final List<Map<String, dynamic>> sellerProducts = [];
      final List<String> productIds = [];
      
      for (var product in productsResponse) {
        final sellerData = product['sellers'] as Map<String, dynamic>?;
        final sellerUserId = sellerData?['user_id'] as String?;
        final isAdminProduct = sellerUserId == adminUserId;

        // Only add products that belong to sellers (not admin)
        if (!isAdminProduct && sellerUserId != null) {
          sellerProducts.add(product);
          productIds.add(product['id'] as String);
        }
      }

      if (sellerProducts.isEmpty) {
        return [];
      }

      // Batch fetch all images for all products
      final allImagesResponse = await _supabase
          .from('product_images')
          .select('product_id, image_url, display_order, created_at')
          .order('created_at');

      // Filter images to only those belonging to our products and group by product_id
      final Map<String, String?> firstImagesMap = {};
      final Map<String, List<Map<String, dynamic>>> imagesByProduct = {};
      
      for (var image in allImagesResponse) {
        final productId = image['product_id'] as String;
        if (productIds.contains(productId)) {
          if (!imagesByProduct.containsKey(productId)) {
            imagesByProduct[productId] = [];
          }
          imagesByProduct[productId]!.add(image);
        }
      }
      
      // Get first image for each product (prioritize display_order, then created_at)
      for (var entry in imagesByProduct.entries) {
        final sortedImages = entry.value
          ..sort((a, b) {
            final aOrder = a['display_order'] as int? ?? 999;
            final bOrder = b['display_order'] as int? ?? 999;
            if (aOrder != bOrder) {
              return aOrder.compareTo(bOrder);
            }
            final aDate = a['created_at'] as String? ?? '';
            final bDate = b['created_at'] as String? ?? '';
            return aDate.compareTo(bDate);
          });
        if (sortedImages.isNotEmpty) {
          firstImagesMap[entry.key] = sortedImages[0]['image_url'] as String?;
        }
      }

      // Batch fetch all ratings for all products
      final allRatingsResponse = await _supabase
          .from('product_ratings')
          .select('product_id, rating');

      // Filter ratings to only those belonging to our products and calculate averages
      final Map<String, List<double>> ratingsByProduct = {};
      for (var rating in allRatingsResponse) {
        final productId = rating['product_id'] as String;
        if (productIds.contains(productId)) {
          final ratingValue = (rating['rating'] as num?)?.toDouble() ?? 0.0;
          if (!ratingsByProduct.containsKey(productId)) {
            ratingsByProduct[productId] = [];
          }
          ratingsByProduct[productId]!.add(ratingValue);
        }
      }

      // Build products with details
      final List<Map<String, dynamic>> productsWithDetails = [];
      
      for (var product in sellerProducts) {
        final productId = product['id'] as String;
        
        // Get seller name
        final sellerData = product['sellers'] as Map<String, dynamic>?;
        final sellerUsers = sellerData?['users'] as Map<String, dynamic>?;
        final sellerName = sellerUsers?['name'] as String? ?? 'Unknown Seller';
        
        // Get first image
        final firstImage = firstImagesMap[productId];

        // Calculate average rating
        double averageRating = 0.0;
        final ratings = ratingsByProduct[productId];
        if (ratings != null && ratings.isNotEmpty) {
          averageRating = ratings.reduce((a, b) => a + b) / ratings.length;
        }

        // Format price
        final price = product['price'] as num? ?? 0.0;
        final priceType = product['price_types'] as Map<String, dynamic>?;
        final priceTypeName = priceType?['name'] as String? ?? 'PKR';
        final formattedPrice = '$priceTypeName ${price.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';

        productsWithDetails.add({
          ...product,
          'first_image': firstImage,
          'rating': averageRating,
          'formatted_price': formattedPrice,
          'seller_name': sellerName,
        });
      }

      return productsWithDetails;
    } catch (e) {
      print('Error loading seller products: $e');
      return [];
    }
  }

  /// Filter products based on search query
  static List<Map<String, dynamic>> filterProducts(
    List<Map<String, dynamic>> products,
    String query,
  ) {
    final searchQuery = query.toLowerCase().trim();
    if (searchQuery.isEmpty) {
      return products;
    }
    
    return products.where((product) {
      final name = (product['name'] as String? ?? '').toLowerCase();
      final description = (product['description'] as String? ?? '').toLowerCase();
      final category = (product['product_categories'] as Map<String, dynamic>?)?['name'] as String? ?? '';
      final categoryLower = category.toLowerCase();
      final brand = (product['product_brands'] as Map<String, dynamic>?)?['name'] as String? ?? '';
      final brandLower = brand.toLowerCase();
      final type = (product['product_types'] as Map<String, dynamic>?)?['name'] as String? ?? '';
      final typeLower = type.toLowerCase();
      final sellerName = (product['seller_name'] as String? ?? '').toLowerCase();
      
      return name.contains(searchQuery) ||
             description.contains(searchQuery) ||
             categoryLower.contains(searchQuery) ||
             brandLower.contains(searchQuery) ||
             typeLower.contains(searchQuery) ||
             sellerName.contains(searchQuery);
    }).toList();
  }

  /// Delete a product and its associated images
  Future<void> deleteProduct(String productId) async {
    try {
      // Get all image URLs before deleting
      final imagesResponse = await _supabase
          .from('product_images')
          .select('image_url')
          .eq('product_id', productId);

      final imageUrls = (imagesResponse as List)
          .map((img) => img['image_url'] as String)
          .toList();

      // Delete product (cascade will delete product_images)
      await _supabase
          .from('products')
          .delete()
          .eq('id', productId);

      // Delete images from storage
      for (var imageUrl in imageUrls) {
        try {
          final fileName = imageUrl.split('/').last.split('?').first;
          await _supabase.storage
              .from('product-images')
              .remove([fileName]);
        } catch (e) {
          print('Error deleting image from storage: $e');
          // Continue even if storage deletion fails
        }
      }
    } catch (e) {
      print('Error deleting product: $e');
      rethrow;
    }
  }
}

