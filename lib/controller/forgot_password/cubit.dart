import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'state.dart';

class ForgotPasswordCubit extends Cubit<ForgotPasswordState> {
  ForgotPasswordCubit() : super(const ForgotPasswordInitial());

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> sendPasswordResetEmail(String email) async {
    emit(const ForgotPasswordLoading());

    try {
      final trimmedEmail = email.trim();
      print('🔐 [sendOTP] Starting password reset for email: $trimmedEmail');

      if (trimmedEmail.isEmpty) {
        print('❌ [sendOTP] Error: Email is empty');
        emit(const ForgotPasswordError('Please enter your email address'));
        return;
      }

      // Validate email format
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(trimmedEmail)) {
        print('❌ [sendOTP] Error: Invalid email format: $trimmedEmail');
        emit(const ForgotPasswordError('Please enter a valid email address'));
        return;
      }

      print('✅ [sendOTP] Email format validated. Calling Supabase resetPasswordForEmail...');

      // Send password reset email with OTP
      // Note: This requires email template configuration in Supabase to send OTP
      await _supabase.auth.resetPasswordForEmail(
        trimmedEmail,
        redirectTo: null, // We'll handle the reset in-app
      );

      print('✅ [sendOTP] Supabase resetPasswordForEmail call completed successfully');
      print('📧 [sendOTP] Email sent to: $trimmedEmail');

      emit(const ForgotPasswordEmailSent(
        'Password reset code has been sent to your email. Please check your inbox.',
      ));
      print('✅ [sendOTP] Success state emitted');
    } on AuthException catch (e) {
      print('❌ [sendOTP] AuthException caught:');
      print('   Message: ${e.message}');
      print('   Full error: $e');
      
      // Handle specific auth errors
      if (e.message.contains('rate limit') || e.message.contains('too many')) {
        print('⚠️ [sendOTP] Rate limit error detected');
        emit(const ForgotPasswordError(
          'Too many requests. Please wait a few minutes before trying again.',
        ));
      } else if (e.message.contains('not found') || e.message.contains('does not exist')) {
        print('⚠️ [sendOTP] Email not found (but showing success for security)');
        // Don't reveal if email exists for security
        emit(const ForgotPasswordEmailSent(
          'If an account exists with this email, a password reset code has been sent.',
        ));
      } else {
        print('❌ [sendOTP] Other AuthException: ${e.message}');
        emit(ForgotPasswordError('Failed to send reset code: ${e.message}'));
      }
    } catch (e, stackTrace) {
      print('❌ [sendOTP] General exception caught:');
      print('   Error: $e');
      print('   Error type: ${e.runtimeType}');
      print('   Stack trace: $stackTrace');
      emit(ForgotPasswordError('Failed to send reset code: ${e.toString()}'));
    }
  }

  Future<void> resendPasswordResetEmail(String email) async {
    // Same as sendPasswordResetEmail, but can be called separately
    await sendPasswordResetEmail(email);
  }

  Future<void> verifyOtpAndResetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    emit(const ForgotPasswordLoading());

    try {
      // Validate inputs
      if (otp.trim().isEmpty) {
        emit(const ForgotPasswordError('Please enter the verification code'));
        return;
      }

      if (newPassword.length < 6) {
        emit(const ForgotPasswordError('Password must be at least 6 characters'));
        return;
      }

      // Verify OTP and update password
      final response = await _supabase.auth.verifyOTP(
        type: OtpType.recovery,
        email: email.trim(),
        token: otp.trim(),
      );

      if (response.user == null) {
        emit(const ForgotPasswordError('Invalid verification code'));
        return;
      }

      // Update password
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      emit(const ForgotPasswordEmailSent('Password reset successfully!'));
    } on AuthException catch (e) {
      if (e.message.contains('Invalid') || e.message.contains('expired')) {
        emit(const ForgotPasswordError('Invalid or expired verification code'));
      } else {
        emit(ForgotPasswordError('Failed to reset password: ${e.message}'));
      }
    } catch (e) {
      emit(ForgotPasswordError('Failed to reset password: ${e.toString()}'));
    }
  }

  void reset() {
    emit(const ForgotPasswordInitial());
  }
}

