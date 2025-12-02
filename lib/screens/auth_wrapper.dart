import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../controller/auth_session/cubit.dart';
import '../controller/auth_session/state.dart';
import '../customer/screens/customer_main_screen.dart';
import '../seller/screens/seller_main_screen.dart';
import '../admin/screens/admin_dashboard_screen.dart';
import 'welcome_screen.dart';
import 'code_verification_screen.dart';
import 'account_verification_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthSessionCubit, AuthSessionState>(
      builder: (context, state) {
        if (state is AuthSessionLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // If seller is pending approval, show waiting screen
        if (state is AuthSessionSellerPendingApproval) {
          return const AccountVerificationScreen();
        }

        // If email is not verified, show verification screen
        if (state is AuthSessionEmailUnverified) {
          // Capitalize role for CodeVerificationScreen (it expects 'Customer' or 'Seller')
          final roleCapitalized = state.role == 'customer' 
              ? 'Customer' 
              : state.role == 'seller' 
                  ? 'Seller' 
                  : state.role;
          
          return CodeVerificationScreen(
            role: roleCapitalized,
            email: state.email,
          );
        }

        if (state is AuthSessionAuthenticated) {
          // Navigate to appropriate screen based on role
          if (state.role == 'customer') {
            return const CustomerMainScreen();
          } else if (state.role == 'seller') {
            return const SellerMainScreen();
          } else if (state.role == 'admin') {
            return const AdminDashboardScreen();
          }
        }

        // If unauthenticated or error, show welcome screen
        return const WelcomeScreen();
      },
    );
  }
}

