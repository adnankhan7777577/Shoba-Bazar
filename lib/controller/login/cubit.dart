import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/network_connectivity_service.dart';
import '../../constants/app_texts.dart';
import 'state.dart';

class LoginCubit extends Cubit<LoginState> {
  LoginCubit() : super(const LoginInitial());

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> login({
    required String email,
    required String password,
  }) async {
    emit(const LoginLoading());

    // Check network connectivity first
    final hasNetwork = await NetworkConnectivityService.hasInternetConnection();
    if (!hasNetwork) {
      emit(LoginError(AppTexts.errorNoNetwork));
      return;
    }

    try {
      // 1. Sign in with email and password
      final authResponse = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        emit(const LoginError('Login failed. Please check your credentials.'));
        return;
      }

      final authId = authResponse.user!.id;

      // 2. Get user role from database first (to check if user exists)
      try {
        final userResponse = await _supabase
            .from('users')
            .select('id, role, is_active, email')
            .eq('auth_id', authId)
            .single();

        final userRole = userResponse['role'] as String;
        final isActive = userResponse['is_active'] as bool;
        final userEmail = userResponse['email'] as String? ?? authResponse.user!.email ?? '';

        // Check if user is active
        if (!isActive) {
          emit(const LoginError('Admin blocked you, you cannot able to login please contact admin'));
          return;
        }

        // Check email verification FIRST (for all users including sellers)
        if (authResponse.user!.emailConfirmedAt == null) {
          // Email not verified - redirect to email verification screen
          emit(LoginEmailUnverified(
            email: userEmail,
            role: userRole,
            message: 'Your email is not verified. Please check your inbox for the verification code and enter it to verify your email address.',
          ));
          return;
        }

        // Email is verified, now check admin approval for sellers
        if (userRole == 'seller') {
          final userId = userResponse['id'] as String;
          final sellerResponse = await _supabase
              .from('sellers')
              .select('approval_status')
              .eq('user_id', userId)
              .maybeSingle();

          final approvalStatus = sellerResponse?['approval_status'] as String?;
          
          // If seller is not approved, redirect to waiting screen
          if (approvalStatus != 'approved') {
            emit(const LoginSellerPendingApproval());
            return;
          }
        }

        emit(LoginSuccess(
          userId: userResponse['id'].toString(),
          role: userRole,
          message: 'Login successful!',
        ));
        
        // Trigger session check to update auth state
        // Note: AuthSessionCubit will automatically detect the auth state change
      } on PostgrestException catch (e) {
        if (e.code == 'PGRST116') {
          emit(const LoginError('User not found. Please register first.'));
        } else {
          emit(LoginError('Database error: ${e.message}'));
        }
      }
    } on AuthException catch (e) {
      // Check if it's a network-related error
      final errorMessage = e.message.toLowerCase();
      if (errorMessage.contains('network') || 
          errorMessage.contains('connection') || 
          errorMessage.contains('timeout') ||
          errorMessage.contains('socket') ||
          errorMessage.contains('failed host lookup')) {
        emit(LoginError(AppTexts.errorNoNetwork));
      } else {
        emit(LoginError(e.message));
      }
    } catch (e) {
      // Check if it's a network-related error
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('network') || 
          errorString.contains('connection') || 
          errorString.contains('timeout') ||
          errorString.contains('socket') ||
          errorString.contains('failed host lookup') ||
          errorString.contains('no internet')) {
        emit(LoginError(AppTexts.errorNoNetwork));
      } else {
        emit(LoginError('Login failed: ${e.toString()}'));
      }
    }
  }

  void reset() {
    emit(const LoginInitial());
  }
}

