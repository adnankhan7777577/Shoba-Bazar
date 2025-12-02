import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../controller/product_favorite/cubit.dart';
import '../../controller/customer_favorites/cubit.dart';
import '../../controller/customer_favorites/state.dart';
import 'product_detail_screen.dart';

class CustomerFavoritesScreen extends StatefulWidget {
  const CustomerFavoritesScreen({super.key});

  @override
  State<CustomerFavoritesScreen> createState() => CustomerFavoritesScreenState();
}

// Global key to access the state from outside
final GlobalKey<CustomerFavoritesScreenState> favoritesScreenKey = GlobalKey<CustomerFavoritesScreenState>();

class CustomerFavoritesScreenState extends State<CustomerFavoritesScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    context.read<CustomerFavoritesCubit>().fetchFavorites();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getFilteredItems(List<Map<String, dynamic>> favorites) {
    if (_searchQuery.isEmpty) {
      return favorites;
    }
    return favorites.where((item) {
      final name = (item['name'] as String? ?? '').toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  // Method to reload favorites (can be called from outside)
  void reloadFavorites() {
    context.read<CustomerFavoritesCubit>().fetchFavorites();
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
            
            // Search Bar
            _buildSearchBar(),
            
            // Favorites List
            Expanded(
              child: BlocBuilder<CustomerFavoritesCubit, CustomerFavoritesState>(
                builder: (context, state) {
                  if (state is CustomerFavoritesLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (state is CustomerFavoritesError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            state.message,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              context.read<CustomerFavoritesCubit>().fetchFavorites();
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  if (state is CustomerFavoritesLoaded) {
                    final filteredItems = _getFilteredItems(state.favorites);
                    
                    if (filteredItems.isEmpty) {
                      return _buildEmptyState();
                    }
                    
                    return _buildFavoritesList(filteredItems);
                  }
                  
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Text(
        'Favorite items',
        style: AppTextStyles.heading1.copyWith(
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: AppTextStyles.bodyMedium,
        decoration: InputDecoration(
          hintText: 'Search a product',
          hintStyle: AppTextStyles.textFieldHint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: AppColors.textLight,
            size: 20,
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildFavoritesList(List<Map<String, dynamic>> items) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildFavoriteItem(item);
      },
    );
  }

  Widget _buildFavoriteItem(Map<String, dynamic> item) {
    final imageUrl = item['image'] as String?;
    final rating = (item['rating'] as num?) ?? 0.0;
    
    return GestureDetector(
      onTap: () {
        // Navigate to product detail screen
        final productData = item['product'] as Map<String, dynamic>?;
        if (productData != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailScreen(
                product: productData,
              ),
            ),
          ).then((_) {
            // Reload favorites when returning from detail screen
            context.read<CustomerFavoritesCubit>().fetchFavorites();
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Product Image
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: AppColors.background,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: AppColors.background,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: AppColors.background,
                          child: const Icon(
                            Icons.image_not_supported,
                            size: 40,
                            color: AppColors.textLight,
                          ),
                        ),
                      )
                    : Container(
                        color: AppColors.background,
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 40,
                          color: AppColors.textLight,
                        ),
                      ),
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Product Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Name
                  Text(
                    item['name'] as String? ?? '',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Price
                  Text(
                    item['price'] as String? ?? '',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Rating
                  Row(
                    children: [
                      ...List.generate(5, (starIndex) {
                        return Icon(
                          starIndex < rating.floor()
                              ? Icons.star
                              : Icons.star_border,
                          color: AppColors.warning,
                          size: 16,
                        );
                      }),
                      if (rating > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            
            // Favorite Button
            GestureDetector(
              onTap: () {
                _toggleFavorite(item['id'] as String);
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowLight,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.favorite,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 80,
            color: AppColors.textLight,
          ),
          const SizedBox(height: 20),
          Text(
            'No Favorites Yet',
            style: AppTextStyles.heading2.copyWith(
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add items to your favorites to see them here',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textLight,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFavorite(String productId) async {
    // Perform database operation
    // Pass currentFavoriteStatus as true since item is in favorites list
    try {
      await context.read<ProductFavoriteCubit>().toggleFavorite(
        productId,
        currentFavoriteStatus: true,
      );
      // Reload favorites after toggling
      context.read<CustomerFavoritesCubit>().fetchFavorites();
    } catch (e) {
      print('Error toggling favorite: $e');
    }
  }
}
