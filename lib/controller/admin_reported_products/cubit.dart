import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'state.dart';

class AdminReportedProductsCubit extends Cubit<AdminReportedProductsState> {
  AdminReportedProductsCubit() : super(const AdminReportedProductsInitial());

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> fetchReportedProducts() async {
    emit(const AdminReportedProductsLoading());

    try {
      // Fetch all product reports with related data
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

      // Extract all product IDs for batch queries
      final List<String> productIds = [];
      final List<Map<String, dynamic>> validReports = [];
      
      for (var report in reportsResponse) {
        final product = report['products'] as Map<String, dynamic>?;
        if (product != null) {
          final productId = product['id'] as String?;
          if (productId != null) {
            productIds.add(productId);
            validReports.add(report);
          }
        }
      }

      // Batch fetch all images and ratings in parallel for all products at once
      final Map<String, String?> productImages = {};
      final Map<String, double?> productRatings = {};
      
      if (productIds.isNotEmpty) {
        final results = await Future.wait([
          // Batch fetch all images for all products
          _supabase
              .from('product_images')
              .select('product_id, image_url, display_order')
              .inFilter('product_id', productIds)
              .order('display_order', ascending: true),
          
          // Batch fetch all ratings for all products
          _supabase
              .from('product_ratings')
              .select('product_id, rating')
              .inFilter('product_id', productIds),
        ]);

        final allImagesResponse = results[0] as List;
        final allRatingsResponse = results[1] as List;

        // Group images by product_id and get first image
        final Map<String, List<Map<String, dynamic>>> imagesByProduct = {};
        for (var image in allImagesResponse) {
          final imageMap = image as Map<String, dynamic>;
          final productId = imageMap['product_id'] as String;
          if (!imagesByProduct.containsKey(productId)) {
            imagesByProduct[productId] = [];
          }
          imagesByProduct[productId]!.add(imageMap);
        }
        
        // Get first image for each product
        for (var entry in imagesByProduct.entries) {
          final sortedImages = entry.value
            ..sort((a, b) {
              final aOrder = a['display_order'] as int? ?? 999;
              final bOrder = b['display_order'] as int? ?? 999;
              return aOrder.compareTo(bOrder);
            });
          if (sortedImages.isNotEmpty) {
            productImages[entry.key] = sortedImages[0]['image_url'] as String?;
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
        
        // Calculate average ratings
        for (var entry in ratingsByProduct.entries) {
          if (entry.value.isNotEmpty) {
            productRatings[entry.key] = entry.value.reduce((a, b) => a + b) / entry.value.length;
          }
        }
      }

      final List<Map<String, dynamic>> formattedProducts = [];

      for (var report in validReports) {
        final product = report['products'] as Map<String, dynamic>?;
        final customer = report['customers'] as Map<String, dynamic>?;
        final customerUser = customer?['users'] as Map<String, dynamic>?;
        final seller = product?['sellers'] as Map<String, dynamic>?;
        final sellerUser = seller?['users'] as Map<String, dynamic>?;

        final productId = product!['id'] as String;

        // Get pre-fetched image and rating
        final firstImage = productImages[productId];
        final averageRating = productRatings[productId];

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
          'reportId': report['id'] as String?,
          'productId': productId,
          'productName': product['name'] as String? ?? 'Unknown Product',
          'price': formattedPrice,
          'rating': averageRating,
          'image': firstImage,
          'resolved': report['resolved'] as bool? ?? false,
          'reporter': {
            'id': customerUser?['id'] as String?,
            'name': customerUser?['name'] as String? ?? 'Unknown Customer',
            'email': customerUser?['email'] as String?,
            'mobile': customerUser?['mobile'] as String?,
            'avatar': customerUser?['profile_picture_url'] as String?,
            'reason': report['reason'] as String? ?? '',
            'reportDate': formattedDate,
          },
          'seller': {
            'id': sellerUser?['id'] as String?,
            'name': sellerUser?['name'] as String? ?? 'Unknown Seller',
            'email': sellerUser?['email'] as String?,
            'phone': sellerUser?['mobile'] as String?,
            'whatsapp': seller?['whatsapp'] as String?,
            'avatar': sellerUser?['profile_picture_url'] as String?,
          },
        });
      }

      emit(AdminReportedProductsLoaded(reportedProducts: formattedProducts));
    } catch (e) {
      emit(AdminReportedProductsError('Failed to load reported products: ${e.toString()}'));
    }
  }
}

