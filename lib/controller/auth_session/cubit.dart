import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'state.dart';

class AuthSessionCubit extends Cubit<AuthSessionState> {
  AuthSessionCubit() : super(const AuthSessionInitial()) {
    _initializeAuth();
  }

  final SupabaseClient _supabase = Supabase.instance.client;

  void _initializeAuth() {
    // Listen to auth state changes
    _supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      if (event == AuthChangeEvent.signedIn && session != null) {
        _checkUserSession();
      } else if (event == AuthChangeEvent.signedOut) {
        emit(const AuthSessionUnauthenticated());
      } else if (event == AuthChangeEvent.tokenRefreshed) {
        _checkUserSession();
      }
    });

    // Check initial auth state
    _checkUserSession();
  }

  Future<void> _checkUserSession() async {
    emit(const AuthSessionLoading());

    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        emit(const AuthSessionUnauthenticated());
        return;
      }

      // Get user role from database first to get email and role
      try {
        final userResponse = await _supabase
            .from('users')
            .select('id, role, is_active, email')
            .eq('auth_id', user.id)
            .single();

        final userRole = userResponse['role'] as String;
        // Note: is_active is fetched but not used for automatic logout
        // Users will only be logged out when they manually do it
        final userEmail = userResponse['email'] as String? ?? user.email ?? '';

        // Check email verification FIRST (for all users including sellers)
        if (user.emailConfirmedAt == null) {
          // Email not verified - redirect to email verification screen
          emit(AuthSessionEmailUnverified(
            email: userEmail,
            role: userRole,
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
          // Don't logout them - keep them logged in and show verification screen
          if (approvalStatus != 'approved') {
            emit(const AuthSessionSellerPendingApproval());
            return;
          }
        }

        emit(AuthSessionAuthenticated(
          userId: userResponse['id'].toString(),
          role: userRole,
        ));
      } on PostgrestException catch (e) {
        if (e.code == 'PGRST116') {
          // User not found in database
          // Only sign out if not a seller waiting for approval
          // Check if there's a seller record first
          try {
            final sellerCheck = await _supabase
                .from('sellers')
                .select('approval_status')
                .eq('auth_id', user.id)
                .maybeSingle();
            
            // If seller exists and is pending approval, keep them logged in
            if (sellerCheck != null) {
              final approvalStatus = sellerCheck['approval_status'] as String?;
              if (approvalStatus != 'approved') {
                emit(const AuthSessionSellerPendingApproval());
                return;
              }
            }
          } catch (_) {
            // If check fails, proceed with sign out
          }
          
          // Only sign out if not a seller waiting for approval
          await _supabase.auth.signOut();
          emit(const AuthSessionUnauthenticated());
        } else {
          emit(AuthSessionError('Failed to verify session: ${e.message}'));
        }
      }
    } catch (e) {
      emit(AuthSessionError('Session check failed: ${e.toString()}'));
    }
  }

  Future<void> checkSession() async {
    await _checkUserSession();
  }

  Future<void> refreshSession() async {
    try {
      await _supabase.auth.refreshSession();
      await _checkUserSession();
    } catch (e) {
      emit(AuthSessionError('Failed to refresh session: ${e.toString()}'));
    }
  }
}

