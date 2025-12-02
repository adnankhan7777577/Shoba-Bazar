import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'state.dart';

class PasswordChangeCubit extends Cubit<PasswordChangeState> {
  PasswordChangeCubit() : super(const PasswordChangeInitial());

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    emit(const PasswordChangeLoading());

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        emit(const PasswordChangeError('User not logged in'));
        return;
      }

      final email = user.email;
      if (email == null) {
        emit(const PasswordChangeError('User email not found'));
        return;
      }

      // Validate new password
      if (newPassword.length < 6) {
        emit(const PasswordChangeError('New password must be at least 6 characters'));
        return;
      }

      // Step 1: Verify old password by attempting to sign in
      // This will refresh the session if password is correct
      try {
        final authResponse = await _supabase.auth.signInWithPassword(
          email: email,
          password: oldPassword,
        );
        
        if (authResponse.user == null) {
          emit(const PasswordChangeError('Old password is incorrect'));
          return;
        }
      } on AuthException catch (e) {
        if (e.message.contains('Invalid login credentials') || 
            e.message.contains('Email not confirmed') ||
            e.message.contains('password')) {
          emit(const PasswordChangeError('Old password is incorrect'));
        } else {
          emit(PasswordChangeError('Failed to verify password: ${e.message}'));
        }
        return;
      } catch (e) {
        emit(PasswordChangeError('Failed to verify password: ${e.toString()}'));
        return;
      }

      // Step 2: Update password with new password
      try {
        await _supabase.auth.updateUser(
          UserAttributes(password: newPassword),
        );
        
        emit(const PasswordChangeSuccess('Password changed successfully'));
      } on AuthException catch (e) {
        emit(PasswordChangeError('Failed to update password: ${e.message}'));
      } catch (e) {
        emit(PasswordChangeError('Failed to update password: ${e.toString()}'));
      }
    } catch (e) {
      emit(PasswordChangeError('Failed to change password: ${e.toString()}'));
    }
  }

  void reset() {
    emit(const PasswordChangeInitial());
  }
}

