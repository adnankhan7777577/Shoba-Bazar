import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../../services/network_connectivity_service.dart';
import '../../constants/app_texts.dart';
import '../../utils/network_error_utils.dart';
import 'state.dart';

class AddProductCubit extends Cubit<AddProductState> {
  AddProductCubit() : super(const AddProductInitial());

  final SupabaseClient _supabase = Supabase.instance.client;

  // Storage bucket names
  static const String productImageStorageBucket = 'product-images';
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

  // Fetch dropdown options from database
  // Fetches ALL categories from the database, regardless of who created them (admin or any seller)
  Future<List<Map<String, dynamic>>> fetchCategories() async {
    try {
      // Fetch all categories without filtering by user_id
      // This allows sellers to see and use categories created by admin or other sellers
      final response = await _supabase
          .from('product_categories')
          .select('id, name, image')
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching categories: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchTypes({String? categoryId}) async {
    try {
      var query = _supabase
          .from('product_types')
          .select('id, name, category_id');
      
      // Filter by category if provided
      if (categoryId != null) {
        query = query.eq('category_id', categoryId);
      }
      
      final response = await query.order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching types: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchBrands() async {
    try {
      final response = await _supabase
          .from('product_brands')
          .select('id, name, image')
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching brands: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchModels() async {
    try {
      final response = await _supabase
          .from('product_models')
          .select('id, name')
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching models: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchYears() async {
    try {
      final response = await _supabase
          .from('product_years')
          .select('id, year')
          .order('year', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching years: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchPriceTypes() async {
    try {
      final response = await _supabase
          .from('price_types')
          .select('id, name')
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching price types: $e');
      return [];
    }
  }

  // Add new items to lookup tables
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
      
      // Upload image
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
      // After migration, the same type name can exist in multiple categories
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
      // The same type name can exist in multiple categories, so we only
      // add it to categories that don't already have it
      final categoriesToInsert = categoriesToAdd
          .where((catId) => !existingCategoryIds.contains(catId))
          .toList();
      
      if (categoriesToInsert.isEmpty) {
        // All selected categories already have this type
        if (existingCategoryIds.length == 1) {
          final existingTypeData = existingTypes.first;
          final categoryData = existingTypeData['product_categories'] as Map<String, dynamic>?;
          final categoryName = categoryData?['name'] as String? ?? 'Unknown';
          throw Exception('Type "$name" already exists for category "$categoryName".');
        } else {
          throw Exception('Type "$name" already exists for all selected categories.');
        }
      }
      
      // Insert type for each category that doesn't have it yet
      String? firstTypeId;
      int successCount = 0;
      List<String> failedCategories = [];
      String? firstFailedError;
      
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
          
          // Return the first type ID for backward compatibility
          firstTypeId ??= response['id'] as String?;
          successCount++;
        } catch (e) {
          // If insertion fails, capture the error
          if (firstFailedError == null) {
            firstFailedError = e.toString();
          }
          failedCategories.add(catId);
          
          // Check if it's a duplicate key error
          if (e.toString().contains('duplicate key') && e.toString().contains('product_types_name_key')) {
            // This means the old unique constraint on 'name' alone is still active
            // The type was successfully created for the first category, but can't be created for others
            // This is expected until the migration is run
            if (successCount > 0) {
              // We've already succeeded for at least one category, so this is expected
              continue;
            } else {
              // No success yet, but got duplicate key - type might exist from another user
              final recheckResponse = await _supabase
                  .from('product_types')
                  .select('id, category_id, product_categories(name)')
                  .eq('name', name.trim())
                  .limit(1);
              
              if (recheckResponse.isNotEmpty) {
                final recheckType = Map<String, dynamic>.from(recheckResponse.first);
                final recheckCategoryData = recheckType['product_categories'] as Map<String, dynamic>?;
                final recheckCategoryName = recheckCategoryData?['name'] as String? ?? 'Unknown';
                throw Exception('Type "$name" already exists for category "$recheckCategoryName".');
              }
            }
          } else if (e.toString().contains('duplicate key') && e.toString().contains('product_types_name_category_unique')) {
            // This is the new composite constraint - type already exists for this specific category
            // This is fine, we'll skip this category
            continue;
          }
        }
      }
      
      // If no insertions succeeded
      if (successCount == 0) {
        if (firstFailedError != null && firstFailedError.contains('duplicate key')) {
          throw Exception('Type "$name" already exists. Please use a different name.');
        }
        throw Exception('Failed to add type "$name". ${firstFailedError ?? "Unknown error"}');
      }
      
      // If some categories failed but we succeeded for others
      if (failedCategories.isNotEmpty && successCount > 0) {
        // Check if failures were due to the old constraint (name_key) or new constraint (name_category_unique)
        final hasOldConstraintError = firstFailedError?.contains('product_types_name_key') ?? false;
        if (hasOldConstraintError && categoriesToAdd.length > 1) {
          // The old constraint is still active - type was only added to first category
          print('Note: Type "$name" was added to $successCount category. To add to multiple categories, please run the migration: migration_fix_type_unique_constraint.sql');
        }
      }
      
      return firstTypeId;
    } catch (e) {
      print('Error adding type: $e');
      rethrow;
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
      
      // Upload image
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
      return null;
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

  Future<void> addProduct({
    required String name,
    required String categoryId,
    required String typeId,
    required String brandId,
    required String modelId,
    required String description,
    required String usage, // 'New' or 'Used'
    required String origin, // 'Imported' or 'Local'
    required String price,
    required String priceTypeCode, // Currency code (e.g., 'PKR', 'USD')
    required List<File> productImages,
  }) async {
    emit(const AddProductLoading());

    // Check network connectivity first
    final hasNetwork = await NetworkConnectivityService.hasInternetConnection();
    if (!hasNetwork) {
      emit(AddProductError(AppTexts.errorNoNetwork));
      return;
    }

    try {
      // Get current user
      final user = _supabase.auth.currentUser;
      if (user == null) {
        emit(const AddProductError('User not logged in'));
        return;
      }

      // Get user data to find seller_id
      final userResponse = await _supabase
          .from('users')
          .select('id, role, mobile')
          .eq('auth_id', user.id)
          .single();

      final userId = userResponse['id'];
      final userRole = userResponse['role'] as String?;
      final userMobile = userResponse['mobile'] as String? ?? '';

      // Get seller_id from sellers table (or create one for admin if needed)
      String sellerId;
      final sellerResponse = await _supabase
          .from('sellers')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (sellerResponse != null) {
        // Seller record exists
        sellerId = sellerResponse['id'] as String;
      } else {
        // No seller record found - create one for admin
        if (userRole == 'admin') {
          final newSellerResponse = await _supabase
              .from('sellers')
              .insert({
                'user_id': userId,
                'whatsapp': userMobile.isNotEmpty ? userMobile : '', // Use mobile as whatsapp or empty string
                'shop_address': '', // Empty string instead of null
                'is_verified': true, // Admin sellers are auto-verified
              })
              .select('id')
              .single();
          sellerId = newSellerResponse['id'] as String;
        } else {
          emit(const AddProductError('Seller record not found. Please complete your seller registration.'));
          return;
        }
      }

      // Parse price to double
      final priceValue = double.tryParse(price.replaceAll(',', '')) ?? 0.0;

      // Find or create price_type_id from currency code
      String priceTypeId;
      try {
        // Try to find existing price type
        final priceTypeResponse = await _supabase
            .from('price_types')
            .select('id')
            .eq('name', priceTypeCode)
            .maybeSingle();

        if (priceTypeResponse != null) {
          priceTypeId = priceTypeResponse['id'] as String;
        } else {
          // Create new price type if it doesn't exist
          final newPriceTypeResponse = await _supabase
              .from('price_types')
              .insert({'name': priceTypeCode})
              .select('id')
              .single();
          priceTypeId = newPriceTypeResponse['id'] as String;
        }
      } catch (e) {
        emit(AddProductError('Failed to process currency: ${e.toString()}'));
        return;
      }

      // Create product record - all fields are required
      final productData = {
        'seller_id': sellerId,
        'name': name,
        'description': description,
        'usage': usage,
        'origin': origin,
        'price': priceValue,
        'category_id': categoryId,
        'type_id': typeId,
        'brand_id': brandId,
        'model_id': modelId,
        'price_type_id': priceTypeId,
      };

      final productResponse = await _supabase
          .from('products')
          .insert(productData)
          .select('id')
          .single();

      final productId = productResponse['id'] as String;

      // Upload product images and create product_images records
      int uploadedImagesCount = 0;
      String? imageUploadError;
      
      if (productImages.isNotEmpty) {
        for (int i = 0; i < productImages.length; i++) {
          try {
            final file = productImages[i];
            
            // Check if file exists and is readable
            if (!await file.exists()) {
              imageUploadError = 'Image file not found';
              continue;
            }
            
            final fileName = 'product-$productId-${DateTime.now().millisecondsSinceEpoch}-$i.jpg';
            
            // Upload to storage
            await _supabase.storage
                .from(productImageStorageBucket)
                .upload(
                  fileName,
                  file,
                  fileOptions: const FileOptions(
                    upsert: false,
                    contentType: 'image/jpeg',
                  ),
                );

            // Get public URL
            final imageUrl = _supabase.storage
                .from(productImageStorageBucket)
                .getPublicUrl(fileName);
            
            // Create product_image record with display_order to maintain upload order
            await _supabase
                .from('product_images')
                .insert({
                  'product_id': productId,
                  'image_url': imageUrl,
                  'display_order': i, // Use loop index to maintain order
                });
            
            uploadedImagesCount++;
          } catch (e) {
            print('Error uploading image ${i + 1}: $e');
            imageUploadError = 'Failed to upload some images: ${e.toString()}';
            // Continue with next image
          }
        }
      }

      // Prepare success message
      String successMessage = 'Product added successfully! It will be reviewed by admin before being published.';
      
      if (productImages.isNotEmpty) {
        if (uploadedImagesCount == 0) {
          // All images failed
          emit(AddProductError('Product created but failed to upload images. Please edit the product to add images. Error: ${imageUploadError ?? "Unknown error"}'));
          return;
        } else if (uploadedImagesCount < productImages.length) {
          // Some images failed
          successMessage += ' Note: ${productImages.length - uploadedImagesCount} image(s) failed to upload.';
        }
      }

      emit(AddProductSuccess(
        message: successMessage,
        productId: productId,
      ));
    } on PostgrestException catch (e) {
      final errorMessage = NetworkErrorUtils.getNetworkErrorMessage(e.message);
      emit(AddProductError(errorMessage));
    } catch (e) {
      final errorMessage = NetworkErrorUtils.getNetworkErrorMessage(e.toString());
      emit(AddProductError(errorMessage));
    }
  }

  // Update product
  Future<void> updateProduct({
    required String productId,
    required String name,
    required String categoryId,
    required String typeId,
    required String brandId,
    required String modelId,
    required String description,
    required String usage,
    required String origin,
    required String price,
    required String priceTypeCode,
    required List<File> newProductImages, // New images to add
    required List<String> imageUrlsToKeep, // Existing image URLs to keep
  }) async {
    emit(const AddProductLoading());

    try {
      // Get current user
      final user = _supabase.auth.currentUser;
      if (user == null) {
        emit(const AddProductError('User not logged in'));
        return;
      }

      // Get user data to find seller_id and role
      final userResponse = await _supabase
          .from('users')
          .select('id, role')
          .eq('auth_id', user.id)
          .single();

      final userId = userResponse['id'];
      final userRole = userResponse['role'] as String?;

      // Get seller_id from sellers table (use maybeSingle for admin users)
      final sellerResponse = await _supabase
          .from('sellers')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      String? sellerId;
      if (sellerResponse != null) {
        sellerId = sellerResponse['id'] as String;
      }

      // Verify product belongs to this seller/admin
      final productCheck = await _supabase
          .from('products')
          .select('seller_id')
          .eq('id', productId)
          .single();

      final productSellerId = productCheck['seller_id'] as String?;

      // For admin users, allow editing if they created the product (seller_id matches)
      // For regular sellers, only allow if seller_id matches
      if (userRole == 'admin') {
        if (sellerId == null || productSellerId != sellerId) {
          emit(const AddProductError('You do not have permission to edit this product'));
          return;
        }
      } else {
        if (sellerId == null || productSellerId != sellerId) {
          emit(const AddProductError('You do not have permission to edit this product'));
          return;
        }
      }

      // Parse price to double
      final priceValue = double.tryParse(price.replaceAll(',', '')) ?? 0.0;

      // Find or create price_type_id from currency code
      String priceTypeId;
      try {
        final priceTypeResponse = await _supabase
            .from('price_types')
            .select('id')
            .eq('name', priceTypeCode)
            .maybeSingle();

        if (priceTypeResponse != null) {
          priceTypeId = priceTypeResponse['id'] as String;
        } else {
          final newPriceTypeResponse = await _supabase
              .from('price_types')
              .insert({'name': priceTypeCode})
              .select('id')
              .single();
          priceTypeId = newPriceTypeResponse['id'] as String;
        }
      } catch (e) {
        emit(AddProductError('Failed to process currency: ${e.toString()}'));
        return;
      }

      // Update product record
      final productData = {
        'name': name,
        'description': description,
        'usage': usage,
        'origin': origin,
        'price': priceValue,
        'category_id': categoryId,
        'type_id': typeId,
        'brand_id': brandId,
        'model_id': modelId,
        'price_type_id': priceTypeId,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase
          .from('products')
          .update(productData)
          .eq('id', productId);

      // Handle images: delete removed images, add new ones
      // Get current images
      final currentImagesResponse = await _supabase
          .from('product_images')
          .select('id, image_url')
          .eq('product_id', productId);

      final currentImages = (currentImagesResponse as List)
          .map((img) => <String, dynamic>{
            'id': img['id'],
            'url': img['image_url'] as String,
          })
          .toList();

      // Delete images that are not in the keep list
      for (var image in currentImages) {
        if (!imageUrlsToKeep.contains(image['url'])) {
          try {
            // Delete from database
            await _supabase
                .from('product_images')
                .delete()
                .eq('id', image['id']);

            // Try to delete from storage (extract filename from URL)
            final imageUrl = image['url'] as String;
            final fileName = imageUrl.split('/').last.split('?').first;
            try {
              await _supabase.storage
                  .from(productImageStorageBucket)
                  .remove([fileName]);
            } catch (e) {
              print('Error deleting image from storage: $e');
              // Continue even if storage deletion fails
            }
          } catch (e) {
            print('Error deleting image: $e');
          }
        }
      }

      // Upload new images
      if (newProductImages.isNotEmpty) {
        try {
          // Get the maximum display_order of existing images to append new ones
          final maxOrderResponse = await _supabase
              .from('product_images')
              .select('display_order')
              .eq('product_id', productId)
              .order('display_order', ascending: false)
              .limit(1)
              .maybeSingle();
          
          int nextOrder = 0;
          if (maxOrderResponse != null && maxOrderResponse['display_order'] != null) {
            nextOrder = (maxOrderResponse['display_order'] as int) + 1;
          }
          
          for (int i = 0; i < newProductImages.length; i++) {
            final file = newProductImages[i];
            final fileName = 'product-$productId-${DateTime.now().millisecondsSinceEpoch}-$i.jpg';
            
            await _supabase.storage
                .from(productImageStorageBucket)
                .upload(fileName, file, fileOptions: const FileOptions(
                  upsert: false,
                  contentType: 'image/jpeg',
                ));

            final imageUrl = _supabase.storage
                .from(productImageStorageBucket)
                .getPublicUrl(fileName);
            
            await _supabase
                .from('product_images')
                .insert({
                  'product_id': productId,
                  'image_url': imageUrl,
                  'display_order': nextOrder + i, // Maintain order for new images
                });
          }
        } catch (e) {
          print('Error uploading new images: $e');
          // Continue even if image upload fails
        }
      }
      
      // Reorder existing images based on imageUrlsToKeep order
      // This ensures the order matches what the user sees in the UI
      if (imageUrlsToKeep.isNotEmpty) {
        try {
          // Fetch existing images that match the URLs to keep
          final existingImagesResponse = await _supabase
              .from('product_images')
              .select('id, image_url')
              .eq('product_id', productId);
          
          // Filter in memory since Supabase doesn't have in_ method
          final filteredImages = (existingImagesResponse as List)
              .where((img) => imageUrlsToKeep.contains(img['image_url'] as String))
              .toList();
          
          // Create a map of URL to ID for quick lookup
          final urlToIdMap = <String, String>{};
          for (var img in filteredImages) {
            urlToIdMap[img['image_url'] as String] = img['id'] as String;
          }
          
          // Update display_order based on imageUrlsToKeep order
          for (int i = 0; i < imageUrlsToKeep.length; i++) {
            final imageUrl = imageUrlsToKeep[i];
            final imageId = urlToIdMap[imageUrl];
            if (imageId != null) {
              await _supabase
                  .from('product_images')
                  .update({'display_order': i})
                  .eq('id', imageId);
            }
          }
        } catch (e) {
          print('Error reordering images: $e');
          // Continue even if reordering fails
        }
      }

      emit(AddProductSuccess(
        message: 'Product updated successfully!',
        productId: productId,
      ));
    } on PostgrestException catch (e) {
      emit(AddProductError('Failed to update product: ${e.message}'));
    } catch (e) {
      emit(AddProductError('Failed to update product: ${e.toString()}'));
    }
  }

  // Delete product
  Future<void> deleteProduct(String productId) async {
    emit(const AddProductLoading());

    try {
      // Get current user
      final user = _supabase.auth.currentUser;
      if (user == null) {
        emit(const AddProductError('User not logged in'));
        return;
      }

      // Get user data to find seller_id
      final userResponse = await _supabase
          .from('users')
          .select('id')
          .eq('auth_id', user.id)
          .single();

      final userId = userResponse['id'];

      // Get seller_id from sellers table
      final sellerResponse = await _supabase
          .from('sellers')
          .select('id')
          .eq('user_id', userId)
          .single();

      final sellerId = sellerResponse['id'] as String;

      // Verify product belongs to this seller
      final productCheck = await _supabase
          .from('products')
          .select('seller_id')
          .eq('id', productId)
          .single();

      if (productCheck['seller_id'] != sellerId) {
        emit(const AddProductError('You do not have permission to delete this product'));
        return;
      }

      // Get all image URLs before deleting
      final imagesResponse = await _supabase
          .from('product_images')
          .select('image_url')
          .eq('product_id', productId);

      final imageUrls = (imagesResponse as List)
          .map((img) => img['image_url'] as String)
          .toList();

      // Delete product (cascade will delete product_images)
      await _supabase
          .from('products')
          .delete()
          .eq('id', productId);

      // Delete images from storage
      for (var imageUrl in imageUrls) {
        try {
          final fileName = imageUrl.split('/').last.split('?').first;
          await _supabase.storage
              .from(productImageStorageBucket)
              .remove([fileName]);
        } catch (e) {
          print('Error deleting image from storage: $e');
          // Continue even if storage deletion fails
        }
      }

      emit(AddProductSuccess(
        message: 'Product deleted successfully!',
        productId: productId,
      ));
    } on PostgrestException catch (e) {
      emit(AddProductError('Failed to delete product: ${e.message}'));
    } catch (e) {
      emit(AddProductError('Failed to delete product: ${e.toString()}'));
    }
  }

  void reset() {
    emit(const AddProductInitial());
  }
}

