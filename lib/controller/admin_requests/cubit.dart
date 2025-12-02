import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'state.dart';

class AdminRequestsCubit extends Cubit<AdminRequestsState> {
  AdminRequestsCubit() : super(const AdminRequestsInitial());

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> fetchRequests() async {
    emit(const AdminRequestsLoading());

    try {
      // Fetch all sellers with their user data, excluding admins
      final sellersResponse = await _supabase
          .from('sellers')
          .select('''
            id,
            user_id,
            whatsapp,
            shop_address,
            approval_status,
            created_at,
            users(
              id,
              name,
              email,
              mobile,
              country,
              city,
              profile_picture_url,
              role
            )
          ''')
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> requests = [];
      
      for (var seller in sellersResponse) {
        final userData = seller['users'] as Map<String, dynamic>?;
        if (userData == null) continue;

        // Only include users with role 'seller' - exclude admins
        final userRole = userData['role'] as String?;
        
        // Skip if role is 'admin' or if role is not 'seller'
        if (userRole != 'seller') {
          continue; // Skip admin profiles and other non-seller roles
        }

        final approvalStatus = seller['approval_status'] as String? ?? 'pending';
        final createdAt = seller['created_at'] as String? ?? '';
        
        // Format date
        String formattedDate = '';
        if (createdAt.isNotEmpty) {
          try {
            final date = DateTime.parse(createdAt);
            formattedDate = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          } catch (e) {
            formattedDate = createdAt;
          }
        }

        requests.add({
          'id': seller['id'] as String?,
          'seller_id': seller['id'] as String?,
          'user_id': seller['user_id'] as String?,
          'sellerName': userData['name'] as String? ?? 'Unknown Seller',
          'email': userData['email'] as String? ?? '',
          'phone': userData['mobile'] as String? ?? '',
          'address': seller['shop_address'] as String? ?? 'Not provided',
          'country': userData['country'] as String? ?? 'Not provided',
          'city': userData['city'] as String? ?? 'Not provided',
          'whatsapp': seller['whatsapp'] as String? ?? '',
          'shop_address': seller['shop_address'] as String? ?? '',
          'status': approvalStatus,
          'requestDate': formattedDate,
          'profile_picture_url': userData['profile_picture_url'] as String?,
        });
      }

      emit(AdminRequestsLoaded(requests: requests));
    } catch (e) {
      emit(AdminRequestsError('Failed to load requests: ${e.toString()}'));
    }
  }
}

