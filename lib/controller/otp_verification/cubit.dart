import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'state.dart';

class OtpVerificationCubit extends Cubit<OtpVerificationState> {
  OtpVerificationCubit() : super(const OtpVerificationInitial());

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> verifyOtp({
    required String email,
    required String otp,
    required String role, // 'customer' or 'seller'
  }) async {
    emit(const OtpVerificationLoading());

    try {
      // Verify the OTP code
      final response = await _supabase.auth.verifyOTP(
        type: OtpType.email,
        email: email,
        token: otp,
      );

      if (response.user == null) {
        emit(const OtpVerificationError('Invalid verification code. Please try again.'));
        return;
      }

      // Check if email is verified
      if (response.user!.emailConfirmedAt == null) {
        emit(const OtpVerificationError('Email verification failed. Please try again.'));
        return;
      }

      final authId = response.user!.id;

      // Get user data from database
      try {
        final userResponse = await _supabase
            .from('users')
            .select('id, role')
            .eq('auth_id', authId)
            .single();

        final userRole = userResponse['role'] as String;

        // Verify role matches
        if (userRole != role) {
          emit(OtpVerificationError('Invalid verification. This account is for $userRole, not $role.'));
          return;
        }

        emit(OtpVerificationSuccess(
          message: 'Email verified successfully!',
          userId: userResponse['id'].toString(),
          role: userRole,
        ));
        
        // Note: AuthSessionCubit will automatically detect the auth state change
      } on PostgrestException catch (e) {
        emit(OtpVerificationError('Database error: ${e.message}'));
      }
    } on AuthException catch (e) {
      emit(OtpVerificationError(e.message));
    } catch (e) {
      emit(OtpVerificationError('Verification failed: ${e.toString()}'));
    }
  }

  Future<void> resendOtp({
    required String email,
  }) async {
    emit(const OtpResendLoading());

    try {
      // Check if user is already authenticated (for login scenario)
      final currentUser = _supabase.auth.currentUser;
      final OtpType otpType;
      
      if (currentUser != null && currentUser.email == email) {
        // User is logged in but email not verified - use email type
        otpType = OtpType.email;
      } else {
        // New registration - use signup type
        otpType = OtpType.signup;
      }

      await _supabase.auth.resend(
        type: otpType,
        email: email,
      );

      emit(const OtpResendSuccess('Verification code sent to your email.'));
    } on AuthException catch (e) {
      emit(OtpResendError(e.message));
    } catch (e) {
      emit(OtpResendError('Failed to resend code: ${e.toString()}'));
    }
  }

  void reset() {
    emit(const OtpVerificationInitial());
  }
}

