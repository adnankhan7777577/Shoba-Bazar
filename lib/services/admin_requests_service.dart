import 'package:supabase_flutter/supabase_flutter.dart';

class AdminRequestsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Load all seller requests with their user data, excluding admins
  Future<List<Map<String, dynamic>>> loadRequests() async {
    try {
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

      return requests;
    } catch (e) {
      print('Error loading requests: $e');
      return [];
    }
  }

  /// Filter requests based on search query
  static List<Map<String, dynamic>> filterRequests(
    List<Map<String, dynamic>> requests,
    String query,
  ) {
    if (query.isEmpty) {
      return requests;
    }
    
    final searchQuery = query.toLowerCase();
    return requests.where((request) {
      final sellerName = (request['sellerName'] as String? ?? '').toLowerCase();
      final email = (request['email'] as String? ?? '').toLowerCase();
      return sellerName.contains(searchQuery) || email.contains(searchQuery);
    }).toList();
  }

  /// Approve a seller request
  Future<void> approveSeller(String sellerId) async {
    try {
      await _supabase
          .from('sellers')
          .update({'approval_status': 'approved'})
          .eq('id', sellerId);
    } catch (e) {
      print('Error approving seller: $e');
      rethrow;
    }
  }

  /// Reject a seller request
  Future<void> rejectSeller(String sellerId) async {
    try {
      await _supabase
          .from('sellers')
          .update({'approval_status': 'rejected'})
          .eq('id', sellerId);
    } catch (e) {
      print('Error rejecting seller: $e');
      rethrow;
    }
  }
}

