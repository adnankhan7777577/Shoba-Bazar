import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../widgets/custom_snackbar.dart';
import 'admin_edit_product_screen.dart';
import '../../controller/add_product/cubit.dart';
import '../../controller/add_product/state.dart';
import '../../widgets/full_screen_image_viewer.dart';

class AdminProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const AdminProductDetailScreen({
    super.key,
    required this.product,
  });

  @override
  State<AdminProductDetailScreen> createState() => _AdminProductDetailScreenState();
}

class _AdminProductDetailScreenState extends State<AdminProductDetailScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  int _currentImageIndex = 0;
  bool _isLoading = true;
  bool _isLoadingReviews = false;

  // Product data from database
  Map<String, dynamic>? _productData;
  List<String> _productImages = [];
  Map<String, dynamic>? _sellerData;
  List<Map<String, dynamic>> _reviews = [];
  bool _canEdit = false;
  bool _canDelete = false;
  String? _adminUserId;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    try {
      // Get current user
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Get admin user data
      final userResponse = await _supabase
          .from('users')
          .select('id')
          .eq('auth_id', user.id)
          .single();

      _adminUserId = userResponse['id'] as String;

      await _loadProductDetails();
      _loadReviews();
    } catch (e) {
      print('Error loading admin data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProductDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final productId = widget.product['id'] as String?;
      if (productId == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Fetch full product details with IDs for editing
      final productResponse = await _supabase
          .from('products')
          .select('''
            id,
            name,
            description,
            usage,
            origin,
            price,
            seller_id,
            category_id,
            type_id,
            brand_id,
            model_id,
            year_id,
            price_type_id,
            price_types(name),
            product_categories(id, name),
            product_brands(id, name),
            product_types(id, name),
            product_models(id, name),
            product_years(id, year),
            sellers(user_id)
          ''')
          .eq('id', productId)
          .single();

      // Fetch product images
      final imagesResponse = await _supabase
          .from('product_images')
          .select('image_url')
          .eq('product_id', productId)
          .order('display_order', ascending: true);

      final images = (imagesResponse as List)
          .map((img) => img['image_url'] as String)
          .toList();

      // Check if product belongs to admin
      final sellerData = productResponse['sellers'] as Map<String, dynamic>?;
      final sellerUserId = sellerData?['user_id'] as String?;
      final isAdminProduct = sellerUserId == _adminUserId;

      // Admin can edit/delete their own products, seller can delete their products
      _canEdit = isAdminProduct;
      _canDelete = isAdminProduct; // Admin can delete their own products

      // Fetch seller information
      final sellerId = productResponse['seller_id'] as String?;
      Map<String, dynamic>? sellerInfo;
      
      if (sellerId != null) {
        try {
          // Get seller data
          final sellerResponse = await _supabase
              .from('sellers')
              .select('user_id, shop_address, whatsapp')
              .eq('id', sellerId)
              .single();

          final userId = sellerResponse['user_id'] as String?;
          
          if (userId != null) {
            // Get user data for seller
            final userResponse = await _supabase
                .from('users')
                .select('name, email, mobile, city, country, profile_picture_url')
                .eq('id', userId)
                .single();

            sellerInfo = {
              'name': userResponse['name'] as String? ?? 'Seller',
              'email': userResponse['email'] as String? ?? '',
              'phone': userResponse['mobile'] as String? ?? '',
              'city': userResponse['city'] as String? ?? '',
              'country': userResponse['country'] as String? ?? '',
              'shop_address': sellerResponse['shop_address'] as String? ?? '',
              'whatsapp': sellerResponse['whatsapp'] as String? ?? '',
              'avatar': userResponse['profile_picture_url'] as String?,
            };
          }
        } catch (e) {
          print('Error fetching seller info: $e');
        }
      }

      // Format price
      final price = productResponse['price'] as num? ?? 0.0;
      final priceType = productResponse['price_types'] as Map<String, dynamic>?;
      final currency = priceType?['name'] as String? ?? 'PKR';
      final priceString = price.toStringAsFixed(0);
      final formattedPriceValue = priceString.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );

      // Get category name
      final category = productResponse['product_categories'] as Map<String, dynamic>?;
      final categoryName = category?['name'] as String? ?? '';

      // Build tags
      final usage = productResponse['usage'] as String? ?? '';
      final origin = productResponse['origin'] as String? ?? '';
      final tags = <String>[];
      if (usage.isNotEmpty) tags.add(usage);
      if (origin.isNotEmpty) tags.add(origin);

      setState(() {
        _productData = {
          ...productResponse,
          'formatted_price': '$currency $formattedPriceValue',
          'category': categoryName,
          'tags': tags,
          'images': images, // Include images in product data for edit screen
        };
        _productImages = images;
        _sellerData = sellerInfo;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading product details: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadReviews() async {
    final productId = widget.product['id'] as String?;
    if (productId == null) return;

    setState(() {
      _isLoadingReviews = true;
    });

    try {
      // Fetch all ratings for this product with customer and user information
      final ratingsResponse = await _supabase
          .from('product_ratings')
          .select('''
            id,
            rating,
            comment,
            created_at,
            customer_id,
            customers(
              user_id,
              users(
                id,
                name,
                profile_picture_url
              )
            )
          ''')
          .eq('product_id', productId)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> reviews = [];
      
      for (var rating in ratingsResponse) {
        final customerData = rating['customers'] as Map<String, dynamic>?;
        final userData = customerData?['users'] as Map<String, dynamic>?;
        
        final userName = userData?['name'] as String? ?? 'Anonymous';
        final profilePictureUrl = userData?['profile_picture_url'] as String?;
        final ratingValue = rating['rating'] as int? ?? 0;
        final comment = rating['comment'] as String? ?? '';

        reviews.add({
          'userName': userName,
          'rating': ratingValue,
          'comment': comment,
          'avatar': profilePictureUrl,
        });
      }

      setState(() {
        _reviews = reviews;
        _isLoadingReviews = false;
      });
    } catch (e) {
      print('Error loading reviews: $e');
      setState(() {
        _isLoadingReviews = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.adminPrimary),
          ),
        ),
      );
    }

    if (_productData == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.adminPrimary,
          foregroundColor: AppColors.white,
        ),
        body: const Center(
          child: Text('Product not found'),
        ),
      );
    }

    return BlocListener<AddProductCubit, AddProductState>(
      listener: (context, state) {
        if (state is AddProductSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context);
        } else if (state is AddProductError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: Scaffold(
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
                      if (_sellerData != null) ...[
                        _buildSellerSection(),
                        const SizedBox(height: 20),
                      ],
                      _buildReviewsSection(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    if (_productImages.isEmpty) {
      return Container(
        height: 300,
        color: Colors.grey[200],
        child: const Center(
          child: Icon(
            Icons.image,
            size: 64,
            color: Colors.grey,
          ),
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
                    images: _productImages,
                    initialIndex: _currentImageIndex,
                  ),
                ),
              );
            },
            child: FlutterCarousel.builder(
              itemCount: _productImages.length,
              itemBuilder: (context, index, realIndex) {
                return Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                  ),
                  child: CachedNetworkImage(
                    imageUrl: _productImages[index],
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.adminPrimary),
                      ),
                    ),
                    errorWidget: (context, url, error) => const Icon(
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
                  color: AppColors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
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
          ),
          
          // Image Indicators
          if (_productImages.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _productImages.length,
                  (index) => Container(
                    width: index == _currentImageIndex ? 12 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: index == _currentImageIndex 
                          ? AppColors.adminPrimary 
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
    final productName = _productData!['name'] as String? ?? 'Unknown Product';
    final description = _productData!['description'] as String? ?? '';
    final formattedPrice = _productData!['formatted_price'] as String? ?? 'PKR 0';
    final tags = _productData!['tags'] as List<String>? ?? [];

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Name
          Text(
            productName,
            style: AppTextStyles.heading2.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // Description
          if (description.isNotEmpty)
            Text(
              description,
              style: AppTextStyles.bodyMedium.copyWith(
                height: 1.5,
              ),
            ),
          if (description.isNotEmpty) const SizedBox(height: 16),
          
          // Tags
          if (tags.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map<Widget>((tag) {
                Color backgroundColor;
                Color borderColor;
                Color textColor;
                
                switch (tag) {
                  case 'New':
                    backgroundColor = AppColors.info.withOpacity(0.1);
                    borderColor = AppColors.info;
                    textColor = AppColors.info;
                    break;
                  case 'Used':
                    backgroundColor = AppColors.success.withOpacity(0.1);
                    borderColor = AppColors.success;
                    textColor = AppColors.success;
                    break;
                  case 'Imported':
                    backgroundColor = AppColors.adminPrimary.withOpacity(0.1);
                    borderColor = AppColors.adminPrimary;
                    textColor = AppColors.adminPrimary;
                    break;
                  case 'Local':
                    backgroundColor = AppColors.warning.withOpacity(0.1);
                    borderColor = AppColors.warning;
                    textColor = AppColors.warning;
                    break;
                  default:
                    backgroundColor = AppColors.lightGrey.withOpacity(0.1);
                    borderColor = AppColors.lightGrey;
                    textColor = AppColors.textLight;
                }
                
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    border: Border.all(color: borderColor),
                    borderRadius: BorderRadius.circular(20),
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
                      TextSpan(
                        text: formattedPrice.split(' ')[0] + ' ',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textLight,
                        ),
                      ),
                      TextSpan(
                        text: formattedPrice.split(' ').length > 1 
                            ? formattedPrice.split(' ').sublist(1).join(' ')
                            : '',
                        style: AppTextStyles.heading1.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Action Icons - only show if can edit or delete
              if (_canEdit || _canDelete)
                Row(
                  children: [
                    const SizedBox(width: 12),
                    if (_canEdit)
                      _buildActionIcon(
                        icon: Icons.edit,
                        color: AppColors.adminPrimary,
                        onTap: () {
                          _editProduct();
                        },
                      ),
                    if (_canEdit && _canDelete) const SizedBox(width: 12),
                    if (_canDelete)
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
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
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
    if (_sellerData == null) return const SizedBox.shrink();
    
    return Container(
      color: AppColors.surface,
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
                backgroundColor: AppColors.background,
                backgroundImage: _sellerData!['avatar'] != null
                    ? CachedNetworkImageProvider(_sellerData!['avatar'] as String)
                    : null,
                child: _sellerData!['avatar'] == null
                    ? const Icon(Icons.person, size: 30)
                    : null,
              ),
              const SizedBox(width: 12),
              
              // Seller Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _sellerData!['name'] as String? ?? 'Seller',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Contact Details
                   
                    if (_sellerData!['phone'] != null && (_sellerData!['phone'] as String).isNotEmpty)
                      _buildContactDetail(Icons.phone, _sellerData!['phone'] as String),
                    if (_sellerData!['phone'] != null && (_sellerData!['phone'] as String).isNotEmpty)
                      const SizedBox(height: 4),
                    if (_sellerData!['shop_address'] != null && (_sellerData!['shop_address'] as String).isNotEmpty)
                      _buildContactDetail(Icons.location_on, _sellerData!['shop_address'] as String),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // WhatsApp Contact Button
          if ((_sellerData!['whatsapp'] != null && (_sellerData!['whatsapp'] as String).isNotEmpty) ||
              (_sellerData!['phone'] != null && (_sellerData!['phone'] as String).isNotEmpty))
            Container(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  _contactSeller();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0DC143),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: Image.asset(
                  'assets/images/whatsapp.png',
                  width: 24,
                  height: 24,
                ),
                label: Text(
                  'Contact Seller',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _contactSeller() async {
    if (_sellerData == null) return;
    
    final whatsapp = _sellerData!['whatsapp'] as String?;
    final phone = _sellerData!['phone'] as String?;
    final contactNumber = whatsapp?.isNotEmpty == true ? whatsapp : phone;
    
    if (contactNumber == null || contactNumber.isEmpty) {
      CustomSnackBar.showError(context, 'Contact number not available');
      return;
    }

    // Clean the number: remove all non-numeric characters except +
    String cleanNumber = contactNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    
    // If number doesn't start with +, handle local format
    if (!cleanNumber.startsWith('+')) {
      // If it starts with 0, remove it (local format like 0912345678)
      if (cleanNumber.startsWith('0')) {
        cleanNumber = cleanNumber.substring(1);
      }
    }
    
    if (cleanNumber.isEmpty) {
      CustomSnackBar.showError(context, 'Invalid WhatsApp number');
      return;
    }

    // Create default message indicating admin is contacting from Shoba Bazar app
    String defaultMessage = 'Hello! I am contacting you regarding your product listing on Shoba Bazar app.';
    
    // Add product name if available
    if (_productData != null) {
      final productName = _productData!['name'] as String?;
      if (productName != null && productName.isNotEmpty) {
        defaultMessage = 'Hello! I am contacting you regarding "$productName" on Shoba Bazar app.';
      }
    }
    
    // URL encode the message
    final encodedMessage = Uri.encodeComponent(defaultMessage);
    
    // Use whatsapp:// scheme to open personal WhatsApp (not WhatsApp Business)
    final whatsappUrl = 'whatsapp://send?phone=$cleanNumber&text=$encodedMessage';
    
    try {
      final uri = Uri.parse(whatsappUrl);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      
      if (!launched) {
        // Fallback to wa.me if whatsapp:// scheme fails
        final fallbackUrl = 'https://wa.me/$cleanNumber?text=$encodedMessage';
        final fallbackUri = Uri.parse(fallbackUrl);
        final fallbackLaunched = await launchUrl(
          fallbackUri,
          mode: LaunchMode.externalApplication,
        );
        
        if (!fallbackLaunched && mounted) {
          CustomSnackBar.showError(context, 'Could not open WhatsApp. Please make sure WhatsApp is installed.');
        }
      }
    } catch (e) {
      // Try fallback to wa.me if whatsapp:// scheme throws an error
      try {
        final fallbackUrl = 'https://wa.me/$cleanNumber?text=$encodedMessage';
        final fallbackUri = Uri.parse(fallbackUrl);
        await launchUrl(
          fallbackUri,
          mode: LaunchMode.externalApplication,
        );
      } catch (fallbackError) {
        if (mounted) {
          CustomSnackBar.showError(context, 'Could not open WhatsApp. Please make sure WhatsApp is installed.');
        }
      }
    }
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
      color: AppColors.surface,
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
          
          if (_isLoadingReviews)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.adminPrimary),
                ),
              ),
            )
          else if (_reviews.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No ratings and reviews',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textLight,
                  ),
                ),
              ),
            )
          else
            // Reviews List
            ..._reviews.map<Widget>((review) {
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User Avatar
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.background,
                      backgroundImage: review['avatar'] != null
                          ? CachedNetworkImageProvider(review['avatar'] as String)
                          : null,
                      child: review['avatar'] == null
                          ? const Icon(Icons.person, size: 20)
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
      ),
    );
  }

  void _editProduct() {
    if (_productData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product data not loaded. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    
    // Ensure images are included in product data
    final productDataWithImages = Map<String, dynamic>.from(_productData!);
    productDataWithImages['images'] = _productImages; // Use _productImages which is guaranteed to have the images
    
    print('Passing product data to edit screen:');
    print('  - Product ID: ${productDataWithImages['id']}');
    print('  - Images count: ${_productImages.length}');
    print('  - Images: $_productImages');
    print('  - Product data images: ${productDataWithImages['images']}');
    print('  - Full product data keys: ${productDataWithImages.keys.toList()}');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminEditProductScreen(
          product: productDataWithImages,
        ),
      ),
    ).then((_) {
      // Refresh product data after editing
      _loadProductDetails();
    });
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
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
    final productId = _productData!['id'] as String?;
    if (productId == null) return;

    context.read<AddProductCubit>().deleteProduct(productId);
  }
}
