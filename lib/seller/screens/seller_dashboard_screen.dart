import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../constants/price_types.dart';
import '../../controller/profile/cubit.dart';
import '../../controller/profile/state.dart';
import '../../controller/seller_products/cubit.dart';
import '../../controller/seller_products/state.dart';
import 'add_product_screen.dart';
import 'seller_product_detail_screen.dart';
import 'edit_product_screen.dart';

class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Fetch profile when screen loads (will show cached data if available)
    context.read<ProfileCubit>().fetchProfile();
    // Fetch seller products
    context.read<SellerProductsCubit>().fetchSellerProducts();
    
    // Listen to search controller changes
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase().trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
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
            
            // Main Content
            Expanded(
              child: Column(
                children: [
                  // Search and Product List Container
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Your Products Section
                          _buildYourProductsSection(),
                          
                          const SizedBox(height: 20),
                          
                    // Product List - wrapped in a widget that rebuilds on search query changes
                    _buildProductListWithSearch(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildHeader() {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, profileState) {
        String sellerName = 'Seller';
        String? profilePictureUrl;

        if (profileState is ProfileLoaded || profileState is ProfileRefreshing) {
          final userData = profileState is ProfileLoaded
              ? profileState.userData
              : (profileState as ProfileRefreshing).userData;
          sellerName = userData['name'] as String? ?? 'Seller';
          profilePictureUrl = userData['profile_picture_url'] as String?;
        }

        return Container(
          decoration: const BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Profile Picture
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.white,
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: profilePictureUrl != null && profilePictureUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: profilePictureUrl,
                            fit: BoxFit.cover,
                            width: 50,
                            height: 50,
                            placeholder: (context, url) => Container(
                              color: AppColors.white,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: AppColors.white,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.build,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  Text(
                                    'SELLER',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Container(
                            color: AppColors.white,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.build,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                Text(
                                  'SELLER',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Welcome Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.white,
                        ),
                      ),
                      Text(
                        sellerName,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildYourProductsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          'Your Products',
          style: AppTextStyles.heading2.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Search Bar
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.primary,
              width: 1.5,
            ),
            color: AppColors.surface,
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
              hintText: 'Search by title, brand, category, price, etc.',
              hintStyle: AppTextStyles.textFieldHint,
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.textLight,
                size: 20,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear,
                        color: AppColors.textLight,
                        size: 20,
                      ),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductListWithSearch() {
    // This widget will rebuild whenever _searchQuery changes because it's part of the widget tree
    return BlocBuilder<SellerProductsCubit, SellerProductsState>(
      builder: (context, state) {
        if (state is SellerProductsLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (state is SellerProductsError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    state.message,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<SellerProductsCubit>().fetchSellerProducts();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (state is SellerProductsLoaded) {
          // This will use the current _searchQuery value when the widget rebuilds
          return _buildFilteredProductList(state.products);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildFilteredProductList(List<Map<String, dynamic>> allProducts) {
    // Filter products based on search query - search across multiple fields
    final filteredProducts = _searchQuery.isEmpty
        ? allProducts
        : allProducts.where((product) {
            // Search in product name (title)
            final productName = (product['name'] as String? ?? '').toLowerCase();
            
            // Search in description
            final description = (product['description'] as String? ?? '').toLowerCase();
            
            // Search in category
            final category = (product['product_categories'] as Map<String, dynamic>?)?['name'] as String? ?? '';
            final categoryLower = category.toLowerCase();
            
            // Search in type
            final type = (product['product_types'] as Map<String, dynamic>?)?['name'] as String? ?? '';
            final typeLower = type.toLowerCase();
            
            // Search in brand
            final brand = (product['product_brands'] as Map<String, dynamic>?)?['name'] as String? ?? '';
            final brandLower = brand.toLowerCase();
            
            // Search in model
            final model = (product['product_models'] as Map<String, dynamic>?)?['name'] as String? ?? '';
            final modelLower = model.toLowerCase();
            
            // Search in year
            final year = (product['product_years'] as Map<String, dynamic>?)?['year'] as num?;
            final yearString = year != null ? year.toString() : '';
            
            // Search in usage
            final usage = (product['usage'] as String? ?? '').toLowerCase();
            
            // Search in origin
            final origin = (product['origin'] as String? ?? '').toLowerCase();
            
            // Search in price type/currency
            final priceType = (product['price_types'] as Map<String, dynamic>?)?['name'] as String? ?? '';
            final priceTypeLower = priceType.toLowerCase();
            
            // Search in price - convert price to string and check if query matches
            final price = product['price'] as num? ?? 0.0;
            final priceString = price.toStringAsFixed(0);
            final formattedPrice = priceString.replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (Match m) => '${m[1]},',
            );
            final priceWithoutCommas = priceString; // Price without formatting for search
            
            // Check if search query matches any of the fields
            bool matchesTextFields = productName.contains(_searchQuery) ||
                description.contains(_searchQuery) ||
                categoryLower.contains(_searchQuery) ||
                typeLower.contains(_searchQuery) ||
                brandLower.contains(_searchQuery) ||
                modelLower.contains(_searchQuery) ||
                usage.contains(_searchQuery) ||
                origin.contains(_searchQuery) ||
                priceTypeLower.contains(_searchQuery);
            
            // Check if search query matches price (numeric search)
            bool matchesPrice = false;
            // Remove non-numeric characters from search query for price matching
            final numericQuery = _searchQuery.replaceAll(RegExp(r'[^\d]'), '');
            if (numericQuery.isNotEmpty) {
              // Check if price contains the numeric query
              matchesPrice = priceWithoutCommas.contains(numericQuery) ||
                  formattedPrice.contains(numericQuery) ||
                  yearString.contains(numericQuery);
            }
            
            return matchesTextFields || matchesPrice;
          }).toList();

    if (filteredProducts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _searchQuery.isNotEmpty ? Icons.search_off : Icons.inventory_2_outlined,
                size: 64,
                color: AppColors.textLight,
              ),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isNotEmpty ? 'No products found' : 'No products yet',
                style: AppTextStyles.heading3.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _searchQuery.isNotEmpty
                    ? 'Try a different search term'
                    : 'Tap the + button to add your first product',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textLight,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        return _buildProductCard(filteredProducts[index]);
      },
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    // Extract product data
    final productName = product['name'] as String? ?? 'Product';
    final price = product['price'] as num? ?? 0.0;
    final usage = product['usage'] as String? ?? 'New';
    final origin = product['origin'] as String? ?? 'Local';
    final images = (product['images'] as List<dynamic>?)?.cast<String>() ?? [];
    final priceType = product['price_types'] as Map<String, dynamic>?;
    final priceTypeCode = priceType?['name'] as String? ?? 'PKR';
    final priceDisplayName = PriceTypes.getDisplayName(priceTypeCode);
    
    // Format price
    final formattedPrice = price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    
    // Build tags
    final tags = <String>[];
    if (usage.isNotEmpty) tags.add(usage);
    if (origin.isNotEmpty) tags.add(origin);
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SellerProductDetailScreen(
              product: product,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
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
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: images.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: images.first,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.image,
                            color: Colors.grey,
                            size: 40,
                          ),
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.image,
                      color: Colors.grey,
                      size: 40,
                    ),
            ),
            
            const SizedBox(width: 12),
            
            // Product Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Title
                  Text(
                    productName,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Price
                  Text(
                    '$priceDisplayName $formattedPrice',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Tags
                  if (tags.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: tags.map((tag) {
                        Color backgroundColor;
                        Color borderColor;
                        Color textColor;
                        
                        switch (tag) {
                          case 'New':
                            backgroundColor = Colors.blue[100]!;
                            borderColor = Colors.blue;
                            textColor = Colors.blue[800]!;
                            break;
                          case 'Used':
                            backgroundColor = Colors.green[100]!;
                            borderColor = Colors.green;
                            textColor = Colors.green[800]!;
                            break;
                          case 'Imported':
                            backgroundColor = Colors.transparent;
                            borderColor = Colors.blue;
                            textColor = Colors.blue;
                            break;
                          case 'Local':
                            backgroundColor = Colors.transparent;
                            borderColor = Colors.orange;
                            textColor = Colors.orange;
                            break;
                          default:
                            backgroundColor = Colors.grey[100]!;
                            borderColor = Colors.grey;
                            textColor = Colors.grey[800]!;
                        }
                        
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: backgroundColor,
                            border: Border.all(color: borderColor),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
            
            // Action Icons
            Column(
              children: [
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SellerProductDetailScreen(
                          product: product,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.visibility,
                    color: Colors.grey,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditProductScreen(
                          product: product,
                        ),
                      ),
                    ).then((_) {
                      // Refresh products after editing
                      if (mounted) {
                        context.read<SellerProductsCubit>().fetchSellerProducts();
                      }
                    });
                  },
                  icon: const Icon(
                    Icons.edit,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AddProductScreen(),
          ),
        );
        // Refresh products after adding a new one
        if (mounted) {
          context.read<SellerProductsCubit>().fetchSellerProducts();
        }
      },
      backgroundColor: AppColors.primary,
      child: const Icon(
        Icons.add,
        color: Colors.white,
        size: 30,
      ),
    );
  }
}
