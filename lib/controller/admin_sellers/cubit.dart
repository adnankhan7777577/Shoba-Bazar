import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'state.dart';

class AdminSellersCubit extends Cubit<AdminSellersState> {
  AdminSellersCubit() : super(const AdminSellersInitial());

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> fetchSellers() async {
    emit(const AdminSellersLoading());

    try {
      // Fetch all sellers with their user information, excluding admins
      final sellersResponse = await _supabase
          .from('sellers')
          .select('''
            id,
            shop_address,
            whatsapp,
            is_verified,
            approval_status,
            user_id,
            users(
              id,
              name,
              email,
              mobile,
              city,
              country,
              profile_picture_url,
              role,
              is_active
            )
          ''')
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> sellersWithDetails = [];
      
      for (var seller in sellersResponse) {
        final userData = seller['users'] as Map<String, dynamic>?;
        
        // Only include users with role 'seller' - exclude admins
        if (userData != null) {
          final userRole = userData['role'] as String?;
          
          // Skip if role is 'admin' or if role is not 'seller'
          if (userRole != 'seller') {
            continue; // Skip admin profiles and other non-seller roles
          }
          
          final isActive = userData['is_active'] as bool? ?? true;
          final approvalStatus = seller['approval_status'] as String? ?? 'pending';
          
          // Skip rejected sellers - don't display them
          if (approvalStatus == 'rejected') {
            continue;
          }
          
          sellersWithDetails.add({
            'id': seller['id'],
            'name': userData['name'] as String? ?? 'Unknown Seller',
            'email': userData['email'] as String? ?? '',
            'phone': userData['mobile'] as String? ?? '',
            'shop_address': seller['shop_address'] as String? ?? '',
            'home_address': '${userData['city'] as String? ?? ''}, ${userData['country'] as String? ?? ''}'.trim().replaceAll(RegExp(r'^,\s*|,\s*$'), ''),
            'city': userData['city'] as String? ?? '',
            'country': userData['country'] as String? ?? '',
            'profile_picture_url': userData['profile_picture_url'] as String?,
            'whatsapp': seller['whatsapp'] as String? ?? '',
            'is_verified': seller['is_verified'] as bool? ?? false,
            'isBlocked': !isActive, // Blocked if is_active is false
            'is_active': isActive,
            'approval_status': approvalStatus,
          });
        }
      }

      emit(AdminSellersLoaded(sellers: sellersWithDetails));
    } catch (e) {
      emit(AdminSellersError('Failed to load sellers: ${e.toString()}'));
    }
  }
}

