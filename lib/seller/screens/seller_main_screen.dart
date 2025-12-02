import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../controller/profile/cubit.dart';
import 'seller_profile_screen.dart';
import 'seller_dashboard_screen.dart';
import 'seller_support_screen.dart';
import '../../customer/screens/customer_dashboard_screen.dart';

class SellerMainScreen extends StatefulWidget {
  const SellerMainScreen({super.key});

  @override
  State<SellerMainScreen> createState() => _SellerMainScreenState();
}

class _SellerMainScreenState extends State<SellerMainScreen> {
  int _selectedBottomNavIndex = 1; // Dashboard is selected by default
  late PageController _pageController;

  // List of screens for bottom navigation
  final List<Widget> _screens = [
    const SellerProfileScreen(),
    const SellerDashboardScreen(),
    const CustomerDashboardScreen(showBackButton: false), // Customer view tab
    const SellerSupportScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedBottomNavIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // Disable manual swiping
        onPageChanged: (index) {
          setState(() {
            _selectedBottomNavIndex = index;
          });
          // Refresh profile data in background when switching to profile tab
          if (index == 0) {
            context.read<ProfileCubit>().refreshProfile();
          }
        },
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedBottomNavIndex,
        onTap: (index) {
          setState(() {
            _selectedBottomNavIndex = index;
          });
          // Use jumpToPage to avoid animating through intermediate pages
          _pageController.jumpToPage(index);
          // Refresh profile data in background when switching to profile tab
          if (index == 0) {
            context.read<ProfileCubit>().refreshProfile();
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textLight,
        selectedLabelStyle: AppTextStyles.navigationLabelActive,
        unselectedLabelStyle: AppTextStyles.navigationLabel,
        items: [
          // Profile Tab
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _selectedBottomNavIndex == 0 
                    ? AppColors.primary.withOpacity(0.1) 
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                size: 24,
              ),
            ),
            label: 'Profile',
          ),
          // Dashboard Tab
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _selectedBottomNavIndex == 1 
                    ? AppColors.primary.withOpacity(0.1) 
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.home,
                size: 24,
              ),
            ),
            label: 'Dashboard',
          ),
          // Customer View Tab
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _selectedBottomNavIndex == 2 
                    ? AppColors.primary.withOpacity(0.1) 
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_bag,
                size: 24,
              ),
            ),
            label: 'Shop',
          ),
          // Support Tab
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _selectedBottomNavIndex == 3 
                    ? AppColors.primary.withOpacity(0.1) 
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.support_agent,
                size: 24,
              ),
            ),
            label: 'Support',
          ),
        ],
      ),
    );
  }
}
