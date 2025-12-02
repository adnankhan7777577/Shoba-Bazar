import 'package:supabase_flutter/supabase_flutter.dart';

class BannerService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String bannerImageStorageBucket = 'banner-images';

  /// Get admin user ID from the current authenticated user
  Future<String?> getAdminUserId() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final userResponse = await _supabase
          .from('users')
          .select('id')
          .eq('auth_id', user.id)
          .single();

      return userResponse['id'] as String;
    } catch (e) {
      print('Error loading admin user ID: $e');
      return null;
    }
  }

  /// Load all banners (for admin)
  Future<List<Map<String, dynamic>>> loadBanners() async {
    try {
      final response = await _supabase
          .from('banners')
          .select('*')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      print('Error loading banners: $e');
      return [];
    }
  }

  /// Load active banners (for customer dashboard - public access)
  Future<List<Map<String, dynamic>>> loadActiveBanners() async {
    try {
      final response = await _supabase
          .from('banners')
          .select('*')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      print('Error loading active banners: $e');
      return [];
    }
  }

  /// Create a new banner
  Future<Map<String, dynamic>?> createBanner({
    required String imageUrl,
    required String text,
    required String userId,
  }) async {
    try {
      final response = await _supabase
          .from('banners')
          .insert({
            'image_url': imageUrl,
            'text': text,
            'user_id': userId,
          })
          .select()
          .single();

      return Map<String, dynamic>.from(response);
    } catch (e) {
      print('Error creating banner: $e');
      return null;
    }
  }

  /// Update a banner
  Future<Map<String, dynamic>?> updateBanner({
    required String bannerId,
    String? imageUrl,
    String? text,
  }) async {
    try {
      final Map<String, dynamic> updateData = {};
      if (imageUrl != null) updateData['image_url'] = imageUrl;
      if (text != null) updateData['text'] = text;

      if (updateData.isEmpty) return null;

      final response = await _supabase
          .from('banners')
          .update(updateData)
          .eq('id', bannerId)
          .select()
          .single();

      return Map<String, dynamic>.from(response);
    } catch (e) {
      print('Error updating banner: $e');
      return null;
    }
  }

  /// Delete a banner
  Future<bool> deleteBanner(String bannerId) async {
    try {
      // First, get the banner to extract image URL for deletion
      final bannerResponse = await _supabase
          .from('banners')
          .select('image_url')
          .eq('id', bannerId)
          .single();

      // Delete from database
      await _supabase
          .from('banners')
          .delete()
          .eq('id', bannerId);

      // Try to delete image from storage
      final imageUrl = bannerResponse['image_url'] as String?;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          // Extract filename from URL
          final fileName = imageUrl.split('/').last.split('?').first;
          await _supabase.storage
              .from(bannerImageStorageBucket)
              .remove([fileName]);
        } catch (e) {
          print('Error deleting banner image from storage: $e');
          // Continue even if storage deletion fails
        }
      }

      return true;
    } catch (e) {
      print('Error deleting banner: $e');
      return false;
    }
  }

  /// Upload banner image to storage
  Future<String?> uploadBannerImage(dynamic imageFile) async {
    try {
      final fileName = 'banner-${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      await _supabase.storage
          .from(bannerImageStorageBucket)
          .upload(fileName, imageFile, fileOptions: const FileOptions(
            upsert: false,
            contentType: 'image/jpeg',
          ));

      final imageUrl = _supabase.storage
          .from(bannerImageStorageBucket)
          .getPublicUrl(fileName);

      return imageUrl;
    } catch (e) {
      print('Error uploading banner image: $e');
      return null;
    }
  }
}

