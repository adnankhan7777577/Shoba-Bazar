import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../../services/supabase_service.dart';
import '../../services/network_connectivity_service.dart';
import '../../constants/app_texts.dart';
import '../../utils/network_error_utils.dart';
import 'state.dart';

class ProfileEditCubit extends Cubit<ProfileEditState> {
  ProfileEditCubit() : super(const ProfileEditInitial());

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> updateCustomerProfile({
    required String userId,
    required String name,
    required String mobile,
    required String country,
    required String city,
    required String address,
    String? profilePicturePath,
    bool skipValidations = false,
  }) async {
    emit(const ProfileEditLoading());

    // Check network connectivity first
    final hasNetwork = await NetworkConnectivityService.hasInternetConnection();
    if (!hasNetwork) {
      emit(ProfileEditError(AppTexts.errorNoNetwork));
      return;
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        emit(const ProfileEditError('User not logged in'));
        return;
      }

      // Only validate mobile if not skipping validations (i.e., when updating from edit dialog)
      if (!skipValidations) {
        // Check if mobile number already exists in users table (excluding current user)
        final existingUser = await _supabase
            .from('users')
            .select('id')
            .eq('mobile', mobile)
            .neq('id', userId)
            .maybeSingle();

        if (existingUser != null) {
          emit(const ProfileEditError('This phone number is already registered. Please use a different number.'));
          return;
        }

        // Check if mobile number already exists in sellers table (whatsapp field)
        final existingSeller = await _supabase
            .from('sellers')
            .select('id')
            .eq('whatsapp', mobile)
            .maybeSingle();

        if (existingSeller != null) {
          emit(const ProfileEditError('This phone number is already registered as a WhatsApp number. Please use a different number.'));
          return;
        }
      }

      // 1. Upload new profile picture if provided
      String? profilePictureUrl;
      if (profilePicturePath != null && profilePicturePath.isNotEmpty) {
        try {
          final file = File(profilePicturePath);
          final fileName = '${user.id}-${DateTime.now().millisecondsSinceEpoch}.jpg';
          
          await _supabase.storage
              .from(SupabaseService.customerStorageBucket)
              .upload(fileName, file, fileOptions: const FileOptions(
                upsert: false,
                contentType: 'image/jpeg',
              ));

          profilePictureUrl = _supabase.storage
              .from(SupabaseService.customerStorageBucket)
              .getPublicUrl(fileName);
        } catch (e) {
          print('Error uploading profile picture: $e');
          // Continue without updating picture if upload fails
        }
      }

      // 2. Update users table
      final updateData = <String, dynamic>{};
      
      // Only update name, mobile, country, city if not skipping validations (i.e., when updating from edit dialog)
      if (!skipValidations) {
        updateData['name'] = name;
        updateData['mobile'] = mobile;
        updateData['country'] = country;
        updateData['city'] = city;
      }
      
      // Only add profile_picture_url if we have a new image
      if (profilePictureUrl != null && profilePictureUrl.isNotEmpty) {
        updateData['profile_picture_url'] = profilePictureUrl;
      }
      
      // Only update if we have data to update
      if (updateData.isNotEmpty) {
        await _supabase
            .from('users')
            .update(updateData)
            .eq('id', userId);
      }

      // 3. Update customers table (only if not skipping validations)
      if (!skipValidations) {
        await _supabase
            .from('customers')
            .update({'address': address})
            .eq('user_id', userId);
      }

      emit(const ProfileEditSuccess('Profile updated successfully!'));
    } catch (e) {
      final errorMessage = NetworkErrorUtils.getNetworkErrorMessage(e.toString());
      emit(ProfileEditError(errorMessage));
    }
  }

  Future<void> updateSellerProfile({
    required String userId,
    required String name,
    required String mobile,
    required String whatsapp,
    required String country,
    required String city,
    required String shopAddress,
    String? profilePicturePath,
    bool skipValidations = false,
  }) async {
    emit(const ProfileEditLoading());

    // Check network connectivity first
    final hasNetwork = await NetworkConnectivityService.hasInternetConnection();
    if (!hasNetwork) {
      emit(ProfileEditError(AppTexts.errorNoNetwork));
      return;
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        emit(const ProfileEditError('User not logged in'));
        return;
      }

      // Only validate mobile and whatsapp if not skipping validations (i.e., when updating from edit dialog)
      if (!skipValidations) {
        // Get current seller's user_id to exclude from checks
        final currentSeller = await _supabase
            .from('sellers')
            .select('id')
            .eq('user_id', userId)
            .maybeSingle();
        final currentSellerId = currentSeller?['id'] as String?;

        // Check if mobile number already exists in users table (excluding current user)
        final existingUser = await _supabase
            .from('users')
            .select('id')
            .eq('mobile', mobile)
            .neq('id', userId)
            .maybeSingle();

        if (existingUser != null) {
          emit(const ProfileEditError('This phone number is already registered. Please use a different number.'));
          return;
        }

        // Check if mobile number already exists in sellers table (whatsapp field)
        final mobileAsWhatsappCheck = await _supabase
            .from('sellers')
            .select('id')
            .eq('whatsapp', mobile)
            .maybeSingle();

        if (mobileAsWhatsappCheck != null) {
          emit(const ProfileEditError('This phone number is already registered as a WhatsApp number. Please use a different number.'));
          return;
        }

        // Check if WhatsApp number already exists in sellers table (excluding current seller)
        if (currentSellerId != null) {
          final existingSeller = await _supabase
              .from('sellers')
              .select('id')
              .eq('whatsapp', whatsapp)
              .neq('id', currentSellerId)
              .maybeSingle();

          if (existingSeller != null) {
            emit(const ProfileEditError('This WhatsApp number is already registered. Please use a different number.'));
            return;
          }
        } else {
          // If seller doesn't exist yet, check if whatsapp exists anywhere
          final existingSeller = await _supabase
              .from('sellers')
              .select('id')
              .eq('whatsapp', whatsapp)
              .maybeSingle();

          if (existingSeller != null) {
            emit(const ProfileEditError('This WhatsApp number is already registered. Please use a different number.'));
            return;
          }
        }

        // Check if WhatsApp number already exists in users table (mobile field)
        final existingUserWithWhatsapp = await _supabase
            .from('users')
            .select('id')
            .eq('mobile', whatsapp)
            .neq('id', userId)
            .maybeSingle();

        if (existingUserWithWhatsapp != null) {
          emit(const ProfileEditError('This WhatsApp number is already registered as a phone number. Please use a different number.'));
          return;
        }
      }

      // 1. Upload new profile picture if provided
      String? profilePictureUrl;
      if (profilePicturePath != null && profilePicturePath.isNotEmpty) {
        try {
          final file = File(profilePicturePath);
          final fileName = '${user.id}-${DateTime.now().millisecondsSinceEpoch}.jpg';
          
          await _supabase.storage
              .from(SupabaseService.sellerStorageBucket)
              .upload(fileName, file, fileOptions: const FileOptions(
                upsert: false,
                contentType: 'image/jpeg',
              ));

          profilePictureUrl = _supabase.storage
              .from(SupabaseService.sellerStorageBucket)
              .getPublicUrl(fileName);
        } catch (e) {
          print('Error uploading profile picture: $e');
          // Continue without updating picture if upload fails
        }
      }

      // 2. Update users table
      final updateData = <String, dynamic>{};
      
      // Only update name, mobile, country, city if not skipping validations (i.e., when updating from edit dialog)
      if (!skipValidations) {
        updateData['name'] = name;
        updateData['mobile'] = mobile;
        updateData['country'] = country;
        updateData['city'] = city;
      }
      
      // Only add profile_picture_url if we have a new image
      if (profilePictureUrl != null && profilePictureUrl.isNotEmpty) {
        updateData['profile_picture_url'] = profilePictureUrl;
      }
      
      // Only update if we have data to update
      if (updateData.isNotEmpty) {
        await _supabase
            .from('users')
            .update(updateData)
            .eq('id', userId);
      }

      // 3. Update sellers table (only if not skipping validations)
      if (!skipValidations) {
        await _supabase
            .from('sellers')
            .update({
              'whatsapp': whatsapp,
              'shop_address': shopAddress,
            })
            .eq('user_id', userId);
      }

      emit(const ProfileEditSuccess('Profile updated successfully!'));
    } catch (e) {
      final errorMessage = NetworkErrorUtils.getNetworkErrorMessage(e.toString());
      emit(ProfileEditError(errorMessage));
    }
  }

  Future<void> updateAdminProfile({
    required String userId,
    required String name,
    required String mobile,
    String? profilePicturePath,
    bool skipValidations = false,
  }) async {
    emit(const ProfileEditLoading());

    // Check network connectivity first
    final hasNetwork = await NetworkConnectivityService.hasInternetConnection();
    if (!hasNetwork) {
      emit(ProfileEditError(AppTexts.errorNoNetwork));
      return;
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        emit(const ProfileEditError('User not logged in'));
        return;
      }

      // Only validate mobile if not skipping validations (i.e., when updating from edit dialog)
      if (!skipValidations) {
        // Check if mobile number already exists in users table (excluding current user)
        final existingUser = await _supabase
            .from('users')
            .select('id')
            .eq('mobile', mobile)
            .neq('id', userId)
            .maybeSingle();

        if (existingUser != null) {
          emit(const ProfileEditError('This phone number is already registered. Please use a different number.'));
          return;
        }

        // Check if mobile number already exists in sellers table (whatsapp field)
        final existingSeller = await _supabase
            .from('sellers')
            .select('id')
            .eq('whatsapp', mobile)
            .maybeSingle();

        if (existingSeller != null) {
          emit(const ProfileEditError('This phone number is already registered as a WhatsApp number. Please use a different number.'));
          return;
        }
      }

      // 1. Upload new profile picture if provided
      String? profilePictureUrl;
      if (profilePicturePath != null && profilePicturePath.isNotEmpty) {
        try {
          final file = File(profilePicturePath);
          final fileName = '${user.id}-${DateTime.now().millisecondsSinceEpoch}.jpg';
          
          // Use seller storage bucket for admin (or create admin bucket if needed)
          await _supabase.storage
              .from(SupabaseService.sellerStorageBucket)
              .upload(fileName, file, fileOptions: const FileOptions(
                upsert: false,
                contentType: 'image/jpeg',
              ));

          profilePictureUrl = _supabase.storage
              .from(SupabaseService.sellerStorageBucket)
              .getPublicUrl(fileName);
        } catch (e) {
          print('Error uploading profile picture: $e');
          // Continue without updating picture if upload fails
        }
      }

      // 2. Update users table with admin profile data
      final updateData = <String, dynamic>{};
      
      // Only update name and mobile if not skipping validations (i.e., when updating from edit dialog)
      if (!skipValidations) {
        updateData['name'] = name;
        updateData['mobile'] = mobile;
      }
      
      // Only add profile_picture_url if we have a new image
      if (profilePictureUrl != null && profilePictureUrl.isNotEmpty) {
        updateData['profile_picture_url'] = profilePictureUrl;
      }
      
      // Only update if we have data to update
      if (updateData.isEmpty) {
        emit(const ProfileEditError('No changes to update'));
        return;
      }

      try {
        await _supabase
            .from('users')
            .update(updateData)
            .eq('id', userId);
      } on PostgrestException catch (e) {
        // If error is due to unknown column (profile_picture_url doesn't exist), retry without it
        if (e.message.contains('profile_picture_url') || e.code == '42703') {
          final updateDataWithoutImage = <String, dynamic>{
            'name': name,
            'mobile': mobile,
          };
          await _supabase
              .from('users')
              .update(updateDataWithoutImage)
              .eq('id', userId);
        } else {
          rethrow;
        }
      }

      emit(const ProfileEditSuccess('Profile updated successfully!'));
    } catch (e) {
      final errorMessage = NetworkErrorUtils.getNetworkErrorMessage(e.toString());
      emit(ProfileEditError(errorMessage));
    }
  }

  void setImagePath(String path) {
    emit(ProfileEditImageSelected(path));
  }
}

