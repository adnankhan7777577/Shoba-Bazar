import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../utils/responsive_utils.dart';
import '../../utils/debouncer.dart';
import 'product_detail_screen.dart';

class BrandSearchScreen extends StatefulWidget {
  final String brandId;
  final String brandName;
  final String? brandImage;
  
  const BrandSearchScreen({
    super.key,
    required this.brandId,
    required this.brandName,
    this.brandImage,
  });

  @override
  State<BrandSearchScreen> createState() => _BrandSearchScreenState();
}

class _BrandSearchScreenState extends State<BrandSearchScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  final Debouncer _debouncer = Debouncer(delay: const Duration(milliseconds: 300));
  
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
    _debouncer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch products filtered by brand, only from active sellers
      final productsResponse = await _supabase
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
          ''')
          .eq('brand_id', widget.brandId)
          .order('created_at', ascending: false);

      if (!mounted) return;

      // Filter products by seller status first
      final validProducts = productsResponse.where((product) {
        final sellerData = product['sellers'] as Map<String, dynamic>?;
        final userData = sellerData?['users'] as Map<String, dynamic>?;
        final isActive = userData?['is_active'] as bool? ?? false;
        final approvalStatus = sellerData?['approval_status'] as String? ?? 'pending';
        final userRole = userData?['role'] as String?;
        final isAdminProduct = userRole == 'admin';
        
        return isAdminProduct || (isActive && approvalStatus == 'approved');
      }).toList();

      if (validProducts.isEmpty) {
        if (!mounted) return;
        setState(() {
          _products = [];
          _isLoading = false;
        });
        return;
      }

      // Extract all product IDs for batch queries
      final productIds = validProducts.map((p) => p['id'] as String).toList();

      // Batch fetch all images at once
      final allImagesResponse = await _supabase
          .from('product_images')
          .select('product_id, image_url, display_order')
          .inFilter('product_id', productIds)
          .order('display_order', ascending: true);

      if (!mounted) return;

      // Batch fetch all reviews at once
      Map<String, double> ratingsMap = {};
      try {
        final allReviewsResponse = await _supabase
            .from('product_reviews')
            .select('product_id, rating')
            .inFilter('product_id', productIds);
        
        if (!mounted) return;

        // Calculate average ratings for each product
        final reviewsByProduct = <String, List<num>>{};
        for (var review in allReviewsResponse) {
          final productId = review['product_id'] as String;
          final rating = (review['rating'] as num?) ?? 0.0;
          reviewsByProduct.putIfAbsent(productId, () => []).add(rating);
        }

        ratingsMap = reviewsByProduct.map((productId, ratings) {
          final avg = ratings.reduce((a, b) => a + b) / ratings.length;
          return MapEntry(productId, avg);
        });
      } catch (e) {
        // Reviews table might not exist, continue with empty ratings
        print('Error fetching reviews: $e');
      }

      if (!mounted) return;

      // Group images by product_id
      final imagesByProduct = <String, List<String>>{};
      for (var image in allImagesResponse) {
        final productId = image['product_id'] as String;
        final imageUrl = image['image_url'] as String?;
        if (imageUrl != null) {
          imagesByProduct.putIfAbsent(productId, () => []).add(imageUrl);
        }
      }

      // Build product list with all data
      final List<Map<String, dynamic>> productsWithDetails = [];
      
      for (var product in validProducts) {
        final productId = product['id'] as String;
        
        // Get first image for this product
        final images = imagesByProduct[productId];
        final firstImage = images?.isNotEmpty == true ? images!.first : null;

        // Get rating for this product
        final averageRating = ratingsMap[productId] ?? 0.0;

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
      
      if (!mounted) return;
      
      setState(() {
        _products = productsWithDetails;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading products: $e');
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _performSearch(String query) {
    _debouncer.call(() {
      if (mounted) {
        setState(() {
          _searchQuery = query.toLowerCase();
        });
      }
    });
  }

  List<Map<String, dynamic>> get _filteredProducts {
    if (_searchQuery.isEmpty) {
      return _products;
    }
    return _products.where((product) {
      final name = (product['name'] as String? ?? '').toLowerCase();
      return name.contains(_searchQuery);
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
          '${widget.brandName} Products',
          style: AppTextStyles.heading2.copyWith(
            color: AppColors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
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
                  hintText: 'Search ${widget.brandName} products...',
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
                  _performSearch(value);
                },
                onSubmitted: (value) {
                  _debouncer.dispose();
                  _performSearch(value);
                },
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
                                  ? 'No products found for ${widget.brandName}'
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

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(
              product: productData,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Product Image
            Container(
              height: ResponsiveUtils.getProductCardImageHeight(context),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                color: AppColors.background,
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: productImage != null && productImage.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: productImage,
                        fit: BoxFit.cover,
                        width: double.infinity,
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
                            color: AppColors.textLight,
                          ),
                        ),
                      )
                    : Container(
                        color: AppColors.background,
                        child: const Icon(
                          Icons.image_not_supported,
                          color: AppColors.textLight,
                        ),
                      ),
              ),
            ),
            
            // Product Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: SizedBox(
                        height: 36,
                        child: Text(
                          productName,
                          style: AppTextStyles.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: Text(
                        productPrice,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          color: AppColors.warning,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            productRating.toStringAsFixed(1),
                            style: AppTextStyles.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}