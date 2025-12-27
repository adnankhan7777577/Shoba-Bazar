import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../controller/products/cubit.dart';
import '../../controller/products/state.dart';
import '../../utils/responsive_utils.dart';
import '../../utils/debouncer.dart';
import '../../widgets/product_card.dart';

class CustomerSearchScreen extends StatefulWidget {
  final String? initialQuery;
  
  const CustomerSearchScreen({
    super.key,
    this.initialQuery,
  });

  @override
  State<CustomerSearchScreen> createState() => _CustomerSearchScreenState();
}

class _CustomerSearchScreenState extends State<CustomerSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final Debouncer _debouncer = Debouncer(delay: const Duration(milliseconds: 500));

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
      context.read<ProductsCubit>().searchProducts(widget.initialQuery!);
    } else {
      // Load all products when user first opens the screen
      context.read<ProductsCubit>().fetchAllProducts();
    }
    // Auto-focus the search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  List<Map<String, dynamic>> _getFilteredProducts(List<Map<String, dynamic>> products) {
    // Get the current search query from the controller
    final searchQuery = _searchController.text.trim().toLowerCase();
    if (searchQuery.isEmpty) {
      return products;
    }
    
    final searchWords = searchQuery.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    
    return products.where((product) {
      final name = (product['name'] as String? ?? '').toLowerCase();
      final nameWords = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      
      // Check if search query is a substring of product name (original behavior)
      if (name.contains(searchQuery)) {
        return true;
      }
      
      // Check if any search word matches any product name word (flexible matching)
      for (final searchWord in searchWords) {
        for (final nameWord in nameWords) {
          // Check if search word is substring of name word or vice versa
          // This handles cases like "headlight" matching "headlights" and vice versa
          if (nameWord.contains(searchWord) || searchWord.contains(nameWord)) {
            return true;
          }
        }
      }
      
      return false;
    }).toList();
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
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
            
            // Search Results
            Expanded(
              child: BlocBuilder<ProductsCubit, ProductsState>(
                builder: (context, state) {
                  if (state is ProductsLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (state is ProductsError) {
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
                              if (_searchController.text.isEmpty) {
                                context.read<ProductsCubit>().fetchAllProducts();
                              } else {
                                context.read<ProductsCubit>().searchProducts(_searchController.text);
                              }
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  if (state is ProductsLoaded) {
                    if (state.products.isEmpty) {
                      return _buildEmptyState();
                    }
                    // Apply flexible matching filter
                    final filteredProducts = _getFilteredProducts(state.products);
                    if (filteredProducts.isEmpty) {
                      return _buildEmptyState();
                    }
                    return _buildSearchResults(filteredProducts);
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
                border: Border.all(color: AppColors.lightGrey),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowLight,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
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
              'Search',
              style: AppTextStyles.heading1.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          const SizedBox(width: 56), // Balance the back button
        ],
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
        focusNode: _searchFocusNode,
        style: AppTextStyles.bodyMedium,
        decoration: InputDecoration(
          hintText: 'Search by product, make, model...',
          hintStyle: AppTextStyles.textFieldHint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: AppColors.textPrimary,
            size: 20,
          ),
        ),
        onChanged: (value) {
          _debouncer.call(() {
            if (value.trim().isEmpty) {
              context.read<ProductsCubit>().fetchAllProducts();
            } else {
              context.read<ProductsCubit>().searchProducts(value.trim());
            }
          });
        },
        onSubmitted: (value) {
          _debouncer.dispose();
          if (value.trim().isEmpty) {
            context.read<ProductsCubit>().fetchAllProducts();
          } else {
            context.read<ProductsCubit>().searchProducts(value.trim());
          }
        },
      ),
    );
  }

  Widget _buildSearchResults(List<Map<String, dynamic>> products) {
    return GridView.builder(
      padding: ResponsiveUtils.getScreenPadding(context),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: ResponsiveUtils.getProductGridCrossAxisCount(context),
        crossAxisSpacing: ResponsiveUtils.getGridSpacing(context),
        mainAxisSpacing: ResponsiveUtils.getGridSpacing(context),
        childAspectRatio: ResponsiveUtils.getProductCardAspectRatio(context),
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _buildProductCard(product);
      },
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final imageUrl = product['image'] as String?;
    final rating = (product['rating'] as num?) ?? 0.0;
    final productData = product['product'] as Map<String, dynamic>?;
    
    if (productData == null) {
      return const SizedBox.shrink();
    }
    
    return ProductCard(
      productImage: imageUrl,
      productName: product['name'] as String? ?? '',
      productPrice: product['price'] as String? ?? '',
      productRating: rating.toDouble(),
      productData: productData,
      useGridViewLayout: true,
      showFiveStarRating: true,
      titleStyle: AppTextStyles.bodySmall.copyWith(
        fontWeight: FontWeight.w600,
      ),
      priceStyle: AppTextStyles.bodyMedium.copyWith(
        fontWeight: FontWeight.bold,
      ),
      cardColor: AppColors.surface,
      horizontalPadding: 12,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: AppColors.textLight,
          ),
          const SizedBox(height: 20),
          Text(
            'No Results Found',
            style: AppTextStyles.heading2.copyWith(
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try searching with different keywords',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textLight,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

}
