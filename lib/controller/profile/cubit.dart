import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit() : super(const ProfileInitial());

  final SupabaseClient _supabase = Supabase.instance.client;
  
  // Cache for profile data
  Map<String, dynamic>? _cachedUserData;
  Map<String, dynamic>? _cachedRoleSpecificData;

  Future<void> fetchProfile({bool showLoading = true}) async {
    // Check if user is logged in first
    final user = _supabase.auth.currentUser;
    if (user == null) {
      // Don't emit error if we're in the process of logging out
      // Just reset to initial state
      clearCache();
      emit(const ProfileInitial());
      return;
    }

    // If we have cached user data, show it immediately and refresh in background
    // For admin, roleSpecificData is null, so we only check _cachedUserData
    if (_cachedUserData != null) {
      emit(ProfileRefreshing(
        userData: _cachedUserData!,
        roleSpecificData: _cachedRoleSpecificData,
      ));
    } else if (showLoading) {
      emit(const ProfileLoading());
    }

    try {

      // Fetch user data from users table
      final userResponse = await _supabase
          .from('users')
          .select()
          .eq('auth_id', user.id)
          .single();

      final role = userResponse['role'] as String;
      Map<String, dynamic>? roleSpecificData;

      // Fetch role-specific data
      if (role == 'customer') {
        final customerResponse = await _supabase
            .from('customers')
            .select()
            .eq('user_id', userResponse['id'])
            .single();
        roleSpecificData = customerResponse;
      } else if (role == 'seller') {
        final sellerResponse = await _supabase
            .from('sellers')
            .select()
            .eq('user_id', userResponse['id'])
            .single();
        roleSpecificData = sellerResponse;
      } else if (role == 'admin') {
        // Admin doesn't have a separate table, all data is in users table
        // roleSpecificData will be null for admin
        roleSpecificData = null;
      }

      // Update cache
      _cachedUserData = userResponse;
      _cachedRoleSpecificData = roleSpecificData;

      emit(ProfileLoaded(
        userData: userResponse,
        roleSpecificData: roleSpecificData,
      ));
    } on PostgrestException catch (e) {
      // If we have cached data, keep showing it even on error
      if (_cachedUserData != null) {
        emit(ProfileLoaded(
          userData: _cachedUserData!,
          roleSpecificData: _cachedRoleSpecificData,
        ));
      } else {
        emit(ProfileError('Failed to fetch profile: ${e.message}'));
      }
    } catch (e) {
      // If we have cached data, keep showing it even on error
      if (_cachedUserData != null) {
        emit(ProfileLoaded(
          userData: _cachedUserData!,
          roleSpecificData: _cachedRoleSpecificData,
        ));
      } else {
        emit(ProfileError('Failed to fetch profile: ${e.toString()}'));
      }
    }
  }

  // Refresh profile in background (doesn't show loading if cached data exists)
  Future<void> refreshProfile() async {
    await fetchProfile(showLoading: false);
  }

  void clearCache() {
    _cachedUserData = null;
    _cachedRoleSpecificData = null;
  }

  void reset() {
    clearCache();
    emit(const ProfileInitial());
  }
}

