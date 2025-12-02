import 'package:flutter/material.dart';
import 'admin/screens/admin_dashboard_screen.dart';
import 'admin/screens/admin_add_product_screen.dart';
import 'admin/screens/admin_product_detail_screen.dart';
import 'admin/screens/admin_seller_list_screen.dart';
import 'admin/screens/admin_seller_detail_screen.dart';
import 'admin/screens/admin_requests_list_screen.dart';
import 'admin/screens/admin_request_detail_screen.dart';
import 'admin/screens/admin_reported_products_list_screen.dart';
import 'admin/screens/admin_reported_product_detail_screen.dart';
import 'admin/screens/admin_profile_screen.dart';
import 'admin/screens/admin_seller_products_screen.dart';
import 'admin/screens/admin_banner_list_screen.dart';
import 'constants/app_colors.dart';
import 'constants/bloc_provider.dart';
import 'services/supabase_init.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseInit.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBlocProvider(
      child: MaterialApp(
        title: 'Shoba Bazar',
        theme: ThemeData(
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            elevation: 4,
            shadowColor: AppColors.shadow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
      home: const SplashScreen(),
      routes: {
        '/admin_dashboard': (context) => const AdminDashboardScreen(),
        '/admin_add_product': (context) => const AdminAddProductScreen(),
        '/admin_product_detail': (context) => AdminProductDetailScreen(
          product: {}, // Pass empty map for now, in real app this would come from navigation arguments
        ),
        '/admin_seller_list': (context) => const AdminSellerListScreen(),
        '/admin_seller_detail': (context) => AdminSellerDetailScreen(
          seller: {}, // Pass empty map for now, in real app this would come from navigation arguments
        ),
        '/admin_requests_list': (context) => const AdminRequestsListScreen(),
        '/admin_request_detail': (context) => AdminRequestDetailScreen(
          request: {}, // Pass empty map for now, in real app this would come from navigation arguments
        ),
        '/admin_reported_products_list': (context) => const AdminReportedProductsListScreen(),
        '/admin_reported_product_detail': (context) => AdminReportedProductDetailScreen(
          product: {}, // Pass empty map for now, in real app this would come from navigation arguments
        ),
        '/admin_profile': (context) => const AdminProfileScreen(),
        '/admin_seller_products': (context) => const AdminSellerProductsScreen(),
        '/admin_banner_list': (context) => const AdminBannerListScreen(),
      },
      debugShowCheckedModeBanner: false,
      ),
    );
  }
}
