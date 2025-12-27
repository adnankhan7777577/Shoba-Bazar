import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../controller/products/cubit.dart';
import '../../controller/products/state.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/product_card.dart';

class AllProductsScreen extends StatefulWidget {
  final String title;
  final String filterType; // 'hot_deals' or 'recently_added'
  
  const AllProductsScreen({
    super.key,
    required this.title,
    required this.filterType,
  });

  @override
  State<AllProductsScreen> createState() => _AllProductsScreenState();
}

class _AllProductsScreenState extends State<AllProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Fetch all products with a very high limit to show all products
    context.read<ProductsCubit>().fetchAllProducts(limit: 10000);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  List<Map<String, dynamic>> _getFilteredProducts(List<Map<String, dynamic>> products) {
    if (_searchQuery.isEmpty) {
      return products;
    } else {
      final searchLower = _searchQuery.toLowerCase();
      final searchWords = searchLower.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      
      return products.where((product) {
        final name = (product['name'] as String? ?? '').toLowerCase();
        final nameWords = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
        
        // Check if search query is a substring of product name (original behavior)
        if (name.contains(searchLower)) {
          return true;
        }
        
        // Check if any search word matches any product name word (flexible matching)
        for (final searchWord in searchWords) {
          for (final nameWord in nameWords) {
            // Check if search word is substring of name word or vice versa
            if (nameWord.contains(searchWord) || searchWord.contains(nameWord)) {
              return true;
            }
          }
        }
        
        return false;
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: AppTextStyles.heading2,
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.getHorizontalPadding(context),
              vertical: 8,
            ),
            child: Container(
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
                  hintText: 'Search products...',
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
              ),
            ),
          ),
          
          // Products Grid
          Expanded(
            child: BlocBuilder<ProductsCubit, ProductsState>(
              builder: (context, state) {
                if (state is ProductsLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
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
                            context.read<ProductsCubit>().fetchAllProducts();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                
                if (state is ProductsLoaded) {
                  final filteredProducts = _getFilteredProducts(state.products);
                  
                  if (filteredProducts.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: AppColors.textLight,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? 'No products available'
                                : 'No products match your search',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textLight,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }
                  
                  return GridView.builder(
                    padding: ResponsiveUtils.getScreenPadding(context),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: ResponsiveUtils.getProductGridCrossAxisCount(context),
                      crossAxisSpacing: ResponsiveUtils.getGridSpacing(context),
                      mainAxisSpacing: ResponsiveUtils.getGridSpacing(context),
                      childAspectRatio: ResponsiveUtils.getProductCardAspectRatio(context),
                    ),
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      return _buildProductCard(product);
                    },
                  );
                }
                
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final productImage = product['image'] as String?;
    final productName = product['name'] as String;
    final productPrice = product['price'] as String;
    final productRating = product['rating'] as num? ?? 0.0;
    final productData = product['product'] as Map<String, dynamic>;

    return ProductCard(
      productImage: productImage,
      productName: productName,
      productPrice: productPrice,
      productRating: productRating.toDouble(),
      productData: productData,
      useGridViewLayout: true,
    );
  }
}

