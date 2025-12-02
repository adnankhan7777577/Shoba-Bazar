import 'package:supabase_flutter/supabase_flutter.dart';

class AdminReportedProductsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Load all reported products with related data
  Future<List<Map<String, dynamic>>> loadReportedProducts() async {
    try {
      final reportsResponse = await _supabase
          .from('product_reports')
          .select('''
            id,
            reason,
            resolved,
            created_at,
            product_id,
            customer_id,
            products(
              id,
              name,
              price,
              seller_id,
              price_types(name),
              sellers(
                user_id,
                whatsapp,
                users(
                  id,
                  name,
                  email,
                  mobile,
                  profile_picture_url
                )
              )
            ),
            customers(
              user_id,
              users(
                id,
                name,
                email,
                mobile,
                profile_picture_url
              )
            )
          ''')
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> formattedProducts = [];

      for (var report in reportsResponse) {
        final product = report['products'] as Map<String, dynamic>?;
        final customer = report['customers'] as Map<String, dynamic>?;
        final customerUser = customer?['users'] as Map<String, dynamic>?;
        final seller = product?['sellers'] as Map<String, dynamic>?;
        final sellerUser = seller?['users'] as Map<String, dynamic>?;

        if (product == null) continue;

        final productId = product['id'] as String?;
        if (productId == null) continue;

        // Fetch product images
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
        double? averageRating;
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
          // Rating calculation failed, rating will be null
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

        // Format date
        final createdAt = report['created_at'] as String?;
        String formattedDate = 'N/A';
        if (createdAt != null) {
          try {
            final date = DateTime.parse(createdAt);
            final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
            formattedDate = '${date.day} ${months[date.month - 1]} ${date.year}';
          } catch (e) {
            formattedDate = createdAt;
          }
        }

        formattedProducts.add({
          'id': report['id'] as String?,
          'product_id': productId,
          'product_name': product['name'] as String? ?? 'Unknown Product',
          'product_price': formattedPrice,
          'product_image': firstImage,
          'product_rating': averageRating,
          'reason': report['reason'] as String? ?? 'No reason provided',
          'resolved': report['resolved'] as bool? ?? false,
          'created_at': formattedDate,
          'customer_name': customerUser?['name'] as String? ?? 'Unknown Customer',
          'customer_email': customerUser?['email'] as String? ?? '',
          'customer_phone': customerUser?['mobile'] as String? ?? '',
          'customer_profile_picture': customerUser?['profile_picture_url'] as String?,
          'seller_name': sellerUser?['name'] as String? ?? 'Unknown Seller',
          'seller_email': sellerUser?['email'] as String? ?? '',
          'seller_phone': sellerUser?['mobile'] as String? ?? '',
          'seller_profile_picture': sellerUser?['profile_picture_url'] as String?,
          'seller_whatsapp': seller?['whatsapp'] as String?,
        });
      }

      return formattedProducts;
    } catch (e) {
      print('Error loading reported products: $e');
      return [];
    }
  }

  /// Filter reported products based on search query
  static List<Map<String, dynamic>> filterReportedProducts(
    List<Map<String, dynamic>> products,
    String query,
  ) {
    if (query.isEmpty) {
      return products;
    }
    
    final searchQuery = query.toLowerCase();
    return products.where((product) {
      final productName = (product['product_name'] as String? ?? '').toLowerCase();
      final customerName = (product['customer_name'] as String? ?? '').toLowerCase();
      final sellerName = (product['seller_name'] as String? ?? '').toLowerCase();
      final reason = (product['reason'] as String? ?? '').toLowerCase();
      
      return productName.contains(searchQuery) ||
             customerName.contains(searchQuery) ||
             sellerName.contains(searchQuery) ||
             reason.contains(searchQuery);
    }).toList();
  }
}

