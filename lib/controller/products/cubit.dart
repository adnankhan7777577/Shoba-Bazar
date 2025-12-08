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

      final searchQuery = query.trim().toLowerCase();
      final searchWords = searchQuery.split(' ').where((w) => w.isNotEmpty).toList();
      
      // Collect all matching IDs for brands, categories, and models
      Set<String> brandIds = {};
      Set<String> categoryIds = {};
      Set<String> modelIds = {};
      
      // Search for each word in the query to find matches
      for (final word in searchWords) {
        // Search brands
        final brandsResponse = await _supabase
            .from('product_brands')
            .select('id')
            .ilike('name', '%$word%')
            .limit(10);
        brandIds.addAll(brandsResponse.map((brand) => brand['id'] as String));
        
        // Search categories
        final categoriesResponse = await _supabase
            .from('product_categories')
            .select('id')
            .ilike('name', '%$word%')
            .limit(10);
        categoryIds.addAll(categoriesResponse.map((cat) => cat['id'] as String));
        
        // Search models
        final modelsResponse = await _supabase
            .from('product_models')
            .select('id')
            .ilike('name', '%$word%')
            .limit(10);
        modelIds.addAll(modelsResponse.map((model) => model['id'] as String));
      }
      
      // Also search for the full query string
      final fullBrandsResponse = await _supabase
          .from('product_brands')
          .select('id')
          .ilike('name', '%$searchQuery%')
          .limit(10);
      brandIds.addAll(fullBrandsResponse.map((brand) => brand['id'] as String));
      
      final fullCategoriesResponse = await _supabase
          .from('product_categories')
          .select('id')
          .ilike('name', '%$searchQuery%')
          .limit(10);
      categoryIds.addAll(fullCategoriesResponse.map((cat) => cat['id'] as String));
      
      final fullModelsResponse = await _supabase
          .from('product_models')
          .select('id')
          .ilike('name', '%$searchQuery%')
          .limit(10);
      modelIds.addAll(fullModelsResponse.map((model) => model['id'] as String));
      
      // Build OR conditions for comprehensive search
      List<String> orConditions = [];
      
      // Always search in product name (both full query and individual words)
      orConditions.add('name.ilike.%$searchQuery%');
      for (final word in searchWords) {
        if (word.length >= 2) { // Only search words with 2+ characters
          orConditions.add('name.ilike.%$word%');
        }
      }
      
      // If brand matches found, include them
      if (brandIds.isNotEmpty) {
        orConditions.add('brand_id.in.(${brandIds.join(',')})');
      }
      
      // If category matches found, include them
      if (categoryIds.isNotEmpty) {
        orConditions.add('category_id.in.(${categoryIds.join(',')})');
      }
      
      // If model matches found, include them
      if (modelIds.isNotEmpty) {
        orConditions.add('model_id.in.(${modelIds.join(',')})');
      }
      
      // Build the query with all OR conditions
      var queryBuilder = _supabase
          .from('products')
          .select('''
            id,
            name,
            price,
            description,
            seller_id,
            category_id,
            brand_id,
            model_id,
            price_types(name),
            product_categories(name),
            product_brands(name),
            product_types(name),
            product_models(name),
            product_years(year),
            sellers(user_id, approval_status, users(is_active, role))
          ''')
          .or(orConditions.join(','))
          .order('created_at', ascending: false)
          .limit(limit);

      final productsResponse = await queryBuilder;
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
    // First, filter products by active sellers
    final List<Map<String, dynamic>> activeProducts = [];
    final List<String> activeProductIds = [];
    
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
      if (isAdminProduct || (isActive && approvalStatus == 'approved')) {
        activeProducts.add(product);
        activeProductIds.add(product['id'] as String);
      }
    }

    if (activeProductIds.isEmpty) {
      emit(ProductsLoaded(products: []));
      return;
    }

    // Batch fetch all images and ratings in parallel for better performance
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
          .inFilter('product_id', activeProductIds)
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
          .inFilter('product_id', activeProductIds)
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
  }
}

