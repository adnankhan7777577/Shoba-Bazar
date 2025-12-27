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
      print('📧 [Resend OTP] Starting resend for email: $email');
      
      // Check if user is already authenticated (for login scenario)
      final currentUser = _supabase.auth.currentUser;
      final OtpType otpType;
      
      if (currentUser != null && currentUser.email == email) {
        // User is logged in but email not verified - use email type
        otpType = OtpType.email;
        print('📧 [Resend OTP] User is authenticated, using OtpType.email');
      } else {
        // New registration - use signup type
        otpType = OtpType.signup;
        print('📧 [Resend OTP] New registration, using OtpType.signup');
      }

      print('📧 [Resend OTP] Calling Supabase auth.resend with type: $otpType');
      var result = await _supabase.auth.resend(
        type: otpType,
        email: email,
      );

      print('✅ [Resend OTP] Supabase resend call completed successfully');
      print('📧 [Resend OTP] Result:');
      print('   - Message ID: ${result.messageId ?? "null"}');
      print('   - Full result: $result');
      print('   - Result type: ${result.runtimeType}');

      emit(const OtpResendSuccess('Verification code sent to your email.'));
      print('✅ [Resend OTP] Success state emitted');
    } on AuthException catch (e) {
      print('❌ [Resend OTP] AuthException caught:');
      print('   - Message: ${e.message}');
      print('   - Full error: $e');
      emit(OtpResendError(e.message));
    } catch (e, stackTrace) {
      print('❌ [Resend OTP] General exception caught:');
      print('   - Error: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Stack trace: $stackTrace');
      emit(OtpResendError('Failed to resend code: ${e.toString()}'));
    }
  }

  void reset() {
    emit(const OtpVerificationInitial());
  }
}

