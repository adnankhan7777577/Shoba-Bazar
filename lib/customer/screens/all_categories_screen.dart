import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../controller/add_product/cubit.dart';
import 'category_search_screen.dart';

class AllCategoriesScreen extends StatefulWidget {
  const AllCategoriesScreen({super.key});

  @override
  State<AllCategoriesScreen> createState() => _AllCategoriesScreenState();
}

class _AllCategoriesScreenState extends State<AllCategoriesScreen> {
  // Categories data - will be loaded from database
  List<Map<String, dynamic>> _categories = [
    {'name': 'All', 'icon': 'assets/images/all.png', 'type': 'all', 'id': null, 'image': null}
  ];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final addProductCubit = context.read<AddProductCubit>();
      final dbCategories = await addProductCubit.fetchCategories();
      
      if (mounted) {
        setState(() {
          // Keep "All" first, then add DB categories
          _categories = [
            {'name': 'All', 'icon': 'assets/images/all.png', 'type': 'all', 'id': null, 'image': null},
            ...dbCategories.map((cat) => {
              'name': cat['name'] as String,
              'icon': cat['image'] as String? ?? 'assets/images/all.png',
              'type': (cat['name'] as String).toLowerCase().replaceAll(' ', '_'),
              'id': cat['id'],
              'image': cat['image'] as String?,
            }),
          ];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading categories: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToCategory(Map<String, dynamic> category) {
    // Navigate to category search screen with filters
    // If "All", show all products (categoryId is null)
    // Otherwise, filter by category ID
    if (category['type'] == 'all') {
      // For "All", navigate to a screen that shows all products with filters
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CategorySearchScreen(
            categoryId: null,
            categoryName: 'All',
            categoryType: 'all',
          ),
        ),
      );
    } else {
      // For specific categories, navigate with category ID
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CategorySearchScreen(
            categoryId: category['id'] as String?,
            categoryName: category['name'] as String,
            categoryType: category['type'] as String,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header Section
            _buildHeader(),
            
            // Categories Grid
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : _categories.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.category_outlined,
                                size: 64,
                                color: AppColors.textLight,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No categories available',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textLight,
                                ),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 16),
                              Text(
                                'All Categories',
                                style: AppTextStyles.heading3,
                              ),
                              const SizedBox(height: 16),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 1,
                                ),
                                itemCount: _categories.length,
                                itemBuilder: (context, index) {
                                  final category = _categories[index];
                                  return GestureDetector(
                                    onTap: () {
                                      _navigateToCategory(category);
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppColors.lightGrey),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.shadowLight,
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: AppColors.background,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: category['image'] != null && category['image'] is String && (category['image'] as String).startsWith('http')
                                                  ? CachedNetworkImage(
                                                      imageUrl: category['image'] as String,
                                                      fit: BoxFit.contain,
                                                      width: 30,
                                                      height: 30,
                                                      placeholder: (context, url) => const SizedBox(
                                                        width: 30,
                                                        height: 30,
                                                        child: Center(
                                                          child: CircularProgressIndicator(strokeWidth: 2),
                                                        ),
                                                      ),
                                                      errorWidget: (context, url, error) => Image.asset(
                                                        category['icon'] as String,
                                                        fit: BoxFit.contain,
                                                        width: 30,
                                                        height: 30,
                                                      ),
                                                    )
                                                  : Image.asset(
                                                      category['icon'] as String,
                                                      fit: BoxFit.contain,
                                                      width: 30,
                                                      height: 30,
                                                    ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            category['name'],
                                            style: AppTextStyles.caption,
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          // Back Button
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Title
          Expanded(
            child: Text(
              'All Categories',
              style: AppTextStyles.heading2.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

