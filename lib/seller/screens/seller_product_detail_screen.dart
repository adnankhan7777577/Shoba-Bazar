import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shoba_bazar_app/seller/screens/edit_product_screen.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../constants/price_types.dart';
import '../../controller/profile/cubit.dart';
import '../../controller/profile/state.dart';
import '../../controller/add_product/cubit.dart';
import '../../controller/add_product/state.dart';
import '../../controller/seller_products/cubit.dart';
import '../../controller/product_reviews/cubit.dart';
import '../../controller/product_reviews/state.dart';
import '../../widgets/full_screen_image_viewer.dart';

class SellerProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const SellerProductDetailScreen({
    super.key,
    required this.product,
  });

  @override
  State<SellerProductDetailScreen> createState() => _SellerProductDetailScreenState();
}

class _SellerProductDetailScreenState extends State<SellerProductDetailScreen> {
  int _currentImageIndex = 0;

  // Extract product data from widget.product
  Map<String, dynamic> get _productData => widget.product;
  
  // Get product images
  List<String> get _productImages {
    final images = _productData['images'] as List<dynamic>?;
    if (images == null || images.isEmpty) {
      return [];
    }
    return images.cast<String>();
  }
  
  // Get product name
  String get _productName => _productData['name'] as String? ?? 'Product';
  
  // Get product description
  String get _productDescription => _productData['description'] as String? ?? 'No description available.';
  
  // Get price and currency
  String get _formattedPrice {
    final price = _productData['price'] as num? ?? 0.0;
    final priceType = _productData['price_types'] as Map<String, dynamic>?;
    final priceTypeCode = priceType?['name'] as String? ?? 'PKR';
    final priceDisplayName = PriceTypes.getDisplayName(priceTypeCode);
    
    final formattedPrice = price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    
    return '$priceDisplayName $formattedPrice';
  }
  
  // Get tags (usage and origin)
  List<String> get _tags {
    final tags = <String>[];
    final usage = _productData['usage'] as String?;
    final origin = _productData['origin'] as String?;
    if (usage != null && usage.isNotEmpty) tags.add(usage);
    if (origin != null && origin.isNotEmpty) tags.add(origin);
    return tags;
  }

  @override
  void initState() {
    super.initState();
    // Fetch reviews using cubit
    final productId = _productData['id'] as String;
    if (productId.isNotEmpty) {
      context.read<ProductReviewsCubit>().fetchProductReviews(productId);
    }
    // Fetch profile when screen loads
    context.read<ProfileCubit>().fetchProfile();
  }

  // Get product ID
  String get _productId => _productData['id'] as String;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Image Section with Back Arrow
            _buildImageSection(),
            
            // Product Details Section
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProductInfoSection(),
                    const SizedBox(height: 20),
                    _buildSellerSection(),
                    const SizedBox(height: 20),
                    _buildReviewsSection(),
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

  Widget _buildImageSection() {
    final images = _productImages;
    
    if (images.isEmpty) {
      return Container(
        height: 300,
        color: Colors.grey[200],
        child: Stack(
          children: [
            Center(
              child: Icon(
                Icons.image,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
            // Back Arrow
            Positioned(
              top: 16,
              left: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    shape: BoxShape.circle,
                    color: AppColors.white,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    return Container(
      height: 300,
      child: Stack(
        children: [
          // Image Carousel
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FullScreenImageViewer(
                    images: images,
                    initialIndex: _currentImageIndex,
                  ),
                ),
              );
            },
            child: FlutterCarousel.builder(
              itemCount: images.length,
              itemBuilder: (context, index, realIndex) {
                return CachedNetworkImage(
                  imageUrl: images[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: const Icon(
                      Icons.image,
                      size: 64,
                      color: Colors.grey,
                    ),
                  ),
                );
              },
              options: FlutterCarouselOptions(
                height: 300,
                viewportFraction: 1.0,
                showIndicator: false,
                enableInfiniteScroll: true,
                autoPlay: false,
                onPageChanged: (index, reason) {
                  setState(() {
                    _currentImageIndex = index;
                  });
                },
              ),
            ),
          ),
          
          // Back Arrow - positioned on the left side of the image
          Positioned(
            top: 16,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  shape: BoxShape.circle,
                  color: AppColors.white,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
            ),
          ),
          
          // Image Indicators
          if (images.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  images.length,
                  (index) => Container(
                    width: index == _currentImageIndex ? 12 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: index == _currentImageIndex 
                          ? AppColors.primary 
                          : AppColors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductInfoSection() {
    final tags = _tags;
    final priceParts = _formattedPrice.split(' ');
    final currency = priceParts.length > 1 ? priceParts[0] : '';
    final price = priceParts.length > 1 ? priceParts.sublist(1).join(' ') : _formattedPrice;
    
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Name
          Text(
            _productName,
            style: AppTextStyles.heading2.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // Description
          Text(
            _productDescription,
            style: AppTextStyles.bodyMedium.copyWith(
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          
          // Tags
          if (tags.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map<Widget>((tag) {
                Color borderColor;
                Color textColor;
                
                switch (tag) {
                  case 'New':
                    borderColor = AppColors.info;
                    textColor = AppColors.info;
                    break;
                  case 'Used':
                    borderColor = AppColors.success;
                    textColor = AppColors.success;
                    break;
                  case 'Imported':
                    borderColor = AppColors.info;
                    textColor = AppColors.info;
                    break;
                  case 'Local':
                    borderColor = AppColors.warning;
                    textColor = AppColors.warning;
                    break;
                  default:
                    borderColor = AppColors.lightGrey;
                    textColor = AppColors.textLight;
                }
                
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: borderColor),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    tag,
                    style: AppTextStyles.caption.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 20),
          
          // Price and Action Icons
          Row(
            children: [
              // Price
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: [
                      if (currency.isNotEmpty)
                        TextSpan(
                          text: '$currency ',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textLight,
                          ),
                        ),
                      TextSpan(
                        text: price,
                        style: AppTextStyles.heading1.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Action Icons
              Row(
                children: [
                  const SizedBox(width: 12),
                  _buildActionIcon(
                    icon: Icons.edit,
                    color: AppColors.info,
                    onTap: () {
                      _editProduct();
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildActionIcon(
                    icon: Icons.delete,
                    color: AppColors.error,
                    onTap: () {
                      _showDeleteConfirmationDialog();
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Status Button
          Container(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                _toggleProductStatus();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: const Icon(
                Icons.visibility,
                size: 24,
              ),
              label: Text(
                'Product Active',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionIcon({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.lightGrey,
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: color,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildSellerSection() {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, profileState) {
        String sellerName = 'Seller';
        String? sellerEmail;
        String? sellerPhone;
        String? sellerCity;
        String? shopAddress;
        String? profilePictureUrl;

        if (profileState is ProfileLoaded || profileState is ProfileRefreshing) {
          final userData = profileState is ProfileLoaded
              ? profileState.userData
              : (profileState as ProfileRefreshing).userData;
          sellerName = userData['name'] as String? ?? 'Seller';
          sellerEmail = userData['email'] as String?;
          sellerPhone = userData['mobile'] as String?;
          sellerCity = userData['city'] as String?;
          shopAddress = userData['shop_address'] as String?;
          profilePictureUrl = userData['profile_picture_url'] as String?;
        }
        
        return Container(
          color: AppColors.white,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Seller Information',
                style: AppTextStyles.heading3.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  // Seller Avatar
                  CircleAvatar(
                    radius: 25,
                    backgroundImage: profilePictureUrl != null && profilePictureUrl.isNotEmpty
                        ? CachedNetworkImageProvider(profilePictureUrl)
                        : null,
                    backgroundColor: AppColors.background,
                    child: profilePictureUrl == null || profilePictureUrl.isEmpty
                        ? Icon(
                            Icons.person,
                            color: AppColors.textLight,
                            size: 30,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  
                  // Seller Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sellerName,
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        // Contact Details
                      
                        if (sellerPhone != null && sellerPhone.isNotEmpty)
                          _buildContactDetail(Icons.phone, sellerPhone),
                        if (sellerPhone != null && sellerPhone.isNotEmpty) const SizedBox(height: 4),
                        if (sellerCity != null && sellerCity.isNotEmpty)
                          _buildContactDetail(Icons.location_on, sellerCity),
                        if (sellerCity != null && sellerCity.isNotEmpty) const SizedBox(height: 4),
                        if (shopAddress != null && shopAddress.isNotEmpty)
                          _buildContactDetail(
                            Icons.store_mall_directory,
                            shopAddress,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContactDetail(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.textLight,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodySmall,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsSection() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rating and reviews',
            style: AppTextStyles.heading3.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          BlocBuilder<ProductReviewsCubit, ProductReviewsState>(
            builder: (context, state) {
              if (state is ProductReviewsLoading) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              
              if (state is ProductReviewsError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text(
                      state.message,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                );
              }
              
              if (state is ProductReviewsLoaded) {
                final reviews = state.reviews;
                final averageRating = state.averageRating;
                
                if (reviews.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        'No ratings and reviews',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textLight,
                        ),
                      ),
                    ),
                  );
                }
                
                return Column(
                  children: [
                    // Average Rating Summary
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          // Average Rating Number
                          Text(
                            averageRating?.toStringAsFixed(1) ?? '0.0',
                            style: AppTextStyles.heading1.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 12),
                          
                          // Star Rating
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: List.generate(5, (index) {
                                  final avgRating = averageRating ?? 0.0;
                                  return Icon(
                                    Icons.star,
                                    size: 20,
                                    color: index < avgRating.round()
                                        ? AppColors.warning
                                        : AppColors.lightGrey,
                                  );
                                }),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${reviews.length} reviews',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textLight,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Reviews List
                    ...reviews.map<Widget>((review) {
                      final avatarUrl = review['avatar'] as String?;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // User Avatar
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.background,
                              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                  ? CachedNetworkImageProvider(avatarUrl)
                                  : null,
                              child: avatarUrl == null || avatarUrl.isEmpty
                                  ? const Icon(
                                      Icons.person,
                                      color: AppColors.textLight,
                                      size: 24,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            
                            // Review Content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    review['userName'] as String? ?? 'Anonymous',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  
                                  // Star Rating
                                  Row(
                                    children: List.generate(5, (index) {
                                      final rating = review['rating'] as int? ?? 0;
                                      return Icon(
                                        Icons.star,
                                        size: 16,
                                        color: index < rating
                                            ? AppColors.warning
                                            : AppColors.lightGrey,
                                      );
                                    }),
                                  ),
                                  const SizedBox(height: 8),
                                  
                                  Text(
                                    review['comment'] as String? ?? '',
                                    style: AppTextStyles.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                );
              }
              
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  void _editProduct() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProductScreen(
          product: _productData,
        ),
      ),
    ).then((_) {
      // Refresh products after editing
      if (mounted) {
        context.read<SellerProductsCubit>().fetchSellerProducts();
      }
    });
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Close button and warning icon on same line
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete,
                        color: AppColors.error,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 40), // Spacer to center the icon
                  ],
                ),
                const SizedBox(height: 16),
                
                // Title
                Text(
                  'Delete Product',
                  style: AppTextStyles.heading2.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Warning text
                Text(
                  'Are you sure you want to delete this product? This action cannot be undone.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: BorderSide(color: AppColors.lightGrey),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          'Cancel',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _deleteProduct();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                        ),
                        child: Text(
                          'Delete',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _deleteProduct() {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    // Delete product
    context.read<AddProductCubit>().deleteProduct(_productId).then((_) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        
        // Check result
        final state = context.read<AddProductCubit>().state;
        if (state is AddProductSuccess) {
          // Refresh products list
          context.read<SellerProductsCubit>().fetchSellerProducts();
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.success,
            ),
          );
          
          // Navigate back to dashboard
          Navigator.pop(context);
        } else if (state is AddProductError) {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    });
  }

  void _toggleProductStatus() {
    // TODO: Implement toggle product status (active/inactive)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Product status updated!'),
        backgroundColor: AppColors.success,
      ),
    );
  }
}
