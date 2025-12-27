import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/product_card.dart';

class CategoryProductsScreen extends StatefulWidget {
  final String? categoryId;
  final String categoryName;
  final String? categoryImage;
  
  const CategoryProductsScreen({
    super.key,
    this.categoryId,
    required this.categoryName,
    this.categoryImage,
  });

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Build query - if categoryId is null, fetch all products
      var query = _supabase
          .from('products')
          .select('''
            id,
            name,
            price,
            description,
            seller_id,
            price_types(name),
            product_categories(name),
            product_brands(name),
            product_types(name),
            product_models(name),
            product_years(year),
            sellers(user_id, approval_status, users(is_active, role))
          ''');

      // Filter by category if categoryId is provided
      if (widget.categoryId != null) {
        query = query.eq('category_id', widget.categoryId!);
      }

      final productsResponse = await query.order('created_at', ascending: false);

      // Fetch images and ratings for each product, filter by active sellers
      final List<Map<String, dynamic>> productsWithDetails = [];
      
      for (var product in productsResponse) {
        // Filter: only include products from approved and active sellers
        // Admin products should always be shown regardless of approval status
        final sellerData = product['sellers'] as Map<String, dynamic>?;
        final userData = sellerData?['users'] as Map<String, dynamic>?;
        final isActive = userData?['is_active'] as bool? ?? false;
        final approvalStatus = sellerData?['approval_status'] as String? ?? 'pending';
        final userRole = userData?['role'] as String?;
        final isAdminProduct = userRole == 'admin';
        
        // Skip products from blocked or rejected sellers (unless it's an admin product)
        if (!isAdminProduct && (!isActive || approvalStatus != 'approved')) {
          continue;
        }
        final productId = product['id'] as String;
        
        // Fetch first image
        final imagesResponse = await _supabase
            .from('product_images')
            .select('image_url')
            .eq('product_id', productId)
            .order('display_order', ascending: true)
            .limit(1);

        String? firstImage;
        if (imagesResponse.isNotEmpty) {
          firstImage = imagesResponse[0]['image_url'] as String?;
        }

        // Fetch average rating
        double averageRating = 0.0;
        try {
          final reviewsResponse = await _supabase
              .from('product_reviews')
              .select('rating')
              .eq('product_id', productId);
          
          if (reviewsResponse.isNotEmpty) {
            final ratings = reviewsResponse
                .map((review) => (review['rating'] as num?) ?? 0.0)
                .toList();
            if (ratings.isNotEmpty) {
              averageRating = ratings.reduce((a, b) => a + b) / ratings.length;
            }
          }
        } catch (e) {
          // Use default 0.0 if reviews table doesn't exist
        }

        // Format price
        final price = product['price'] as num? ?? 0.0;
        final priceType = product['price_types'] as Map<String, dynamic>?;
        final currency = priceType?['name'] as String? ?? 'PKR';
        final priceString = price.toStringAsFixed(0);
        final formattedPriceValue = priceString.replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
        final formattedPrice = '$currency $formattedPriceValue';

        productsWithDetails.add({
          'id': productId,
          'name': product['name'] as String,
          'price': formattedPrice,
          'image': firstImage,
          'rating': averageRating,
          'product': product,
        });
      }
      
      setState(() {
        _products = productsWithDetails;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading products: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _performSearch(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  List<Map<String, dynamic>> get _filteredProducts {
    if (_searchQuery.isEmpty) {
      return _products;
    }
    final searchLower = _searchQuery.toLowerCase();
    final searchWords = searchLower.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    
    return _products.where((product) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.categoryId == null 
              ? 'All Products'
              : '${widget.categoryName} Products',
          style: AppTextStyles.heading2.copyWith(
            color: AppColors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: ResponsiveUtils.getScreenPadding(context),
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
                  hintText: widget.categoryId == null
                      ? 'Search all products...'
                      : 'Search ${widget.categoryName} products...',
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
                onChanged: _performSearch,
              ),
            ),
          ),
          
          // Products List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _filteredProducts.isEmpty
                    ? Center(
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
                                  ? widget.categoryId == null
                                      ? 'No products available'
                                      : 'No products found for ${widget.categoryName}'
                                  : 'No products match your search',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textLight,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: ResponsiveUtils.getScreenPadding(context),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: ResponsiveUtils.getProductGridCrossAxisCount(context),
                          crossAxisSpacing: ResponsiveUtils.getGridSpacing(context),
                          mainAxisSpacing: ResponsiveUtils.getGridSpacing(context),
                          childAspectRatio: ResponsiveUtils.getProductCardAspectRatio(context),
                        ),
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = _filteredProducts[index];
                          return _buildProductCard(product);
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
      cardColor: AppColors.surface,
    );
  }
}

