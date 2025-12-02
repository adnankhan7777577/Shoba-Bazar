import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'state.dart';

class ProductsCubit extends Cubit<ProductsState> {
  ProductsCubit() : super(const ProductsInitial());

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> fetchAllProducts({int limit = 100}) async {
    emit(const ProductsLoading());

    try {
      final productsResponse = await _supabase
          .from('products')
          .select('''
            id,
            name,
            price,
            description,
            seller_id,
            price_types(name),
            product_categories(name),
            product_brands(name),
            product_types(name),
            product_models(name),
            product_years(year),
            sellers(user_id, approval_status, users(is_active, role))
          ''')
          .order('created_at', ascending: false)
          .limit(limit);

      await _processProducts(productsResponse);
    } catch (e) {
      emit(ProductsError('Failed to load products: ${e.toString()}'));
    }
  }

  Future<void> searchProducts(String query, {int limit = 100}) async {
    emit(const ProductsLoading());

    try {
      if (query.trim().isEmpty) {
        await fetchAllProducts(limit: limit);
        return;
      }

      final searchQuery = query.trim();
      
      // Search products by title (name), brand, and category
      // First, get matching category IDs and brand IDs
      final categoriesResponse = await _supabase
          .from('product_categories')
          .select('id')
          .ilike('name', '%$searchQuery%');
      
      final brandsResponse = await _supabase
          .from('product_brands')
          .select('id')
          .ilike('name', '%$searchQuery%');
      
      final categoryIds = categoriesResponse.map((cat) => cat['id'] as String).toList();
      final brandIds = brandsResponse.map((brand) => brand['id'] as String).toList();
      
      // Build query to search by name, category_id, or brand_id
      var queryBuilder = _supabase
          .from('products')
          .select('''
            id,
            name,
            price,
            description,
            seller_id,
            price_types(name),
            product_categories(name),
            product_brands(name),
            product_types(name),
            product_models(name),
            product_years(year),
            sellers(user_id, approval_status, users(is_active, role))
          ''');
      
      // Use OR condition to search across name, category_id, and brand_id
      List<String> orConditions = ['name.ilike.%$searchQuery%'];
      
      if (categoryIds.isNotEmpty) {
        orConditions.add('category_id.in.(${categoryIds.join(',')})');
      }
      
      if (brandIds.isNotEmpty) {
        orConditions.add('brand_id.in.(${brandIds.join(',')})');
      }
      
      final productsResponse = await queryBuilder
          .or(orConditions.join(','))
          .order('created_at', ascending: false)
          .limit(limit);

      await _processProducts(productsResponse);
    } catch (e) {
      emit(ProductsError('Failed to search products: ${e.toString()}'));
    }
  }

  Future<void> fetchProductsByCategory({
    String? categoryId,
    String? typeId,
    String? brandId,
    String? modelId,
  }) async {
    emit(const ProductsLoading());

    try {
      var query = _supabase
          .from('products')
          .select('''
            id,
            name,
            price,
            description,
            seller_id,
            price_types(name),
            product_categories(name),
            product_brands(id, name),
            product_types(id, name),
            product_models(id, name),
            sellers(user_id, approval_status, users(is_active, role))
          ''');

      if (categoryId != null) {
        query = query.eq('category_id', categoryId);
      }

      if (typeId != null) {
        query = query.eq('type_id', typeId);
      }

      if (brandId != null) {
        query = query.eq('brand_id', brandId);
      }

      if (modelId != null) {
        query = query.eq('model_id', modelId);
      }

      final productsResponse = await query.order('created_at', ascending: false);

      // First, filter products by active sellers
      final List<Map<String, dynamic>> activeProducts = [];
      final List<String> activeProductIds = [];
      
      for (var product in productsResponse) {
        final sellerData = product['sellers'] as Map<String, dynamic>?;
        final userData = sellerData?['users'] as Map<String, dynamic>?;
        final isActive = userData?['is_active'] as bool? ?? false;
        final approvalStatus = sellerData?['approval_status'] as String? ?? 'pending';
        final userRole = userData?['role'] as String?;
        final isAdminProduct = userRole == 'admin';
        
        // Only include products from approved and active sellers
        // Admin products should always be shown regardless of approval status
        if (isAdminProduct || (isActive && approvalStatus == 'approved')) {
          activeProducts.add(product);
          activeProductIds.add(product['id'] as String);
        }
      }

      if (activeProductIds.isEmpty) {
        emit(ProductsLoaded(products: []));
        return;
      }

      // Batch fetch all images and ratings in parallel
      final Map<String, String?> productImages = {};
      final Map<String, double> productRatings = {};
      
      // Create a set for faster lookup
      final activeProductIdsSet = activeProductIds.toSet();
      
      // Fetch images and ratings in parallel
      final results = await Future.wait([
        // Fetch all images
        _supabase
            .from('product_images')
            .select('product_id, image_url, display_order')
            .order('display_order', ascending: true)
            .then((response) {
              // Filter and group by product_id, take first image for each
              final Map<String, String?> images = {};
              for (var img in response) {
                final pid = img['product_id'] as String;
                if (activeProductIdsSet.contains(pid) && !images.containsKey(pid)) {
                  images[pid] = img['image_url'] as String?;
                }
              }
              return images;
            }).catchError((e) {
              print('Error fetching images: $e');
              return <String, String?>{};
            }),
        
        // Fetch all ratings
        _supabase
            .from('product_ratings')
            .select('product_id, rating')
            .then((response) {
              // Group by product_id and calculate average
              final Map<String, List<double>> ratingsByProduct = {};
              for (var rating in response) {
                final pid = rating['product_id'] as String;
                final ratingValue = ((rating['rating'] as num?) ?? 0.0).toDouble();
                if (activeProductIdsSet.contains(pid)) {
                  ratingsByProduct.putIfAbsent(pid, () => []).add(ratingValue);
                }
              }
              
              // Calculate averages
              final Map<String, double> averages = {};
              ratingsByProduct.forEach((pid, ratings) {
                if (ratings.isNotEmpty) {
                  averages[pid] = ratings.reduce((a, b) => a + b) / ratings.length;
                }
              });
              return averages;
            }).catchError((e) {
              print('Error fetching ratings: $e');
              return <String, double>{};
            }),
      ]);

      productImages.addAll(results[0] as Map<String, String?>);
      productRatings.addAll(results[1] as Map<String, double>);

      // Build final products list
      final List<Map<String, dynamic>> productsWithDetails = [];
      
      for (var product in activeProducts) {
        final productId = product['id'] as String;
        
        // Format price
        final price = product['price'] as num? ?? 0.0;
        final priceType = product['price_types'] as Map<String, dynamic>?;
        final currency = priceType?['name'] as String? ?? 'PKR';
        final priceString = price.toStringAsFixed(0);
        final formattedPriceValue = priceString.replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
        final formattedPrice = '$currency $formattedPriceValue';

        productsWithDetails.add({
          'id': productId,
          'name': product['name'] as String? ?? '',
          'price': formattedPrice,
          'image': productImages[productId],
          'rating': productRatings[productId] ?? 0.0,
          'product': product, // Store full product data for navigation
        });
      }

      emit(ProductsLoaded(products: productsWithDetails));
    } catch (e) {
      emit(ProductsError('Failed to load products: ${e.toString()}'));
    }
  }

  Future<void> _processProducts(List<dynamic> productsResponse) async {
    // Fetch images and ratings for each product, filter by active sellers
    final List<Map<String, dynamic>> productsWithDetails = [];
    
    for (var product in productsResponse) {
      // Filter: only include products from approved and active sellers
      // Admin products should always be shown regardless of approval status
      final sellerData = product['sellers'] as Map<String, dynamic>?;
      final userData = sellerData?['users'] as Map<String, dynamic>?;
      final isActive = userData?['is_active'] as bool? ?? false;
      final approvalStatus = sellerData?['approval_status'] as String? ?? 'pending';
      final userRole = userData?['role'] as String?;
      final isAdminProduct = userRole == 'admin';
      
      // Skip products from blocked or rejected sellers (unless it's an admin product)
      if (!isAdminProduct && (!isActive || approvalStatus != 'approved')) {
        continue;
      }
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

      // Fetch average rating from product_ratings
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
      final currency = priceType?['name'] as String? ?? 'PKR';
      final priceString = price.toStringAsFixed(0);
      final formattedPriceValue = priceString.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
      final formattedPrice = '$currency $formattedPriceValue';

      productsWithDetails.add({
        'id': productId,
        'name': product['name'] as String? ?? '',
        'price': formattedPrice,
        'image': firstImage,
        'rating': averageRating,
        'product': product, // Store full product data for navigation
      });
    }

    emit(ProductsLoaded(products: productsWithDetails));
  }
}

