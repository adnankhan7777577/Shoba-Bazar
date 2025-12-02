import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSellerListService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Load all sellers with their user information, excluding admins
  Future<List<Map<String, dynamic>>> loadSellers() async {
    try {
      final sellersResponse = await _supabase
          .from('sellers')
          .select('''
            id,
            shop_address,
            whatsapp,
            is_verified,
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
            continue;
          }
          
          final isActive = userData['is_active'] as bool? ?? true;
          
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
            'isBlocked': !isActive,
            'is_active': isActive,
          });
        }
      }

      return sellersWithDetails;
    } catch (e) {
      print('Error loading sellers: $e');
      return [];
    }
  }

  /// Filter sellers based on filter and search query
  static List<Map<String, dynamic>> filterSellers(
    List<Map<String, dynamic>> sellers,
    String filter, // 'All' or 'Blocked'
    String query,
  ) {
    List<Map<String, dynamic>> filtered = sellers;
    
    if (filter == 'Blocked') {
      filtered = filtered.where((seller) => (seller['isBlocked'] as bool? ?? false) == true).toList();
    }
    
    if (query.isNotEmpty) {
      final searchQuery = query.toLowerCase();
      filtered = filtered.where((seller) =>
          (seller['name'] as String? ?? '').toLowerCase().contains(searchQuery) ||
          (seller['email'] as String? ?? '').toLowerCase().contains(searchQuery) ||
          (seller['phone'] as String? ?? '').toLowerCase().contains(searchQuery)
      ).toList();
    }
    
    return filtered;
  }

  /// Block a seller (set is_active to false)
  Future<void> blockSeller(String sellerId) async {
    try {
      // Get user_id from seller
      final sellerResponse = await _supabase
          .from('sellers')
          .select('user_id')
          .eq('id', sellerId)
          .single();

      final userId = sellerResponse['user_id'] as String;

      // Update user is_active to false
      await _supabase
          .from('users')
          .update({'is_active': false})
          .eq('id', userId);
    } catch (e) {
      print('Error blocking seller: $e');
      rethrow;
    }
  }

  /// Unblock a seller (set is_active to true)
  Future<void> unblockSeller(String sellerId) async {
    try {
      // Get user_id from seller
      final sellerResponse = await _supabase
          .from('sellers')
          .select('user_id')
          .eq('id', sellerId)
          .single();

      final userId = sellerResponse['user_id'] as String;

      // Update user is_active to true
      await _supabase
          .from('users')
          .update({'is_active': true})
          .eq('id', userId);
    } catch (e) {
      print('Error unblocking seller: $e');
      rethrow;
    }
  }
}

