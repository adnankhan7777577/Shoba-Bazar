import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../../services/supabase_service.dart';
import '../../services/network_connectivity_service.dart';
import '../../constants/app_texts.dart';
import 'state.dart';

class SellerRegistrationCubit extends Cubit<SellerRegistrationState> {
  SellerRegistrationCubit() : super(const SellerRegistrationInitial());

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> registerSeller({
    required String name,
    required String email,
    required String mobile,
    required String whatsapp,
    required String country,
    required String city,
    required String shopAddress,
    required String password,
    String? profilePicturePath,
  }) async {
    emit(const SellerRegistrationLoading());

    // Check network connectivity first
    final hasNetwork = await NetworkConnectivityService.hasInternetConnection();
    if (!hasNetwork) {
      emit(SellerRegistrationError(AppTexts.errorNoNetwork));
      return;
    }

    try {
      // Check for duplicate email
      final emailCheck = await _supabase
          .from('users')
          .select('email')
          .eq('email', email)
          .maybeSingle();

      if (emailCheck != null) {
        emit(const SellerRegistrationError('Email already exists'));
        return;
      }

      // Check if mobile number already exists in users table (mobile field)
      final phoneCheck = await _supabase
          .from('users')
          .select('mobile')
          .eq('mobile', mobile)
          .maybeSingle();

      if (phoneCheck != null) {
        emit(const SellerRegistrationError('This phone number is already registered. Please use a different number.'));
        return;
      }

      // Check if mobile number already exists in sellers table (whatsapp field)
      final mobileAsWhatsappCheck = await _supabase
          .from('sellers')
          .select('whatsapp')
          .eq('whatsapp', mobile)
          .maybeSingle();

      if (mobileAsWhatsappCheck != null) {
        emit(const SellerRegistrationError('This phone number is already registered as a WhatsApp number. Please use a different number.'));
        return;
      }

      // Check if WhatsApp number already exists in sellers table (whatsapp field)
      final whatsappCheck = await _supabase
          .from('sellers')
          .select('whatsapp')
          .eq('whatsapp', whatsapp)
          .maybeSingle();

      if (whatsappCheck != null) {
        emit(const SellerRegistrationError('This WhatsApp number is already registered. Please use a different number.'));
        return;
      }

      // Check if WhatsApp number already exists in users table (mobile field)
      final whatsappAsMobileCheck = await _supabase
          .from('users')
          .select('mobile')
          .eq('mobile', whatsapp)
          .maybeSingle();

      if (whatsappAsMobileCheck != null) {
        emit(const SellerRegistrationError('This WhatsApp number is already registered as a phone number. Please use a different number.'));
        return;
      }

      // 1. Create auth user
      print('📧 [Seller Registration] Starting signUp for email: $email');
      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      print('✅ [Seller Registration] signUp call completed');
      print('📧 [Seller Registration] AuthResponse:');
      print('   - User: ${authResponse.user?.id ?? "null"}');
      print('   - Email: ${authResponse.user?.email ?? "null"}');
      print('   - Email confirmed: ${authResponse.user?.emailConfirmedAt ?? "null"}');
      print('   - Session: ${authResponse.session?.accessToken != null ? "exists" : "null"}');
      print('   - Full response: $authResponse');

      if (authResponse.user == null) {
        print('❌ [Seller Registration] Error: User is null after signUp');
        emit(const SellerRegistrationError('Failed to create user account'));
        return;
      }

      final authId = authResponse.user!.id;
      print('✅ [Seller Registration] User created with authId: $authId');

      // 2. Create user record in users table first (needed for storage permissions)
      final userResponseList = await _supabase.from('users').insert({
        'auth_id': authId,
        'role': 'seller',
        'name': name,
        'email': email,
        'mobile': mobile,
        'city': city,
        'country': country,
        'is_active': true,
      }).select();

      if (userResponseList.isEmpty) {
        emit(const SellerRegistrationError('Failed to create user record'));
        return;
      }

      final userResponse = userResponseList.first;
      final userId = userResponse['id'];

      // 3. Upload profile picture if provided (after user record is created)
      String? profilePictureUrl;
      if (profilePicturePath != null && profilePicturePath.isNotEmpty) {
        try {
          final file = File(profilePicturePath);
          final fileName = '$authId-${DateTime.now().millisecondsSinceEpoch}.jpg';
          
          await _supabase.storage
              .from(SupabaseService.sellerStorageBucket)
              .upload(fileName, file, fileOptions: const FileOptions(
                upsert: false,
                contentType: 'image/jpeg',
              ));

          profilePictureUrl = _supabase.storage
              .from(SupabaseService.sellerStorageBucket)
              .getPublicUrl(fileName);
          
          // Update user record with profile picture URL
          if (profilePictureUrl.isNotEmpty) {
            await _supabase
                .from('users')
                .update({'profile_picture_url': profilePictureUrl})
                .eq('id', userId);
          }
        } catch (e) {
          // Continue registration even if image upload fails
          // This is expected if storage RLS policies are not configured
          // The user can upload their profile picture later from the profile screen
        }
      }

      // 4. Create seller record with pending approval status
      await _supabase.from('sellers').insert({
        'user_id': userId,
        'whatsapp': whatsapp,
        'shop_address': shopAddress,
        'is_verified': false,
        'approval_status': 'pending', // New sellers need admin approval
      });

      emit(SellerRegistrationSuccess(
        message: 'Registration successful!',
        userId: userId.toString(),
      ));
    } on AuthException catch (e) {
      // Parse clean error messages for auth errors
      String errorMessage = _parseAuthErrorMessage(e.message);
      emit(SellerRegistrationError(errorMessage));
    } on PostgrestException catch (e) {
      // Handle database errors with specific messages
      String errorMessage = _parseDatabaseErrorMessage(e);
      emit(SellerRegistrationError(errorMessage));
    } catch (e) {
      // Handle any other unexpected errors
      print('Unexpected registration error: $e');
      String errorMessage = _parseGenericErrorMessage(e.toString());
      emit(SellerRegistrationError(errorMessage));
    }
  }

  String _parseAuthErrorMessage(String error) {
    final lowerError = error.toLowerCase();
    
    if (lowerError.contains('email') && 
        (lowerError.contains('already') || 
         lowerError.contains('exists') ||
         lowerError.contains('duplicate') ||
         lowerError.contains('taken'))) {
      return 'This email is already registered. Please use a different email or try logging in.';
    }
    
    if (lowerError.contains('password')) {
      if (lowerError.contains('weak') || lowerError.contains('short')) {
        return 'Password is too weak. Please use a stronger password.';
      }
      return 'Invalid password. Please check your password and try again.';
    }
    
    if (lowerError.contains('network') || 
        lowerError.contains('connection') || 
        lowerError.contains('timeout') ||
        lowerError.contains('socket') ||
        lowerError.contains('failed host lookup') ||
        lowerError.contains('no internet')) {
      return AppTexts.errorNoNetwork;
    }
    
    if (lowerError.contains('invalid') && lowerError.contains('email')) {
      return 'Invalid email format. Please enter a valid email address.';
    }
    
    // Return a user-friendly default message
    return 'Registration failed. Please check your information and try again.';
  }

  String _parseDatabaseErrorMessage(PostgrestException e) {
    final lowerMessage = e.message.toLowerCase();
    final code = e.code ?? '';
    
    // Handle specific error codes
    if (code == 'PGRST116' || 
        lowerMessage.contains('multiple rows') || 
        lowerMessage.contains('json object requested')) {
      return 'Registration error occurred. Please try again. If the problem persists, contact support.';
    }
    
    // Handle constraint violations
    if (code == '23505' || lowerMessage.contains('unique constraint') || lowerMessage.contains('duplicate key')) {
      if (lowerMessage.contains('email')) {
        return 'This email is already registered. Please use a different email.';
      }
      if (lowerMessage.contains('mobile') || lowerMessage.contains('phone')) {
        return 'This phone number is already registered. Please use a different phone number.';
      }
      if (lowerMessage.contains('whatsapp')) {
        return 'This WhatsApp number is already registered. Please use a different WhatsApp number.';
      }
      return 'This information is already registered. Please use different details.';
    }
    
    // Handle foreign key violations
    if (code == '23503' || lowerMessage.contains('foreign key')) {
      return 'Registration failed due to invalid data. Please check your information and try again.';
    }
    
    // Handle not null violations
    if (code == '23502' || lowerMessage.contains('not null')) {
      return 'Please fill in all required fields.';
    }
    
    // Handle check constraint violations
    if (code == '23514' || lowerMessage.contains('check constraint')) {
      return 'Invalid data provided. Please check your information and try again.';
    }
    
    // Handle other database errors
    if (lowerMessage.contains('connection') || lowerMessage.contains('timeout')) {
      return 'Database connection error. Please check your internet connection and try again.';
    }
    
    // Default database error message
    return 'Registration failed. Please try again. If the problem persists, contact support.';
  }

  String _parseGenericErrorMessage(String error) {
    final lowerError = error.toLowerCase();
    
    if (lowerError.contains('network') || 
        lowerError.contains('connection') || 
        lowerError.contains('timeout') ||
        lowerError.contains('socket') ||
        lowerError.contains('failed host lookup') ||
        lowerError.contains('no internet')) {
      return AppTexts.errorNoNetwork;
    }
    
    if (lowerError.contains('email') && 
        (lowerError.contains('already') || lowerError.contains('exists') || lowerError.contains('duplicate'))) {
      return 'This email is already registered. Please use a different email.';
    }
    
    if ((lowerError.contains('phone') || lowerError.contains('mobile') || lowerError.contains('whatsapp')) &&
        (lowerError.contains('already') || lowerError.contains('exists') || lowerError.contains('duplicate'))) {
      return 'This phone number is already registered. Please use a different phone number.';
    }
    
    // Return a generic user-friendly message
    return 'Registration failed. Please try again. If the problem persists, contact support.';
  }

  void setImagePath(String path) {
    emit(SellerRegistrationImageSelected(path));
  }
}

