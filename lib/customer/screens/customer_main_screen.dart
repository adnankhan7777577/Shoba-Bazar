import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../controller/profile/cubit.dart';
import 'customer_profile_screen.dart';
import 'customer_dashboard_screen.dart';
import 'customer_favorites_screen.dart' show CustomerFavoritesScreen, favoritesScreenKey;

class CustomerMainScreen extends StatefulWidget {
  const CustomerMainScreen({super.key});

  @override
  State<CustomerMainScreen> createState() => _CustomerMainScreenState();
}

class _CustomerMainScreenState extends State<CustomerMainScreen> {
  int _selectedBottomNavIndex = 1; // Home is selected by default
  late PageController _pageController;

  // List of screens for bottom navigation
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedBottomNavIndex);
    _screens = [
      const CustomerProfileScreen(),
      const CustomerDashboardScreen(),
      CustomerFavoritesScreen(key: favoritesScreenKey),
    ];
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
        onPageChanged: (index) {
          setState(() {
            _selectedBottomNavIndex = index;
          });
          // Refresh profile data in background when switching to profile tab
          if (index == 0) {
            context.read<ProfileCubit>().refreshProfile();
          }
          // Reload favorites when switching to favorites tab
          if (index == 2) {
            favoritesScreenKey.currentState?.reloadFavorites();
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
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          // Refresh profile data in background when switching to profile tab
          if (index == 0) {
            context.read<ProfileCubit>().refreshProfile();
          }
          // Reload favorites when switching to favorites tab
          if (index == 2) {
            favoritesScreenKey.currentState?.reloadFavorites();
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
          // Home Tab
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
            label: 'Home',
          ),
          // Favorites Tab
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
                Icons.favorite,
                size: 24,
              ),
            ),
            label: 'Favorites',
          ),
        ],
      ),
    );
  }
}

