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

