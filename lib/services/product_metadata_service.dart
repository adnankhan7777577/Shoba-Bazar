import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class CategoryInUseException implements Exception {
  final String message;
  const CategoryInUseException([this.message = 'This category is currently in use.']);

  @override
  String toString() => message;
}

class BrandInUseException implements Exception {
  final String message;
  const BrandInUseException([this.message = 'This brand is currently in use.']);

  @override
  String toString() => message;
}

class TypeInUseException implements Exception {
  final String message;
  const TypeInUseException([this.message = 'This type is currently in use.']);

  @override
  String toString() => message;
}

class ModelInUseException implements Exception {
  final String message;
  const ModelInUseException([this.message = 'This model is currently in use.']);

  @override
  String toString() => message;
}

class ProductMetadataService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Storage bucket names
  static const String categoryImageStorageBucket = 'category-images';
  static const String brandImageStorageBucket = 'brand-images';

  // Get current user ID from users table
  Future<String?> _getCurrentUserId() async {
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
      print('Error getting current user ID: $e');
      return null;
    }
  }

  // ============ CATEGORIES ============
  // For sellers: only show categories they created
  // For admin: show all categories
  Future<List<Map<String, dynamic>>> fetchCategories({bool isAdmin = false}) async {
    try {
      var query = _supabase
          .from('product_categories')
          .select('id, name, image, user_id');
      
      // For sellers, only show their own categories
      if (!isAdmin) {
        final userId = await _getCurrentUserId();
        if (userId == null) {
          return [];
        }
        query = query.eq('user_id', userId);
      }
      
      final response = await query.order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching categories: $e');
      return [];
    }
  }
  
  // Fetch ALL categories (for use when adding types - sellers can add types to any category)
  Future<List<Map<String, dynamic>>> fetchAllCategories() async {
    try {
      final response = await _supabase
          .from('product_categories')
          .select('id, name, image, user_id')
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching all categories: $e');
      return [];
    }
  }

  Future<String?> addCategory(String name, {File? imageFile}) async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) {
        print('Error: User not authenticated');
        return null;
      }

      // Validate: Image is required
      if (imageFile == null) {
        throw Exception('Category image is required');
      }

      // Validate: Name must be text (not just numbers)
      if (_isOnlyNumbers(name.trim())) {
        throw Exception('Category name cannot be only numbers. Please enter a text name.');
      }

      String? imageUrl;
      
      try {
        final fileName = 'category-${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _supabase.storage
            .from(categoryImageStorageBucket)
            .upload(fileName, imageFile, fileOptions: const FileOptions(
              upsert: false,
              contentType: 'image/jpeg',
            ));
        imageUrl = _supabase.storage
            .from(categoryImageStorageBucket)
            .getPublicUrl(fileName);
      } catch (e) {
        print('Error uploading category image: $e');
        throw Exception('Failed to upload category image');
      }
      
      final data = {
        'name': name.trim(),
        'user_id': userId,
        'image': imageUrl,
      };
      
      final response = await _supabase
          .from('product_categories')
          .insert(data)
          .select('id')
          .single();
      return response['id'] as String?;
    } catch (e) {
      print('Error adding category: $e');
      rethrow;
    }
  }

  // Helper method to check if string contains only numbers
  bool _isOnlyNumbers(String text) {
    if (text.isEmpty) return false;
    // Check if the text contains only digits (and possibly spaces)
    final numericOnly = text.replaceAll(RegExp(r'\s+'), '');
    return numericOnly.isNotEmpty && numericOnly.split('').every((char) => RegExp(r'^\d+$').hasMatch(char));
  }

  Future<bool> updateCategory(String id, String name, {File? imageFile, String? existingImageUrl, bool isAdmin = false}) async {
    try {
      // Check ownership for sellers
      if (!isAdmin) {
        final userId = await _getCurrentUserId();
        if (userId == null) return false;
        
        final category = await _supabase
            .from('product_categories')
            .select('user_id')
            .eq('id', id)
            .maybeSingle();
        
        if (category == null || category['user_id'] != userId) {
          print('Error: User does not own this category');
          return false;
        }
      }

      // Validate: Name must be text (not just numbers)
      if (_isOnlyNumbers(name.trim())) {
        throw Exception('Category name cannot be only numbers. Please enter a text name.');
      }

      // Validate: Image is required (either existing or new)
      String? imageUrl = existingImageUrl;
      
      if (imageFile != null) {
        try {
          // Delete old image if exists
          if (existingImageUrl != null && existingImageUrl.isNotEmpty) {
            try {
              final oldFileName = existingImageUrl.split('/').last.split('?').first;
              await _supabase.storage
                  .from(categoryImageStorageBucket)
                  .remove([oldFileName]);
            } catch (e) {
              print('Error deleting old category image: $e');
            }
          }
          
          // Upload new image
          final fileName = 'category-${DateTime.now().millisecondsSinceEpoch}.jpg';
          await _supabase.storage
              .from(categoryImageStorageBucket)
              .upload(fileName, imageFile, fileOptions: const FileOptions(
                upsert: false,
                contentType: 'image/jpeg',
              ));
          imageUrl = _supabase.storage
              .from(categoryImageStorageBucket)
              .getPublicUrl(fileName);
        } catch (e) {
          print('Error uploading category image: $e');
          throw Exception('Failed to upload category image');
        }
      }
      
      // Ensure image exists (either existing or newly uploaded)
      if (imageUrl == null || imageUrl.isEmpty) {
        throw Exception('Category image is required');
      }
      
      final data = {
        'name': name.trim(),
        'image': imageUrl,
      };
      
      await _supabase
          .from('product_categories')
          .update(data)
          .eq('id', id);
      return true;
    } catch (e) {
      print('Error updating category: $e');
      rethrow;
    }
  }

  Future<bool> deleteCategory(String id, {String? imageUrl, bool isAdmin = false}) async {
    try {
      // Check ownership for sellers
      if (!isAdmin) {
        final userId = await _getCurrentUserId();
        if (userId == null) return false;
        
        final category = await _supabase
            .from('product_categories')
            .select('user_id')
            .eq('id', id)
            .maybeSingle();
        
        if (category == null || category['user_id'] != userId) {
          print('Error: User does not own this category');
          return false;
        }
      }

      // Delete image from storage if exists
      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          final fileName = imageUrl.split('/').last.split('?').first;
          await _supabase.storage
              .from(categoryImageStorageBucket)
              .remove([fileName]);
        } catch (e) {
          print('Error deleting category image: $e');
        }
      }
      
      await _supabase
          .from('product_categories')
          .delete()
          .eq('id', id);
      return true;
    } on PostgrestException catch (e) {
      if (e.code == '23503') {
        throw const CategoryInUseException(
          'This category is associated with existing products and cannot be deleted directly.',
        );
      }
      print('Postgrest error deleting category: ${e.message}');
      return false;
    } catch (e) {
      print('Error deleting category: $e');
      return false;
    }
  }

  // ============ BRANDS ============
  Future<List<Map<String, dynamic>>> fetchBrands({bool isAdmin = false}) async {
    try {
      // For sellers, only show their own brands
      if (!isAdmin) {
        final userId = await _getCurrentUserId();
        if (userId == null) {
          return [];
        }
        final response = await _supabase
            .from('product_brands')
            .select('id, name, image, user_id')
            .eq('user_id', userId)
            .order('name');
        return List<Map<String, dynamic>>.from(response);
      } else {
        // Admin sees all brands
        final response = await _supabase
            .from('product_brands')
            .select('id, name, image, user_id')
            .order('name');
        return List<Map<String, dynamic>>.from(response);
      }
    } catch (e) {
      print('Error fetching brands: $e');
      return [];
    }
  }

  Future<String?> addBrand(String name, {File? imageFile}) async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) {
        print('Error: User not authenticated');
        return null;
      }

      // Validate: Image is required
      if (imageFile == null) {
        throw Exception('Brand image is required');
      }

      // Validate: Name must be text (not just numbers)
      if (_isOnlyNumbers(name.trim())) {
        throw Exception('Brand name cannot be only numbers. Please enter a text name.');
      }

      String? imageUrl;
      
      try {
        final fileName = 'brand-${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _supabase.storage
            .from(brandImageStorageBucket)
            .upload(fileName, imageFile, fileOptions: const FileOptions(
              upsert: false,
              contentType: 'image/jpeg',
            ));
        imageUrl = _supabase.storage
            .from(brandImageStorageBucket)
            .getPublicUrl(fileName);
      } catch (e) {
        print('Error uploading brand image: $e');
        throw Exception('Failed to upload brand image');
      }
      
      final data = {
        'name': name.trim(),
        'user_id': userId,
        'image': imageUrl,
      };
      
      final response = await _supabase
          .from('product_brands')
          .insert(data)
          .select('id')
          .single();
      return response['id'] as String?;
    } catch (e) {
      print('Error adding brand: $e');
      rethrow;
    }
  }

  Future<bool> updateBrand(String id, String name, {File? imageFile, String? existingImageUrl, bool isAdmin = false}) async {
    try {
      // Check ownership for sellers
      if (!isAdmin) {
        final userId = await _getCurrentUserId();
        if (userId == null) return false;
        
        final brand = await _supabase
            .from('product_brands')
            .select('user_id')
            .eq('id', id)
            .maybeSingle();
        
        if (brand == null || brand['user_id'] != userId) {
          print('Error: User does not own this brand');
          return false;
        }
      }

      // Validate: Name must be text (not just numbers)
      if (_isOnlyNumbers(name.trim())) {
        throw Exception('Brand name cannot be only numbers. Please enter a text name.');
      }

      // Validate: Image is required (either existing or new)
      String? imageUrl = existingImageUrl;
      
      if (imageFile != null) {
        try {
          // Delete old image if exists
          if (existingImageUrl != null && existingImageUrl.isNotEmpty) {
            try {
              final oldFileName = existingImageUrl.split('/').last.split('?').first;
              await _supabase.storage
                  .from(brandImageStorageBucket)
                  .remove([oldFileName]);
            } catch (e) {
              print('Error deleting old brand image: $e');
            }
          }
          
          // Upload new image
          final fileName = 'brand-${DateTime.now().millisecondsSinceEpoch}.jpg';
          await _supabase.storage
              .from(brandImageStorageBucket)
              .upload(fileName, imageFile, fileOptions: const FileOptions(
                upsert: false,
                contentType: 'image/jpeg',
              ));
          imageUrl = _supabase.storage
              .from(brandImageStorageBucket)
              .getPublicUrl(fileName);
        } catch (e) {
          print('Error uploading brand image: $e');
          throw Exception('Failed to upload brand image');
        }
      }
      
      // Ensure image exists (either existing or newly uploaded)
      if (imageUrl == null || imageUrl.isEmpty) {
        throw Exception('Brand image is required');
      }
      
      final data = {
        'name': name.trim(),
        'image': imageUrl,
      };
      
      await _supabase
          .from('product_brands')
          .update(data)
          .eq('id', id);
      return true;
    } catch (e) {
      print('Error updating brand: $e');
      return false;
    }
  }

  Future<bool> deleteBrand(String id, {String? imageUrl, bool isAdmin = false}) async {
    try {
      // Check ownership for sellers
      if (!isAdmin) {
        final userId = await _getCurrentUserId();
        if (userId == null) return false;
        
        final brand = await _supabase
            .from('product_brands')
            .select('user_id')
            .eq('id', id)
            .maybeSingle();
        
        if (brand == null || brand['user_id'] != userId) {
          print('Error: User does not own this brand');
          return false;
        }
      }

      // Delete image from storage if exists
      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          final fileName = imageUrl.split('/').last.split('?').first;
          await _supabase.storage
              .from(brandImageStorageBucket)
              .remove([fileName]);
        } catch (e) {
          print('Error deleting brand image: $e');
        }
      }
      
      await _supabase
          .from('product_brands')
          .delete()
          .eq('id', id);
      return true;
    } on PostgrestException catch (e) {
      if (e.code == '23503') {
        throw const BrandInUseException(
          'This brand is associated with existing products and cannot be deleted directly.',
        );
      }
      print('Postgrest error deleting brand: ${e.message}');
      return false;
    } catch (e) {
      print('Error deleting brand: $e');
      return false;
    }
  }

  // ============ TYPES ============
  Future<List<Map<String, dynamic>>> fetchTypes({bool isAdmin = false, String? categoryId}) async {
    try {
      var query = _supabase
          .from('product_types')
          .select('id, name, user_id, category_id, product_categories(name)');
      
      // Filter by category if provided
      if (categoryId != null) {
        query = query.eq('category_id', categoryId);
      }
      
      // For sellers, only show their own types
      if (!isAdmin) {
        final userId = await _getCurrentUserId();
        if (userId == null) {
          return [];
        }
        query = query.eq('user_id', userId);
      }
      
      final response = await query.order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching types: $e');
      return [];
    }
  }

  Future<String?> addType(String name, {String? categoryId, List<String>? categoryIds}) async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) {
        print('Error: User not authenticated');
        return null;
      }

      // Validate: Name must be text (not just numbers)
      if (_isOnlyNumbers(name.trim())) {
        throw Exception('Type name cannot be only numbers. Please enter a text name.');
      }

      // Support both single categoryId (backward compatibility) and multiple categoryIds
      final List<String> categoriesToAdd = [];
      if (categoryIds != null && categoryIds.isNotEmpty) {
        categoriesToAdd.addAll(categoryIds);
      } else if (categoryId != null && categoryId.isNotEmpty) {
        categoriesToAdd.add(categoryId);
      } else {
        throw Exception('At least one category is required to add a type.');
      }

      // Check which categories already have this type
      final existingTypesResponse = await _supabase
          .from('product_types')
          .select('id, category_id, product_categories(name)')
          .eq('name', name.trim())
          .eq('user_id', userId);
      
      final existingTypes = (existingTypesResponse as List).cast<Map<String, dynamic>>();
      final existingCategoryIds = existingTypes
          .map((type) => type['category_id'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toSet();
      
      // Filter out categories that already have this type
      final categoriesToInsert = categoriesToAdd
          .where((catId) => !existingCategoryIds.contains(catId))
          .toList();
      
      if (categoriesToInsert.isEmpty) {
        final existingCategoryNames = existingTypes
            .where((type) {
              final catId = type['category_id'] as String?;
              return catId != null && categoriesToAdd.contains(catId);
            })
            .map((type) {
              final categoryData = type['product_categories'] as Map<String, dynamic>?;
              return categoryData?['name'] as String? ?? 'Unknown';
            })
            .toList();
        
        if (existingCategoryNames.length == 1) {
          throw Exception('Type "$name" already exists for category "${existingCategoryNames.first}".');
        } else {
          throw Exception('Type "$name" already exists for all selected categories.');
        }
      }
      
      // Insert type for each category that doesn't have it yet
      String? firstTypeId;
      int successCount = 0;
      
      for (final catId in categoriesToInsert) {
        try {
          final response = await _supabase
              .from('product_types')
              .insert({
                'name': name.trim(),
                'user_id': userId,
                'category_id': catId,
              })
              .select('id')
              .single();
          
          firstTypeId ??= response['id'] as String?;
          successCount++;
        } catch (e) {
          print('Error inserting type for category $catId: $e');
          // Continue with other categories
        }
      }
      
      if (successCount == 0) {
        throw Exception('Failed to add type "$name" to any category. Please try again.');
      }
      
      return firstTypeId;
    } catch (e) {
      print('Error adding type: $e');
      rethrow;
    }
  }

  Future<bool> updateType(String id, String name, {bool isAdmin = false, String? categoryId}) async {
    try {
      // Validate: Name must be text (not just numbers)
      if (_isOnlyNumbers(name.trim())) {
        throw Exception('Type name cannot be only numbers. Please enter a text name.');
      }

      // Check ownership for sellers
      if (!isAdmin) {
        final userId = await _getCurrentUserId();
        if (userId == null) return false;
        
        final type = await _supabase
            .from('product_types')
            .select('user_id')
            .eq('id', id)
            .maybeSingle();
        
        if (type == null || type['user_id'] != userId) {
          print('Error: User does not own this type');
          return false;
        }
      }

      final updateData = {'name': name.trim()};
      if (categoryId != null) {
        updateData['category_id'] = categoryId;
      }

      await _supabase
          .from('product_types')
          .update(updateData)
          .eq('id', id);
      return true;
    } catch (e) {
      print('Error updating type: $e');
      rethrow;
    }
  }

  Future<bool> deleteType(String id, {bool isAdmin = false}) async {
    try {
      // Check ownership for sellers
      if (!isAdmin) {
        final userId = await _getCurrentUserId();
        if (userId == null) return false;
        
        final type = await _supabase
            .from('product_types')
            .select('user_id')
            .eq('id', id)
            .maybeSingle();
        
        if (type == null || type['user_id'] != userId) {
          print('Error: User does not own this type');
          return false;
        }
      }

      await _supabase
          .from('product_types')
          .delete()
          .eq('id', id);
      return true;
    } on PostgrestException catch (e) {
      if (e.code == '23503') {
        throw const TypeInUseException(
          'This type is associated with existing products and cannot be deleted directly.',
        );
      }
      print('Postgrest error deleting type: ${e.message}');
      return false;
    } catch (e) {
      print('Error deleting type: $e');
      return false;
    }
  }

  // ============ MODELS ============
  Future<List<Map<String, dynamic>>> fetchModels({bool isAdmin = false}) async {
    try {
      // For sellers, only show their own models
      if (!isAdmin) {
        final userId = await _getCurrentUserId();
        if (userId == null) {
          return [];
        }
        final response = await _supabase
            .from('product_models')
            .select('id, name, user_id')
            .eq('user_id', userId)
            .order('name');
        return List<Map<String, dynamic>>.from(response);
      } else {
        // Admin sees all models
        final response = await _supabase
            .from('product_models')
            .select('id, name, user_id')
            .order('name');
        return List<Map<String, dynamic>>.from(response);
      }
    } catch (e) {
      print('Error fetching models: $e');
      return [];
    }
  }

  Future<String?> addModel(String name) async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) {
        print('Error: User not authenticated');
        return null;
      }

      // Validate: Model name must be an integer
      if (!_isInteger(name.trim())) {
        throw Exception('Model must be an integer value. Please enter a valid number.');
      }

      final response = await _supabase
          .from('product_models')
          .insert({
            'name': name.trim(),
            'user_id': userId,
          })
          .select('id')
          .single();
      return response['id'] as String?;
    } catch (e) {
      print('Error adding model: $e');
      rethrow;
    }
  }

  // Helper method to check if string is a valid integer
  bool _isInteger(String text) {
    if (text.isEmpty) return false;
    // Remove any whitespace
    final trimmed = text.trim();
    // Check if it's a valid integer (can be negative)
    return RegExp(r'^-?\d+$').hasMatch(trimmed);
  }

  Future<bool> updateModel(String id, String name, {bool isAdmin = false}) async {
    try {
      // Validate: Model name must be an integer
      if (!_isInteger(name.trim())) {
        throw Exception('Model must be an integer value. Please enter a valid number.');
      }

      // Check ownership for sellers
      if (!isAdmin) {
        final userId = await _getCurrentUserId();
        if (userId == null) return false;
        
        final model = await _supabase
            .from('product_models')
            .select('user_id')
            .eq('id', id)
            .maybeSingle();
        
        if (model == null || model['user_id'] != userId) {
          print('Error: User does not own this model');
          return false;
        }
      }

      await _supabase
          .from('product_models')
          .update({'name': name.trim()})
          .eq('id', id);
      return true;
    } catch (e) {
      print('Error updating model: $e');
      rethrow;
    }
  }

  Future<bool> deleteModel(String id, {bool isAdmin = false}) async {
    try {
      // Check ownership for sellers
      if (!isAdmin) {
        final userId = await _getCurrentUserId();
        if (userId == null) return false;
        
        final model = await _supabase
            .from('product_models')
            .select('user_id')
            .eq('id', id)
            .maybeSingle();
        
        if (model == null || model['user_id'] != userId) {
          print('Error: User does not own this model');
          return false;
        }
      }

      await _supabase
          .from('product_models')
          .delete()
          .eq('id', id);
      return true;
    } on PostgrestException catch (e) {
      if (e.code == '23503') {
        throw const ModelInUseException(
          'This model is associated with existing products and cannot be deleted directly.',
        );
      }
      print('Postgrest error deleting model: ${e.message}');
      return false;
    } catch (e) {
      print('Error deleting model: $e');
      return false;
    }
  }

}

