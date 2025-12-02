import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'state.dart';
import '../profile/cubit.dart';

class LogoutCubit extends Cubit<LogoutState> {
  LogoutCubit(this._profileCubit) : super(const LogoutInitial());

  final SupabaseClient _supabase = Supabase.instance.client;
  final ProfileCubit _profileCubit;

  Future<void> logout() async {
    emit(const LogoutLoading());

    try {
      // Clear profile cache and reset before signing out
      _profileCubit.clearCache();
      _profileCubit.reset();
      
      // Sign out from Supabase
      await _supabase.auth.signOut();
      
      // Emit success after sign out completes
      emit(const LogoutSuccess());
      // Note: AuthSessionCubit will automatically detect the signOut event
    } catch (e) {
      // Even if there's an error, try to clear profile and sign out
      _profileCubit.clearCache();
      _profileCubit.reset();
      try {
        await _supabase.auth.signOut();
      } catch (_) {
        // Ignore sign out errors if already logged out
      }
      emit(LogoutError('Logout failed: ${e.toString()}'));
    }
  }

  void reset() {
    emit(const LogoutInitial());
  }
}

