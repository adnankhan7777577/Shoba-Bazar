import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'state.dart';

class CustomerFavoritesCubit extends Cubit<CustomerFavoritesState> {
  CustomerFavoritesCubit() : super(const CustomerFavoritesInitial());

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> fetchFavorites() async {
    emit(const CustomerFavoritesLoading());

    try {
      // Get current user
      final user = _supabase.auth.currentUser;
      if (user == null) {
        emit(const CustomerFavoritesError('User not logged in'));
        return;
      }

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

      final customerId = customerResponse['id'] as String;

      // Fetch favorite products, only from active sellers
      final favoritesResponse = await _supabase
          .from('product_favorites')
          .select('''
            product_id,
            products(
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
              sellers(user_id, approval_status, users(is_active, role))
            )
          ''')
          .eq('customer_id', customerId)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> favoriteItems = [];

      for (var favorite in favoritesResponse) {
        final productData = favorite['products'] as Map<String, dynamic>?;
        if (productData == null) continue;

        // Filter: only include products from approved and active sellers
        // Admin products should always be shown regardless of approval status
        final sellerData = productData['sellers'] as Map<String, dynamic>?;
        final userData = sellerData?['users'] as Map<String, dynamic>?;
        final isActive = userData?['is_active'] as bool? ?? false;
        final approvalStatus = sellerData?['approval_status'] as String? ?? 'pending';
        final userRole = userData?['role'] as String?;
        final isAdminProduct = userRole == 'admin';
        
        // Skip products from blocked or rejected sellers (unless it's an admin product)
        if (!isAdminProduct && (!isActive || approvalStatus != 'approved')) {
          continue;
        }

        final productId = productData['id'] as String;

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
        final price = productData['price'] as num? ?? 0.0;
        final priceType = productData['price_types'] as Map<String, dynamic>?;
        final currency = priceType?['name'] as String? ?? 'PKR';
        final priceString = price.toStringAsFixed(0);
        final formattedPriceValue = priceString.replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
        final formattedPrice = '$currency $formattedPriceValue';

        favoriteItems.add({
          'id': productId,
          'name': productData['name'] as String? ?? '',
          'price': formattedPrice,
          'rating': averageRating,
          'image': firstImage,
          'isFavorite': true,
          'product': productData, // Store full product data for navigation
        });
      }

      emit(CustomerFavoritesLoaded(favorites: favoriteItems));
    } catch (e) {
      emit(CustomerFavoritesError('Failed to load favorites: ${e.toString()}'));
    }
  }
}

