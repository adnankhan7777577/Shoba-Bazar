import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDashboardService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get admin user ID from the current authenticated user
  Future<String?> getAdminUserId() async {
    try {
      // Get current user
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      // Get admin user data
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

  /// Load all products with related data (images, ratings, formatted prices)
  /// Only returns products that belong to the admin
  /// Optimized to use batch queries instead of N+1 queries
  Future<List<Map<String, dynamic>>> loadAdminProducts(String adminUserId) async {
    try {
      // First, get seller_id for the admin user
      final sellerResponse = await _supabase
          .from('sellers')
          .select('id')
          .eq('user_id', adminUserId)
          .maybeSingle();

      if (sellerResponse == null) {
        return [];
      }

      final sellerId = sellerResponse['id'] as String;

      // Fetch products filtered by seller_id at database level
      final productsResponse = await _supabase
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
            price_types(name)
          ''')
          .eq('seller_id', sellerId)
          .order('created_at', ascending: false);

      if (productsResponse.isEmpty) {
        return [];
      }

      // Extract all product IDs
      final productIds = productsResponse
          .map((product) => product['id'] as String)
          .toList();

      // Batch fetch images and ratings in parallel for better performance
      final results = await Future.wait([
        // Batch fetch all images for our products only using inFilter
        _supabase
            .from('product_images')
            .select('product_id, image_url, display_order, created_at')
            .inFilter('product_id', productIds)
            .order('display_order', ascending: true)
            .order('created_at', ascending: true),
        
        // Batch fetch all ratings for our products only using inFilter
        _supabase
            .from('product_ratings')
            .select('product_id, rating')
            .inFilter('product_id', productIds),
      ]);

      final allImagesResponse = results[0] as List;
      final allRatingsResponse = results[1] as List;

      // Group images by product_id and get first image for each
      final Map<String, String?> firstImagesMap = {};
      final Map<String, List<Map<String, dynamic>>> imagesByProduct = {};
      
      for (var image in allImagesResponse) {
        final productId = image['product_id'] as String;
        if (!imagesByProduct.containsKey(productId)) {
          imagesByProduct[productId] = [];
        }
        imagesByProduct[productId]!.add(image as Map<String, dynamic>);
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

      // Group ratings by product_id and calculate averages
      final Map<String, List<double>> ratingsByProduct = {};
      for (var rating in allRatingsResponse) {
        final ratingMap = rating as Map<String, dynamic>;
        final productId = ratingMap['product_id'] as String;
        final ratingValue = (ratingMap['rating'] as num?)?.toDouble() ?? 0.0;
        if (!ratingsByProduct.containsKey(productId)) {
          ratingsByProduct[productId] = [];
        }
        ratingsByProduct[productId]!.add(ratingValue);
      }

      // Build products with details
      final List<Map<String, dynamic>> productsWithDetails = [];
      
      for (var product in productsResponse) {
        final productId = product['id'] as String;
        
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
          'is_admin_product': true,
        });
      }

      return productsWithDetails;
    } catch (e) {
      print('Error loading products: $e');
      return [];
    }
  }

  /// Filter products based on search query
  /// Searches in name, description, category, brand, and type
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
      
      return name.contains(searchQuery) ||
             description.contains(searchQuery) ||
             categoryLower.contains(searchQuery) ||
             brandLower.contains(searchQuery) ||
             typeLower.contains(searchQuery);
    }).toList();
  }
}

