import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/full_screen_image_viewer.dart';
import '../../controller/product_favorite/cubit.dart';
import '../../controller/product_favorite/state.dart';
import '../../controller/product_rating/cubit.dart';
import '../../controller/product_rating/state.dart';
import '../../controller/product_report/cubit.dart';
import '../../controller/product_report/state.dart';
import '../../controller/product_reviews/cubit.dart';
import '../../controller/product_reviews/state.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailScreen({
    super.key,
    required this.product,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  int _currentImageIndex = 0;
  bool _isFavorited = false;
  bool _hasRated = false;
  int? _userRating;
  String? _userComment;
  bool _isLoading = true;
  bool _isSeller = false; // Track if current user is a seller

  // Product data from database
  Map<String, dynamic>? _productData;
  List<String> _productImages = [];
  Map<String, dynamic>? _sellerData;

  @override
  void initState() {
    super.initState();
    _checkIfUserIsSeller();
    _loadProductDetails();
    // Check favorite status directly from database in initState
    _checkFavoriteStatusDirectly();
    // Also check via cubit for consistency
    _checkFavoriteAndRatingStatus();
    // Load reviews using cubit
    final productId = widget.product['id'] as String?;
    if (productId != null) {
      context.read<ProductReviewsCubit>().fetchProductReviewsWithUserCheck(productId);
    }
  }

  Future<void> _checkIfUserIsSeller() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _isSeller = false;
        });
        return;
      }

      // Get user role from database
      final userResponse = await _supabase
          .from('users')
          .select('role')
          .eq('auth_id', user.id)
          .maybeSingle();

      if (userResponse != null) {
        final userRole = userResponse['role'] as String?;
        if (mounted) {
          setState(() {
            _isSeller = userRole == 'seller';
          });
        }
      }
    } catch (e) {
      print('Error checking user role: $e');
      if (mounted) {
        setState(() {
          _isSeller = false;
        });
      }
    }
  }

  Future<void> _checkFavoriteStatusDirectly() async {
    final productId = widget.product['id'] as String?;
    if (productId == null) return;

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Get user_id from users table
      final userResponse = await _supabase
          .from('users')
          .select('id')
          .eq('auth_id', user.id)
          .single();

      final userId = userResponse['id'] as String;

      // Get customer_id from customers table
      final customerResponse = await _supabase
          .from('customers')
          .select('id')
          .eq('user_id', userId)
          .single();

      final customerId = customerResponse['id'] as String;

      // Check if product is favorited
      final favoriteResponse = await _supabase
          .from('product_favorites')
          .select('id')
          .eq('customer_id', customerId)
          .eq('product_id', productId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _isFavorited = favoriteResponse != null;
          print('Direct favorite check: isFavorited=$_isFavorited');
        });
      }
    } catch (e) {
      print('Error checking favorite status directly: $e');
    }
  }

  Future<void> _checkFavoriteAndRatingStatus() async {
    final productId = widget.product['id'] as String?;
    if (productId == null) return;

    // Check favorite status via cubit for consistency
    context.read<ProductFavoriteCubit>().checkFavoriteStatus(productId);
    // Check rating status via cubit
    context.read<ProductRatingCubit>().checkRatingStatus(productId);
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

      // Fetch full product details, check if seller is active
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
            price_types(name),
            product_categories(name),
            product_brands(name),
            product_types(name),
            product_models(name),
            product_years(year),
            sellers(user_id, approval_status, users(is_active, role))
          ''')
          .eq('id', productId)
          .single();

      // Check if seller is approved and active
      // Admin products should always be shown regardless of approval status
      final sellerData = productResponse['sellers'] as Map<String, dynamic>?;
      final userData = sellerData?['users'] as Map<String, dynamic>?;
      final isActive = userData?['is_active'] as bool? ?? false;
      final approvalStatus = sellerData?['approval_status'] as String? ?? 'pending';
      final userRole = userData?['role'] as String?;
      final isAdminProduct = userRole == 'admin';
      
      // Seller is blocked or rejected, show error and go back (unless it's an admin product)
      if (!isAdminProduct && (!isActive || approvalStatus != 'approved')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This product is no longer available. The seller has been blocked.'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context);
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Fetch product images, ordered by display_order
      final imagesResponse = await _supabase
          .from('product_images')
          .select('image_url')
          .eq('product_id', productId)
          .order('display_order', ascending: true);

      final images = (imagesResponse as List)
          .map((img) => img['image_url'] as String)
          .toList();

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
      final formattedPrice = '$currency $formattedPriceValue';

      // Build product data
      final category = productResponse['product_categories'] as Map<String, dynamic>?;
      final categoryName = category?['name'] as String? ?? '';

      // Build tags based on usage, origin, and creation date
      final usage = productResponse['usage'] as String? ?? '';
      final origin = productResponse['origin'] as String? ?? '';
      final tags = <String>[];
      
      // Add usage tag if available
      if (usage.isNotEmpty) {
        tags.add(usage);
      }
      
      // Add origin tag if available
      if (origin.isNotEmpty) {
        tags.add(origin);
      }
      
      // Add "New" tag if product is recent (within last 30 days)
      final createdAt = productResponse['created_at'] as String?;
      if (createdAt != null) {
        final createdDate = DateTime.parse(createdAt);
        final daysSinceCreation = DateTime.now().difference(createdDate).inDays;
        if (daysSinceCreation <= 30) {
          tags.add('New');
        }
      }

      setState(() {
        _productData = {
          'name': productResponse['name'] as String? ?? '',
          'category': categoryName,
          'price': formattedPrice,
          'priceValue': price,
          'currency': currency,
          'description': productResponse['description'] as String? ?? '',
          'usage': productResponse['usage'] as String? ?? '',
          'origin': origin,
          'tags': tags,
        };
        _productImages = images.isNotEmpty ? images : [
          'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1000&q=80',
        ];
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _productData == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return MultiBlocListener(
      listeners: [
        BlocListener<ProductFavoriteCubit, ProductFavoriteState>(
          listener: (context, state) {
            if (state is ProductFavoriteChecked) {
              // Always update from cubit state to ensure consistency
              if (mounted) {
                setState(() {
                  _isFavorited = state.isFavorited;
                  print('Favorite status checked via cubit: isFavorited=$_isFavorited');
                });
              }
            } else if (state is ProductFavoriteToggled) {
              // Update when user toggles favorite
              if (mounted) {
                setState(() {
                  _isFavorited = state.isFavorited;
                  print('Favorite toggled: isFavorited=$_isFavorited');
                });
                CustomSnackBar.showSuccess(
                  context,
                  state.isFavorited
                      ? 'Product added to favorites'
                      : 'Product removed from favorites',
                );
              }
            } else if (state is ProductFavoriteError) {
              print('Favorite error: ${state.message}');
              if (mounted) {
                CustomSnackBar.showError(context, state.message);
              }
            }
          },
        ),
        BlocListener<ProductRatingCubit, ProductRatingState>(
          listener: (context, state) {
            if (state is ProductRatingChecked) {
              // Only update if we don't already have rating info from reviews
              // This prevents overwriting the state if _loadReviews already found the rating
              if (!_hasRated || _userRating == null) {
                setState(() {
                  _hasRated = state.hasRated;
                  _userRating = state.rating;
                  _userComment = state.comment;
                });
              }
            } else if (state is ProductRatingSubmitted) {
              setState(() {
                _hasRated = true;
                _userRating = state.rating;
                _userComment = state.comment;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Rating submitted successfully'),
                ),
              );
              Navigator.of(context).pop(); // Close dialog
              // Refresh rating status and reviews
              final productId = widget.product['id'] as String?;
              if (productId != null) {
                context.read<ProductRatingCubit>().checkRatingStatus(productId);
                context.read<ProductReviewsCubit>().fetchProductReviewsWithUserCheck(productId);
              }
            } else if (state is ProductRatingError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          },
        ),
      ],
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
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      height: 300,
      child: Stack(
        children: [
          // Image Carousel
          _productImages.isEmpty
              ? Container(
                  color: AppColors.background,
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported,
                      size: 64,
                      color: AppColors.textLight,
                    ),
                  ),
                )
              : GestureDetector(
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
                        child: CachedNetworkImage(
                          imageUrl: _productImages[index],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: AppColors.background,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: AppColors.background,
                            child: const Icon(
                              Icons.image_not_supported,
                              size: 64,
                              color: AppColors.textLight,
                            ),
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
          
          // Image Indicators
          if (_productImages.isNotEmpty)
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
    final productData = _productData!;
    final name = productData['name'] as String? ?? '';
    final description = productData['description'] as String? ?? '';
    final tags = productData['tags'] as List<dynamic>? ?? [];
    
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Name
          Text(
            name,
            style: AppTextStyles.heading1.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              height: 1.2,
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
          
          // Tags (Usage, Origin, New, etc.)
          if (tags.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map<Widget>((tag) {
                final tagString = tag.toString();
                final borderColor = _getTagColor(tagString);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: borderColor),
                    borderRadius: BorderRadius.circular(12), // More rounded like the image
                  ),
                  child: Text(
                    tagString,
                    style: AppTextStyles.caption.copyWith(
                      color: borderColor,
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
                child: Text(
                  _productData!['price'] as String,
                  style: AppTextStyles.heading1.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              // Action Icons (hide for sellers)
              if (!_isSeller)
                Row(
                  children: [
                    const SizedBox(width: 12),
                    _buildActionIcon(
                      icon: Icons.star,
                      color: AppColors.warning,
                      onTap: () {
                        _showRateReviewDialog();
                      },
                      isActive: _hasRated,
                    ),
                    const SizedBox(width: 12),
                    _buildActionIcon(
                      icon: Icons.report,
                      color: AppColors.error,
                      onTap: () {
                        _showReportDialog();
                      },
                    ),
                    const SizedBox(width: 12),
                    _buildActionIcon(
                      icon: Icons.favorite,
                      color: AppColors.error,
                      onTap: () {
                        final productId = widget.product['id'] as String?;
                        if (productId != null) {
                          // Pass current favorite status for immediate UI update
                          context.read<ProductFavoriteCubit>().toggleFavorite(
                            productId,
                            currentFavoriteStatus: _isFavorited,
                          );
                        }
                      },
                      isActive: _isFavorited,
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Contact Button
          Container(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                _contactSeller();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: AppColors.white,
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
                'Contact',
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
    bool isActive = false,
  }) {
    // For favorite icon, use filled heart (red) when active, outline (grey) when not
    IconData finalIcon;
    Color finalColor;
    
    if (icon == Icons.favorite) {
      finalIcon = isActive ? Icons.favorite : Icons.favorite_border;
      finalColor = isActive ? AppColors.error : AppColors.textLight; // Red when favorited, grey when not
    } else if (icon == Icons.star) {
      finalIcon = Icons.star;
      finalColor = isActive ? AppColors.warning : AppColors.textLight; // Yellow when rated, grey when not
    } else {
      finalIcon = icon;
      finalColor = isActive ? color : AppColors.textLight;
    }
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.1) : AppColors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive ? color : AppColors.lightGrey,
            width: 1,
          ),
        ),
        child: Icon(
          finalIcon,
          color: finalColor,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildSellerSection() {
    if (_sellerData == null) {
      return const SizedBox.shrink();
    }

    final seller = _sellerData!;
    final sellerName = seller['name'] as String? ?? 'Seller';
    final sellerEmail = seller['email'] as String? ?? '';
    final sellerPhone = seller['phone'] as String? ?? '';
    final sellerCity = seller['city'] as String? ?? '';
    final sellerCountry = seller['country'] as String? ?? '';
    final shopAddress = seller['shop_address'] as String? ?? '';
    final profilePictureUrl = seller['avatar'] as String?;
    
    // Build location string
    final locationParts = <String>[];
    if (sellerCity.isNotEmpty) locationParts.add(sellerCity);
    if (sellerCountry.isNotEmpty) locationParts.add(sellerCountry);
    final location = locationParts.join(', ');
    
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seller',
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
                backgroundImage: profilePictureUrl != null && profilePictureUrl.isNotEmpty
                    ? CachedNetworkImageProvider(profilePictureUrl)
                    : null,
                child: profilePictureUrl == null || profilePictureUrl.isEmpty
                    ? const Icon(
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
                    if (sellerEmail.isNotEmpty) ...[
                      _buildContactDetail(Icons.email, sellerEmail),
                      const SizedBox(height: 4),
                    ],
                    if (sellerPhone.isNotEmpty) ...[
                      _buildContactDetail(Icons.phone, sellerPhone),
                      const SizedBox(height: 4),
                    ],
                    if (location.isNotEmpty) ...[
                      _buildContactDetail(Icons.location_on, location),
                      const SizedBox(height: 4),
                    ],
                    if (shopAddress.isNotEmpty)
                      _buildContactDetail(Icons.store_mall_directory, shopAddress),
                  ],
                ),
              ),
            ],
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

    // Create default message indicating customer is from Shoba Bazar app
    String defaultMessage = 'Hello! I am interested in your product from Shoba Bazar app.';
    
    // Add product name if available
    if (_productData != null) {
      final productName = _productData!['name'] as String?;
      if (productName != null && productName.isNotEmpty) {
        defaultMessage = 'Hello! I am interested in "$productName" from Shoba Bazar app.';
      }
    }
    
    // URL encode the message
    final encodedMessage = Uri.encodeComponent(defaultMessage);
    final whatsappUrl = 'https://wa.me/$cleanNumber?text=$encodedMessage';
    
    try {
      final uri = Uri.parse(whatsappUrl);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      
      if (!launched) {
        if (mounted) {
          CustomSnackBar.showError(context, 'Could not open WhatsApp. Please make sure WhatsApp is installed.');
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, 'Error opening WhatsApp: ${e.toString()}');
      }
    }
  }

  Color _getTagColor(String tag) {
    final tagLower = tag.toLowerCase();
    
    // New tag - Blue
    if (tagLower == 'new') {
      return AppColors.accentBlue;
    }
    
    // Origin tags
    if (tagLower == 'local' || tagLower.contains('local')) {
      return AppColors.accentOrange;
    }
    if (tagLower == 'imported' || tagLower.contains('import')) {
      return const Color(0xFF9B59B6); // Purple
    }
    
    // Usage tags
    if (tagLower == 'used') {
      return const Color(0xFF16A085); // Teal/Green
    }
    if (tagLower == 'refurbished' || tagLower.contains('refurbish')) {
      return const Color(0xFFE67E22); // Orange
    }
    if (tagLower == 'like new' || tagLower.contains('like new')) {
      return const Color(0xFF2ECC71); // Green
    }
    if (tagLower == 'excellent' || tagLower.contains('excellent')) {
      return const Color(0xFF1ABC9C); // Turquoise
    }
    if (tagLower == 'good' || tagLower.contains('good')) {
      return const Color(0xFF3498DB); // Light Blue
    }
    if (tagLower == 'fair' || tagLower.contains('fair')) {
      return const Color(0xFFF39C12); // Yellow/Orange
    }
    
    // Default color for other tags
    return AppColors.accentOrange;
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
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
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
                
                // Check if current user has rated from reviews
                final currentUserReview = reviews.firstWhere(
                  (review) => review['isCurrentUser'] == true,
                  orElse: () => {},
                );
                
                if (currentUserReview.isNotEmpty && (!_hasRated || _userRating == null)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() {
                      _hasRated = true;
                      _userRating = currentUserReview['rating'] as int?;
                      _userComment = currentUserReview['comment'] as String?;
                    });
                  });
                }
                
                if (reviews.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
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
                  children: reviews.map<Widget>((review) {
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
                );
              }
              
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    final TextEditingController reasonController = TextEditingController();
    final productId = widget.product['id'] as String?;
    
    if (productId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product ID not found'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return BlocProvider.value(
          value: context.read<ProductReportCubit>(),
          child: BlocConsumer<ProductReportCubit, ProductReportState>(
            listener: (context, state) {
              if (state is ProductReportSubmitted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: AppColors.success,
                  ),
                );
                reasonController.dispose();
              } else if (state is ProductReportError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            builder: (context, reportState) {
              final isLoading = reportState is ProductReportLoading;
              
              return Dialog(
                backgroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      // Close button and warning icon on same line
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: isLoading ? null : () {
                              reasonController.dispose();
                              Navigator.of(context).pop();
                            },
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
                          Image.asset(
                            'assets/images/report.png',
                            width: 60,
                            height: 60,
                          ),
                          const SizedBox(width: 40), // Spacer to center the image
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Title
                      Text(
                        'Report Item',
                        style: AppTextStyles.heading2.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Instruction text
                      Text(
                        'Please provide details of why you are reporting this item.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      
                      // Report description label
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Report description',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textLight,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Report description text field
                      TextField(
                        controller: reasonController,
                        enabled: !isLoading,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: 'Enter the reason for reporting this product...',
                          hintStyle: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textLight,
                          ),
                          filled: true,
                          fillColor: AppColors.lightGrey.withOpacity(0.3),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppColors.lightGrey,
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppColors.lightGrey,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : () {
                            final reason = reasonController.text.trim();
                            if (reason.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a reason for reporting'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                              return;
                            }
                            context.read<ProductReportCubit>().submitReport(
                              productId: productId,
                              reason: reason,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                                  ),
                                )
                              : Text(
                                  'Submit Report',
                                  style: AppTextStyles.bodyLarge.copyWith(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showRateReviewDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return _RateReviewDialog(
          initialRating: _userRating ?? 0,
          initialComment: _userComment ?? '',
          hasRated: _hasRated,
          onSubmit: (rating, comment) {
            final productId = widget.product['id'] as String?;
            if (productId != null) {
              context.read<ProductRatingCubit>().submitRating(
                productId: productId,
                rating: rating,
                comment: comment,
              );
            }
          },
        );
      },
    );
  }
}

// Separate StatefulWidget for the rating dialog to properly manage TextEditingController
class _RateReviewDialog extends StatefulWidget {
  final int initialRating;
  final String initialComment;
  final bool hasRated;
  final Function(int rating, String comment) onSubmit;

  const _RateReviewDialog({
    required this.initialRating,
    required this.initialComment,
    required this.hasRated,
    required this.onSubmit,
  });

  @override
  State<_RateReviewDialog> createState() => _RateReviewDialogState();
}

class _RateReviewDialogState extends State<_RateReviewDialog> {
  late TextEditingController _commentController;
  late int _selectedRating;
  String? _commentError;
  String? _ratingError;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController(text: widget.initialComment);
    _selectedRating = widget.initialRating;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Close button and star icon on same line
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                    },
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
                  Image.asset(
                    'assets/images/star.png',
                    width: 60,
                    height: 60,
                  ),
                  const SizedBox(width: 40), // Spacer to center the image
                ],
              ),
              const SizedBox(height: 16),
              
              // Title
              Text(
                widget.hasRated ? 'Update Rating & Review' : 'Rate & Review',
                style: AppTextStyles.heading2.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              
              // Star rating
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedRating = index + 1;
                        _ratingError = null; // Clear error when rating changes
                        _commentError = null; // Clear comment error too
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.star,
                        size: 32,
                        color: index < _selectedRating 
                            ? AppColors.warning 
                            : AppColors.lightGrey,
                      ),
                    ),
                  );
                }),
              ),
              if (_ratingError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _ratingError!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              
              // Review label
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Review *',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textLight,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              
              // Review text field
              TextField(
                controller: _commentController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Write your review here...',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textLight,
                  ),
                  filled: true,
                  fillColor: AppColors.lightGrey.withOpacity(0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _commentError != null 
                          ? AppColors.error 
                          : AppColors.lightGrey,
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _commentError != null 
                          ? AppColors.error 
                          : AppColors.lightGrey,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _commentError != null 
                          ? AppColors.error 
                          : AppColors.primary,
                      width: 2,
                    ),
                  ),
                  errorText: _commentError,
                  errorStyle: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                onChanged: (value) {
                  if (value.trim().isNotEmpty && _commentError != null) {
                    setState(() {
                      _commentError = null;
                    });
                  }
                },
              ),
              if (_commentError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _commentError!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              
              // Submit button
              AppButton.primary(
                text: widget.hasRated ? 'Update' : 'Submit',
                onPressed: () {
                  // Validate rating
                  if (_selectedRating == 0) {
                    setState(() {
                      _ratingError = 'Please select a rating';
                    });
                    return;
                  }
                  
                  // Validate comment
                  final comment = _commentController.text.trim();
                  if (comment.isEmpty) {
                    setState(() {
                      _commentError = 'Comment is required';
                    });
                    return;
                  }
                  
                  // Clear any errors
                  setState(() {
                    _ratingError = null;
                    _commentError = null;
                  });
                  
                  // Submit rating
                  widget.onSubmit(_selectedRating, comment);
                },
                size: ButtonSize.large,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
