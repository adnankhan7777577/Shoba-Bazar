import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../screens/product_metadata_management_screen.dart';

class AdminDrawer extends StatelessWidget {
  final String currentScreen;

  const AdminDrawer({
    super.key,
    required this.currentScreen,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Drawer Header
          DrawerHeader(
            decoration: const BoxDecoration(
              color: AppColors.adminPrimary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.white,
                  child: Icon(
                    Icons.admin_panel_settings,
                    color: AppColors.adminPrimary,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Admin Panel',
                  style: AppTextStyles.heading2.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Shoba Bazar',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          
          // Drawer Items
          _buildDrawerItem(
            context: context,
            icon: Icons.grid_view,
            title: 'Products',
            route: '/admin_dashboard',
            currentScreen: currentScreen,
            onTap: () {
              Navigator.pop(context);
              if (currentScreen != 'admin_dashboard') {
                Navigator.pushNamed(context, '/admin_dashboard');
              }
            },
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.person,
            title: 'Sellers',
            route: '/admin_seller_list',
            currentScreen: currentScreen,
            onTap: () {
              Navigator.pop(context);
              if (currentScreen != 'admin_seller_list') {
                Navigator.pushNamed(context, '/admin_seller_list');
              }
            },
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.description,
            title: 'Requests',
            route: '/admin_requests_list',
            currentScreen: currentScreen,
            onTap: () {
              Navigator.pop(context);
              if (currentScreen != 'admin_requests_list') {
                Navigator.pushNamed(context, '/admin_requests_list');
              }
            },
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.report_problem,
            title: 'Reported',
            route: '/admin_reported_products_list',
            currentScreen: currentScreen,
            onTap: () {
              Navigator.pop(context);
              if (currentScreen != 'admin_reported_products_list') {
                Navigator.pushNamed(context, '/admin_reported_products_list');
              }
            },
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.store,
            title: 'Seller Products',
            route: '/admin_seller_products',
            currentScreen: currentScreen,
            onTap: () {
              Navigator.pop(context);
              if (currentScreen != 'admin_seller_products') {
                Navigator.pushNamed(context, '/admin_seller_products');
              }
            },
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.image,
            title: 'Banners',
            route: '/admin_banner_list',
            currentScreen: currentScreen,
            onTap: () {
              Navigator.pop(context);
              if (currentScreen != 'admin_banner_list') {
                Navigator.pushNamed(context, '/admin_banner_list');
              }
            },
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.settings_applications,
            title: 'Manage Data',
            route: '/product_metadata_management',
            currentScreen: currentScreen,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProductMetadataManagementScreen(isAdmin: true),
                ),
              );
            },
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.person_outline,
            title: 'Profile',
            route: '/admin_profile',
            currentScreen: currentScreen,
            onTap: () {
              Navigator.pop(context);
              if (currentScreen != 'admin_profile') {
                Navigator.pushNamed(context, '/admin_profile');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String route,
    required String currentScreen,
    required VoidCallback onTap,
  }) {
    final bool isSelected = currentScreen == route;
    
    return Container(
      color: isSelected ? AppColors.adminPrimary.withOpacity(0.1) : null,
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? AppColors.adminPrimary : AppColors.adminPrimary,
        ),
        title: Text(
          title,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? AppColors.adminPrimary : null,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

