import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../services/admin_seller_products_service.dart';
import '../../widgets/admin_drawer.dart';
import '../../widgets/custom_snackbar.dart';
import 'admin_product_detail_screen.dart';

class AdminSellerProductsScreen extends StatefulWidget {
  const AdminSellerProductsScreen({super.key});

  @override
  State<AdminSellerProductsScreen> createState() => _AdminSellerProductsScreenState();
}

class _AdminSellerProductsScreenState extends State<AdminSellerProductsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final AdminSellerProductsService _service = AdminSellerProductsService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _allProducts = [];
  bool _isLoading = true;
  String? _adminUserId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadAdminData();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) {
      setState(() {
        // Trigger rebuild to show filtered results
      });
    }
  }

  List<Map<String, dynamic>> get _filteredProducts {
    return AdminSellerProductsService.filterProducts(
      _allProducts,
      _searchController.text,
    );
  }

  Future<void> _loadAdminData() async {
    try {
      _adminUserId = await _service.getAdminUserId();
      if (_adminUserId != null) {
        await _loadProducts();
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading admin data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadProducts() async {
    if (_adminUserId == null) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final products = await _service.loadSellerProducts(_adminUserId!);
      
      if (mounted) {
        setState(() {
          _allProducts = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading products: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
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
                  await _loadProducts();
                },
                color: AppColors.adminPrimary,
                child: _isLoading && _allProducts.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.adminPrimary),
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Seller Products Section
                            _buildSellerProductsSection(),
                            
                            const SizedBox(height: 20),
                            
                            // Product List
                            _buildProductList(),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
      drawer: const AdminDrawer(currentScreen: 'admin_seller_products'),
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
            // Hamburger Menu
            GestureDetector(
              onTap: () {
                _scaffoldKey.currentState?.openDrawer();
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.menu,
                  color: AppColors.white,
                  size: 20,
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
                    'Admin',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSellerProductsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          'Seller Products',
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
            decoration: InputDecoration(
              hintText: 'Search seller products',
              hintStyle: AppTextStyles.textFieldHint,
              border: InputBorder.none,
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.textLight,
                size: 20,
              ),
              suffixIcon: _searchController.text.isNotEmpty
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
            ),
            style: AppTextStyles.bodyMedium,
            onChanged: (_) {
              if (mounted) {
                setState(() {}); // Rebuild to update suffix icon and filtered results
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductList() {
    if (_isLoading && _allProducts.isEmpty) {
      return const SizedBox.shrink(); // Loading is handled in the RefreshIndicator child
    }

    final filteredProducts = _filteredProducts;

    if (filteredProducts.isEmpty) {
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
                  : 'No seller products found',
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
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        return _buildProductCard(filteredProducts[index]);
      },
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final usage = product['usage'] as String? ?? 'New';
    final origin = product['origin'] as String? ?? 'Imported';
    final tags = <String>[];
    
    if (usage.isNotEmpty) tags.add(usage);
    if (origin.isNotEmpty) tags.add(origin);
    
    final productName = product['name'] as String? ?? 'Unknown Product';
    final formattedPrice = product['formatted_price'] as String? ?? 'PKR 0';
    final rating = product['rating'] as double? ?? 0.0;
    final firstImage = product['first_image'] as String?;
    final sellerName = product['seller_name'] as String? ?? 'Unknown Seller';

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
            Stack(
              children: [
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
              ],
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
                  
                  // Seller Name
                  Row(
                    children: [
                      const Icon(
                        Icons.person,
                        color: AppColors.textLight,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'By: $sellerName',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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

      await _service.deleteProduct(productId);

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Remove product from local list
      if (mounted) {
        setState(() {
          _allProducts.removeWhere((p) => p['id'] == productId);
        });
      }

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

