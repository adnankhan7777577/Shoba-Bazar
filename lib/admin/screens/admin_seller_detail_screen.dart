import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../widgets/custom_snackbar.dart';
import '../../controller/admin_seller_products/cubit.dart';
import '../../controller/admin_seller_products/state.dart';
import 'admin_product_detail_screen.dart';

class AdminSellerDetailScreen extends StatefulWidget {
  final Map<String, dynamic> seller;

  const AdminSellerDetailScreen({
    super.key,
    required this.seller,
  });

  @override
  State<AdminSellerDetailScreen> createState() => _AdminSellerDetailScreenState();
}

class _AdminSellerDetailScreenState extends State<AdminSellerDetailScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  
  Map<String, dynamic>? _sellerData;

  @override
  void initState() {
    super.initState();
    _loadSellerData();
    final sellerId = widget.seller['id'] as String?;
    if (sellerId != null) {
      context.read<AdminSellerProductsCubit>().fetchSellerProducts(sellerId);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSellerData() async {
    // Use the seller data passed from the list screen
    // The is_active status is already included from the list screen
    setState(() {
      _sellerData = widget.seller;
    });
  }

  List<Map<String, dynamic>> _getFilteredProducts(List<Map<String, dynamic>> allProducts) {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      return allProducts;
    }
    
    return allProducts.where((product) {
      final name = (product['name'] as String? ?? '').toLowerCase();
      final description = (product['description'] as String? ?? '').toLowerCase();
      return name.contains(query) || description.contains(query);
    }).toList();
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
              child: RefreshIndicator(
                onRefresh: () async {
                  final sellerId = widget.seller['id'] as String?;
                  if (sellerId != null) {
                    context.read<AdminSellerProductsCubit>().fetchSellerProducts(sellerId);
                  }
                },
                color: AppColors.adminPrimary,
                child: BlocBuilder<AdminSellerProductsCubit, AdminSellerProductsState>(
                  builder: (context, state) {
                    if (state is AdminSellerProductsLoading) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.adminPrimary),
                          ),
                        ),
                      );
                    }
                    
                    if (state is AdminSellerProductsError) {
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
                                final sellerId = widget.seller['id'] as String?;
                                if (sellerId != null) {
                                  context.read<AdminSellerProductsCubit>().fetchSellerProducts(sellerId);
                                }
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    if (state is AdminSellerProductsLoaded) {
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Seller Information Section
                            _buildSellerInfoSection(),
                            
                            const SizedBox(height: 20),
                            
                            // Products Section
                            _buildProductsSection(),
                            
                            const SizedBox(height: 20),
                            
                            // Product List
                            _buildProductList(state.products),
                          ],
                        ),
                      );
                    }
                    
                    return const SizedBox.shrink();
                  },
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
      decoration: const BoxDecoration(
        color: AppColors.adminPrimary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: AppColors.white,
                  size: 20,
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Title
            Expanded(
              child: Text(
                'Seller Details',
                style: AppTextStyles.heading2.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSellerInfoSection() {
    if (_sellerData == null) {
      return const SizedBox.shrink();
    }

    final profileImageUrl = _sellerData!['profile_picture_url'] as String?;
    final name = _sellerData!['name'] as String? ?? 'Unknown Seller';
    final email = _sellerData!['email'] as String? ?? '';
    final phone = _sellerData!['phone'] as String? ?? '';
    final shopAddress = _sellerData!['shop_address'] as String? ?? 'Not provided';
    final homeAddress = _sellerData!['home_address'] as String? ?? 'Not provided';
    final isBlocked = _sellerData!['isBlocked'] as bool? ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Seller Logo/Avatar
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(
                    color: AppColors.adminPrimary,
                    width: 2,
                  ),
                ),
                child: profileImageUrl != null && profileImageUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(38),
                        child: Image.network(
                          profileImageUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.person,
                              color: Colors.grey,
                              size: 40,
                            );
                          },
                        ),
                      )
                    : const Icon(
                        Icons.person,
                        color: Colors.grey,
                        size: 40,
                      ),
              ),
              
              const SizedBox(width: 16),
              
              // Seller Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Seller Name
                    Text(
                      name,
                      style: AppTextStyles.heading3.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    
                    
                    // Phone
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.phone,
                          color: AppColors.textLight,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            phone.isNotEmpty ? phone : 'Not provided',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Shop Address
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.store,
                          color: AppColors.textLight,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            shopAddress,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Home Address
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.home,
                          color: AppColors.textLight,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            homeAddress,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Block/Unblock Button
              GestureDetector(
                onTap: () {
                  if (isBlocked) {
                    _showUnblockConfirmation();
                  } else {
                    _showBlockConfirmation();
                  }
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isBlocked 
                        ? AppColors.adminPrimary 
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: isBlocked 
                          ? AppColors.adminPrimary 
                          : Colors.red,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    isBlocked ? Icons.check : Icons.block,
                    color: isBlocked 
                        ? AppColors.white 
                        : Colors.red,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          'Products',
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
              color: AppColors.adminPrimary,
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
            onChanged: (value) {
              setState(() {});
            },
            decoration: InputDecoration(
              hintText: 'Search product',
              hintStyle: AppTextStyles.textFieldHint,
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.textLight,
                size: 20,
              ),
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

  Widget _buildProductList(List<Map<String, dynamic>> allProducts) {
    final products = _getFilteredProducts(allProducts);
    
    if (products.isEmpty) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 50),
            Icon(
              _searchController.text.isNotEmpty ? Icons.search_off : Icons.inventory_2,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No products found for "${_searchController.text}"'
                  : 'No products found',
              style: AppTextStyles.bodyLarge.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchController.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                child: Text(
                  'Clear search',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.adminPrimary,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      itemBuilder: (context, index) {
        return _buildProductCard(products[index]);
      },
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final productName = product['name'] as String? ?? 'Unknown Product';
    final formattedPrice = product['formatted_price'] as String? ?? 'PKR 0';
    final rating = product['rating'] as double? ?? 0.0;
    final firstImage = product['first_image'] as String?;
    final tags = product['tags'] as List<dynamic>? ?? [];
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AdminProductDetailScreen(product: product),
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
              child: firstImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        firstImage,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.image,
                            color: Colors.grey,
                            size: 40,
                          );
                        },
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
                    formattedPrice,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.adminPrimary,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Rating
                  if (rating > 0)
                    Row(
                      children: List.generate(5, (starIndex) {
                        final isFilled = starIndex < rating;
                        return Icon(
                          isFilled ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 16,
                        );
                      }),
                    )
                  else
                    Row(
                      children: List.generate(5, (starIndex) {
                        return Icon(
                          Icons.star_border,
                          color: Colors.grey[300],
                          size: 16,
                        );
                      }),
                    ),
                  
                  const SizedBox(height: 8),
                  
                  // Tags
                  if (tags.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: tags.map((tag) {
                        final tagString = tag.toString();
                        Color backgroundColor;
                        Color borderColor;
                        Color textColor;
                        
                        switch (tagString) {
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
                            tagString,
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
                        builder: (context) => AdminProductDetailScreen(product: product),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.visibility,
                    color: AppColors.adminPrimary,
                  ),
                  tooltip: 'View Product',
                ),
                IconButton(
                  onPressed: () {
                    _showDeleteConfirmation(product);
                  },
                  icon: const Icon(
                    Icons.close,
                    color: Colors.red,
                  ),
                  tooltip: 'Delete Product',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  void _showBlockConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.block,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Block',
                style: AppTextStyles.heading3.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to block this seller?',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _blockSeller();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Yes',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showUnblockConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: AppColors.adminPrimary,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Unblock',
                style: AppTextStyles.heading3.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to unblock this seller?',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _unblockSeller();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.adminPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Yes',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _blockSeller() async {
    try {
      final sellerId = widget.seller['id'] as String?;
      if (sellerId == null) return;

      // Get user_id from seller
      final sellerResponse = await _supabase
          .from('sellers')
          .select('user_id')
          .eq('id', sellerId)
          .single();

      final userId = sellerResponse['user_id'] as String?;
      if (userId == null) return;

      // Update user's is_active to false
      await _supabase
          .from('users')
          .update({'is_active': false})
          .eq('id', userId);

      setState(() {
        _sellerData!['isBlocked'] = true;
        _sellerData!['is_active'] = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seller blocked successfully'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      print('Error blocking seller: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to block seller: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _unblockSeller() async {
    try {
      final sellerId = widget.seller['id'] as String?;
      if (sellerId == null) return;

      // Get user_id from seller
      final sellerResponse = await _supabase
          .from('sellers')
          .select('user_id')
          .eq('id', sellerId)
          .single();

      final userId = sellerResponse['user_id'] as String?;
      if (userId == null) return;

      // Update user's is_active to true
      await _supabase
          .from('users')
          .update({'is_active': true})
          .eq('id', userId);

      setState(() {
        _sellerData!['isBlocked'] = false;
        _sellerData!['is_active'] = true;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seller unblocked successfully'),
          backgroundColor: AppColors.adminPrimary,
        ),
      );
    } catch (e) {
      print('Error unblocking seller: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to unblock seller: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteConfirmation(Map<String, dynamic> product) {
    final productName = product['name'] as String? ?? 'this product';
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.delete_outline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Delete Product',
                style: AppTextStyles.heading3.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to delete "$productName"?',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'This action cannot be undone.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteProduct(product);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Delete',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteProduct(Map<String, dynamic> product) async {
    final productId = product['id'] as String?;
    if (productId == null) {
      CustomSnackBar.showError(context, 'Product ID not found');
      return;
    }

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.adminPrimary),
          ),
        ),
      );

      // Get all image URLs before deleting
      final imagesResponse = await _supabase
          .from('product_images')
          .select('image_url')
          .eq('product_id', productId);

      final imageUrls = (imagesResponse as List)
          .map((img) => img['image_url'] as String)
          .toList();

      // Delete product (cascade will delete product_images)
      await _supabase
          .from('products')
          .delete()
          .eq('id', productId);

      // Delete images from storage
      for (var imageUrl in imageUrls) {
        try {
          final fileName = imageUrl.split('/').last.split('?').first;
          await _supabase.storage
              .from('product-images')
              .remove([fileName]);
        } catch (e) {
          print('Error deleting image from storage: $e');
          // Continue even if storage deletion fails
        }
      }

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Remove product from local list
      setState(() {
        // Refresh products list
        final sellerId = widget.seller['id'] as String?;
        if (sellerId != null) {
          context.read<AdminSellerProductsCubit>().fetchSellerProducts(sellerId);
        }
      });

      // Show success message
      if (mounted) {
        CustomSnackBar.showSuccess(context, 'Product deleted successfully!');
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      print('Error deleting product: $e');
      if (mounted) {
        CustomSnackBar.showError(context, 'Failed to delete product: ${e.toString()}');
      }
    }
  }

}
