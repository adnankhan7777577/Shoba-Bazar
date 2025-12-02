import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../controller/profile/cubit.dart';
import '../../controller/profile/state.dart';
import '../../controller/add_product/cubit.dart';
import '../../services/banner_service.dart';
import 'customer_search_screen.dart';
import 'category_search_screen.dart';
import 'brand_search_screen.dart';
import 'product_detail_screen.dart';
import 'all_products_screen.dart';
import 'all_categories_screen.dart';
import 'all_brands_screen.dart';

class CustomerDashboardScreen extends StatefulWidget {
  final bool showBackButton;
  
  const CustomerDashboardScreen({
    super.key,
    this.showBackButton = false,
  });

  @override
  State<CustomerDashboardScreen> createState() => _CustomerDashboardScreenState();
}

class _CustomerDashboardScreenState extends State<CustomerDashboardScreen> {
  final PageController _bannerController = PageController();
  int _currentBannerIndex = 0;
  final BannerService _bannerService = BannerService();

  // Banner data for slider - loaded from database
  List<Map<String, dynamic>> _banners = [];
  bool _isLoadingBanners = true;

  // Categories data - will be loaded from database
  List<Map<String, dynamic>> _categories = [
    {'name': 'All', 'icon': 'assets/images/all.png', 'type': 'all', 'id': null, 'image': null}
  ];

  // Auto parts make data - will be loaded from database
  List<Map<String, dynamic>> _autoPartsMake = [];

  // Auto parts featuring data - limited to 8 popular brands
  final List<Map<String, dynamic>> _featuredMakers = [
    {'name': 'Toyota', 'discount': '10% off', 'color': 0xFFE31937},
    {'name': 'Honda', 'discount': '15% off', 'color': 0xFF000000},
    {'name': 'Suzuki', 'discount': '12% off', 'color': 0xFF0066CC},
    {'name': 'Audi', 'discount': '20% off', 'color': 0xFFBB0A30},
    {'name': 'BMW', 'discount': '18% off', 'color': 0xFF0066CC},
    {'name': 'Mercedes', 'discount': '25% off', 'color': 0xFF000000},
    {'name': 'Nissan', 'discount': '14% off', 'color': 0xFFC3002F},
    {'name': 'Hyundai', 'discount': '16% off', 'color': 0xFF002C5F},
  ];

  // Hot deals data - will be loaded from database
  List<Map<String, dynamic>> _hotDeals = [];
  bool _isLoadingHotDeals = true;
  
  // Recently added products data
  List<Map<String, dynamic>> _recentlyAdded = [];
  bool _isLoadingRecentlyAdded = true;

  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    // Load banners from database
    _loadBanners();
    // Auto-scroll banner (will start after banners are loaded)
    // Load categories and brands from database
    _loadCategories();
    _loadBrands();
    // Load products for hot deals
    _loadHotDeals();
    // Load recently added products
    _loadRecentlyAdded();
    // Load user profile
    context.read<ProfileCubit>().fetchProfile(showLoading: false);
  }

  Future<void> _loadBanners() async {
    setState(() {
      _isLoadingBanners = true;
    });

    try {
      final banners = await _bannerService.loadActiveBanners();
      if (mounted) {
        setState(() {
          _banners = banners;
          _isLoadingBanners = false;
        });
        // Start auto-scroll after banners are loaded
        if (_banners.isNotEmpty) {
          _startBannerAutoScroll();
        }
      }
    } catch (e) {
      print('Error loading banners: $e');
      if (mounted) {
        setState(() {
          _isLoadingBanners = false;
        });
      }
    }
  }

  Future<void> _loadCategories() async {
    try {
      final addProductCubit = context.read<AddProductCubit>();
      final dbCategories = await addProductCubit.fetchCategories();
      
      if (mounted) {
        setState(() {
          // Keep "All" first, then add DB categories
          _categories = [
            {'name': 'All', 'icon': 'assets/images/all.png', 'type': 'all', 'id': null, 'image': null},
            ...dbCategories.map((cat) => {
              'name': cat['name'] as String,
              'icon': cat['image'] as String? ?? 'assets/images/all.png',
              'type': (cat['name'] as String).toLowerCase().replaceAll(' ', '_'),
              'id': cat['id'],
              'image': cat['image'] as String?,
            }),
          ];
        });
      }
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  Future<void> _loadBrands() async {
    try {
      final addProductCubit = context.read<AddProductCubit>();
      final dbBrands = await addProductCubit.fetchBrands();
      
      if (mounted) {
        setState(() {
          _autoPartsMake = dbBrands.map((brand) => {
            'name': brand['name'] as String,
            'image': brand['image'] as String?,
            'id': brand['id'],
          }).toList();
        });
      }
    } catch (e) {
      print('Error loading brands: $e');
    }
  }

  Future<void> _loadHotDeals() async {
    if (mounted) {
      setState(() {
        _isLoadingHotDeals = true;
      });
    }

    try {
      // Fetch all products with their first image, only from active sellers
      // Order by created_at ascending (oldest first) for hot deals
      // Limit to 5 products
      final productsResponse = await _supabase
          .from('products')
          .select('''
            id,
            name,
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
          .order('created_at', ascending: true)
          .limit(10); // Fetch more to account for filtered inactive sellers

      // Fetch first image for each product and filter by active sellers
      final List<Map<String, dynamic>> productsWithImages = [];
      
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
        
        // Fetch first image for this product
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

        // Fetch average rating from product_ratings (same as product detail screen)
        double averageRating = 0.0;
        try {
          final ratingsResponse = await _supabase
              .from('product_ratings')
              .select('rating')
              .eq('product_id', productId);
          
          if (ratingsResponse.isNotEmpty) {
            final ratings = ratingsResponse
                .map((rating) => (rating['rating'] as num?) ?? 0.0)
                .toList();
            if (ratings.isNotEmpty) {
              averageRating = ratings.reduce((a, b) => a + b) / ratings.length;
            }
          }
        } catch (e) {
          // Rating calculation failed, use default 0.0
          // Silently handle error - rating will show as 0.0
        }

        // Format price with currency
        final price = product['price'] as num? ?? 0.0;
        final priceType = product['price_types'] as Map<String, dynamic>?;
        final currency = priceType?['name'] as String? ?? 'PKR';
        final priceString = price.toStringAsFixed(0);
        // Add commas for thousands
        final formattedPriceValue = priceString.replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
        final formattedPrice = '$currency $formattedPriceValue';

        productsWithImages.add({
          'id': productId,
          'name': product['name'] as String,
          'price': formattedPrice,
          'image': firstImage,
          'rating': averageRating,
          'product': product, // Store full product data for navigation
        });
        
        // Limit to 5 products after filtering
        if (productsWithImages.length >= 5) {
          break;
        }
      }
      
      if (mounted) {
        setState(() {
          _hotDeals = productsWithImages.take(5).toList();
          _isLoadingHotDeals = false;
        });
      }
    } catch (e) {
      print('Error loading hot deals: $e');
      if (mounted) {
        setState(() {
          _isLoadingHotDeals = false;
        });
      }
    }
  }

  Future<void> _loadRecentlyAdded() async {
    if (mounted) {
      setState(() {
        _isLoadingRecentlyAdded = true;
      });
    }

    try {
      // Fetch recently added products (ordered by created_at descending, limit to 5)
      final productsResponse = await _supabase
          .from('products')
          .select('''
            id,
            name,
            price,
            description,
            usage,
            origin,
            seller_id,
            category_id,
            type_id,
            brand_id,
            model_id,
            created_at,
            price_types(name),
            product_categories(name),
            product_brands(name),
            product_types(name),
            product_models(name),
            sellers(user_id, approval_status, users(is_active, role))
          ''')
          .order('created_at', ascending: false)
          .limit(10); // Fetch more to account for filtered inactive sellers

      // Fetch first image for each product and filter by active sellers
      final List<Map<String, dynamic>> productsWithImages = [];
      
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
        
        // Fetch first image for this product
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

        // Fetch average rating from product_ratings
        double averageRating = 0.0;
        try {
          final ratingsResponse = await _supabase
              .from('product_ratings')
              .select('rating')
              .eq('product_id', productId);
          
          if (ratingsResponse.isNotEmpty) {
            final ratings = ratingsResponse
                .map((rating) => (rating['rating'] as num?) ?? 0.0)
                .toList();
            if (ratings.isNotEmpty) {
              averageRating = ratings.reduce((a, b) => a + b) / ratings.length;
            }
          }
        } catch (e) {
          // Rating calculation failed, use default 0.0
        }

        // Format price with currency
        final price = product['price'] as num? ?? 0.0;
        final priceType = product['price_types'] as Map<String, dynamic>?;
        final currency = priceType?['name'] as String? ?? 'PKR';
        final priceString = price.toStringAsFixed(0);
        // Add commas for thousands
        final formattedPriceValue = priceString.replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
        final formattedPrice = '$currency $formattedPriceValue';

        productsWithImages.add({
          'id': productId,
          'name': product['name'] as String,
          'price': formattedPrice,
          'image': firstImage,
          'rating': averageRating,
          'product': product, // Store full product data for navigation
        });
        
        // Limit to 5 products after filtering
        if (productsWithImages.length >= 5) {
          break;
        }
      }
      
      if (mounted) {
        setState(() {
          _recentlyAdded = productsWithImages.take(5).toList();
          _isLoadingRecentlyAdded = false;
        });
      }
    } catch (e) {
      print('Error loading recently added products: $e');
      if (mounted) {
        setState(() {
          _isLoadingRecentlyAdded = false;
        });
      }
    }
  }

  void _startBannerAutoScroll() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        if (_currentBannerIndex < _banners.length - 1) {
          _bannerController.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        } else {
          _bannerController.animateToPage(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
        _startBannerAutoScroll();
      }
    });
  }

  @override
  void dispose() {
    _bannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header Section with Search only
            _buildHeaderWithSearch(),
            
            // Main Content with Banner
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    
                    // Banner Slider
                    _buildBannerSlider(),
                    
                    const SizedBox(height: 20),
                    
                    // Shop by categories
                    _buildCategoriesSection(),
                    
                    const SizedBox(height: 30),
                    
                    // Auto parts featuring
                    _buildFeaturedMakersSection(),
                    
                    const SizedBox(height: 30),
                    
                    // Auto parts make
                    _buildAutoPartsMakeSection(),
                    
                    const SizedBox(height: 30),
                    
                    // Hot Deals
                    _buildHotDealsSection(),
                    
                    const SizedBox(height: 30),
                    
                    // Recently Added
                    _buildRecentlyAddedSection(),
                    
                    const SizedBox(height: 20), // Reduced space since no bottom nav
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderWithSearch() {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, profileState) {
        String userName = 'Customer';
        String? profilePictureUrl;

        if (profileState is ProfileLoaded || profileState is ProfileRefreshing) {
          final userData = profileState is ProfileLoaded
              ? profileState.userData
              : (profileState as ProfileRefreshing).userData;
          userName = userData['name'] as String? ?? 'Customer';
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
          child: Column(
            children: [
              // Profile and Welcome Section
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // Back Button (if viewing from admin/seller)
                    if (widget.showBackButton) ...[
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
                    ],
                    
                    // Profile Picture
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: AppColors.surface,
                      backgroundImage: profilePictureUrl != null
                          ? CachedNetworkImageProvider(profilePictureUrl)
                          : null,
                      child: profilePictureUrl == null
                          ? const Icon(
                              Icons.person,
                              size: 30,
                              color: AppColors.textLight,
                            )
                          : null,
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
                            userName,
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
              
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CustomerSearchScreen(),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search,
                          color: AppColors.textLight,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Search by product, make',
                          style: AppTextStyles.textFieldHint,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBannerSlider() {
    if (_isLoadingBanners) {
      return Container(
        height: 200,
        margin: const EdgeInsets.symmetric(horizontal: 16.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[200],
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Stack(
        children: [
          // Banner slider
          PageView.builder(
            controller: _bannerController,
            onPageChanged: (index) {
              setState(() {
                _currentBannerIndex = index;
              });
            },
            itemCount: _banners.length,
            itemBuilder: (context, index) {
              final banner = _banners[index];
              final imageUrl = banner['image_url'] as String? ?? '';
              final text = banner['text'] as String? ?? '';
              
              return Container(
                margin: const EdgeInsets.only(right: 8.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[200],
                ),
                child: Stack(
                  children: [
                    // Banner image
                    if (imageUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          imageUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[300],
                              child: const Center(
                                child: Icon(
                                  Icons.broken_image,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    
                    // Gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.black.withOpacity(0.3),
                            Colors.black.withOpacity(0.1),
                          ],
                        ),
                      ),
                    ),
                    
                    // Banner text
                    if (text.isNotEmpty)
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: Text(
                          text,
                          style: AppTextStyles.heading2.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 2,
                                offset: const Offset(1, 1),
                              ),
                            ],
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          
          // Page indicators
          if (_banners.length > 1)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _banners.length,
                  (index) => Container(
                    width: index == _currentBannerIndex ? 12 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: index == _currentBannerIndex 
                          ? AppColors.white 
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

  Widget _buildCategoriesSection() {
    // Limit to first 8 categories for dashboard display
    final displayedCategories = _categories.take(8).toList();
    final hasMoreCategories = _categories.length > 8;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Shop by categories',
              style: AppTextStyles.heading3,
            ),
            if (hasMoreCategories)
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AllCategoriesScreen(),
                    ),
                  );
                },
                child: Text(
                  'See All',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: displayedCategories.length,
          itemBuilder: (context, index) {
            final category = displayedCategories[index];
            return GestureDetector(
              onTap: () {
                _navigateToCategory(category);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.lightGrey),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowLight,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: category['image'] != null && category['image'] is String && (category['image'] as String).startsWith('http')
                            ? CachedNetworkImage(
                                imageUrl: category['image'] as String,
                                fit: BoxFit.contain,
                                width: 30,
                                height: 30,
                                placeholder: (context, url) => const SizedBox(
                                  width: 30,
                                  height: 30,
                                  child: Center(
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Image.asset(
                                  category['icon'] as String,
                                  fit: BoxFit.contain,
                                  width: 30,
                                  height: 30,
                                ),
                              )
                            : Image.asset(
                                category['icon'] as String,
                                fit: BoxFit.contain,
                                width: 30,
                                height: 30,
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      category['name'],
                      style: AppTextStyles.caption,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFeaturedMakersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Auto parts featuring',
          style: AppTextStyles.heading3,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: FlutterCarousel.builder(
            itemCount: _featuredMakers.length,
            itemBuilder: (context, index, realIndex) {
              final maker = _featuredMakers[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(maker['color']).withOpacity(0.9),
                      Color(maker['color']).withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Color(maker['color']).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Background pattern
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: RadialGradient(
                            center: Alignment.topRight,
                            radius: 1.5,
                            colors: [
                              Colors.white.withOpacity(0.1),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Simple clean layout
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Brand name
                          Text(
                            maker['name'],
                            style: AppTextStyles.heading2.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Discount text
                          Text(
                            'get ${maker['discount']} on ${maker['name']} parts',
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          // Large logo - no borders, no complex styling
                          Center(
                            child: _buildMakerLogoWithFallback(maker['name'], 80),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
            options: FlutterCarouselOptions(
              height: 200,
              viewportFraction: 0.85,
              enlargeCenterPage: true,
              enableInfiniteScroll: true,
              autoPlay: true,
              autoPlayInterval: const Duration(seconds: 4),
              autoPlayAnimationDuration: const Duration(milliseconds: 1000),
              autoPlayCurve: Curves.easeInOut,
              pauseAutoPlayOnTouch: true,
              pauseAutoPlayOnManualNavigate: true,
              enlargeFactor: 0.15,
              scrollDirection: Axis.horizontal,
              showIndicator: false, // Hide carousel indicators
            ),
          ),
        ),
      ],
    );
  }


  String _getMakerLogoUrl(String makerName) {
    // Using car-logos-dataset with better fallback
    const carLogosBaseUrl = 'https://raw.githubusercontent.com/filippofilip95/car-logos-dataset/master/logos/optimized';
    
    switch (makerName.toLowerCase()) {
      case 'toyota':
        return '$carLogosBaseUrl/toyota.png';
      case 'honda':
        return '$carLogosBaseUrl/honda.png';
      case 'suzuki':
        return '$carLogosBaseUrl/suzuki.png';
      case 'audi':
        return '$carLogosBaseUrl/audi.png';
      case 'bmw':
        return '$carLogosBaseUrl/bmw.png';
      case 'mercedes':
      case 'mercedes-benz':
        return '$carLogosBaseUrl/mercedes-benz.png';
      case 'nissan':
        return '$carLogosBaseUrl/nissan.png';
      case 'hyundai':
        return '$carLogosBaseUrl/hyundai.png';
      default:
        return '$carLogosBaseUrl/toyota.png';
    }
  }

  Widget _buildMakerLogoWithFallback(String makerName, double size) {
    return CachedNetworkImage(
      imageUrl: _getMakerLogoUrl(makerName),
      width: size,
      height: size,
      fit: BoxFit.contain,
      placeholder: (context, url) => SizedBox(
        width: size,
        height: size,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
          ),
        ),
      ),
      errorWidget: (context, url, error) {
        // Simple fallback with brand-specific styling
        return _buildBrandFallback(makerName, size);
      },
    );
  }

  Widget _buildBrandFallback(String makerName, double size) {
    // Simple fallback styling
    String brandInitial = makerName.substring(0, 1).toUpperCase();
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          brandInitial,
          style: TextStyle(
            color: AppColors.white,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Color _getBrandColor(String makerName) {
    switch (makerName.toLowerCase()) {
      case 'toyota':
        return const Color(0xFFEB0A1E);
      case 'honda':
        return const Color(0xFF000000);
      case 'suzuki':
        return const Color(0xFF0066CC);
      case 'audi':
        return const Color(0xFFBB0A30);
      case 'bmw':
        return const Color(0xFF0066CC);
      case 'mercedes':
        return const Color(0xFF000000);
      case 'nissan':
        return const Color(0xFFC3002F);
      case 'hyundai':
        return const Color(0xFF002C5F);
      default:
        return const Color(0xFF666666);
    }
  }

  Widget _buildAutoPartsMakeSection() {
    if (_autoPartsMake.isEmpty) {
      return const SizedBox.shrink();
    }

    // Limit to first 8 brands for dashboard display
    final displayedBrands = _autoPartsMake.take(8).toList();
    final hasMoreBrands = _autoPartsMake.length > 8;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Auto parts make',
              style: AppTextStyles.heading3,
            ),
            if (hasMoreBrands)
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AllBrandsScreen(),
                    ),
                  );
                },
                child: Text(
                  'See All',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: displayedBrands.length,
          itemBuilder: (context, index) {
            final maker = displayedBrands[index];
            final makerName = maker['name'] as String;
            final makerImage = maker['image'] as String?;
            final makerId = maker['id'] as String;
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BrandSearchScreen(
                      brandId: makerId,
                      brandName: makerName,
                      brandImage: makerImage,
                    ),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.lightGrey),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowLight,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: makerImage != null && makerImage.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: makerImage,
                                width: 30,
                                height: 30,
                                fit: BoxFit.contain,
                                placeholder: (context, url) => SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                  ),
                                ),
                                errorWidget: (context, url, error) {
                                  // Fallback with brand-specific styling
                                  Color brandColor = _getBrandColor(makerName);
                                  return Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: brandColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: brandColor.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        makerName.substring(0, 1).toUpperCase(),
                                        style: TextStyle(
                                          color: brandColor,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Builder(
                                builder: (context) {
                                  // Fallback with brand-specific styling
                                  Color brandColor = _getBrandColor(makerName);
                                  return Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: brandColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: brandColor.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        makerName.substring(0, 1).toUpperCase(),
                                        style: TextStyle(
                                          color: brandColor,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      makerName,
                      style: AppTextStyles.caption,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHotDealsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Hot Deals',
              style: AppTextStyles.heading3,
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AllProductsScreen(
                      title: 'Hot Deals',
                      filterType: 'hot_deals',
                    ),
                  ),
                );
              },
              child: Text(
                'See All',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _isLoadingHotDeals
            ? SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              )
            : _hotDeals.isEmpty
                ? SizedBox(
                    height: 200,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 48,
                            color: AppColors.textLight,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No products available',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _hotDeals.length,
                      itemBuilder: (context, index) {
                        final deal = _hotDeals[index];
                        final productImage = deal['image'] as String?;
                        final productName = deal['name'] as String;
                        final productPrice = deal['price'] as String;
                        final productData = deal['product'] as Map<String, dynamic>;
                        
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
                            width: 140,
                            margin: const EdgeInsets.only(right: 16),
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
                                  height: 95,
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
                                            height: double.infinity,
                                            placeholder: (context, url) => Container(
                                              width: double.infinity,
                                              height: double.infinity,
                                              color: AppColors.background,
                                              child: const Center(
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              ),
                                            ),
                                            errorWidget: (context, url, error) => Container(
                                              width: double.infinity,
                                              height: double.infinity,
                                              color: AppColors.background,
                                              child: const Icon(
                                                Icons.image_not_supported,
                                                color: AppColors.textLight,
                                              ),
                                            ),
                                          )
                                        : Container(
                                            width: double.infinity,
                                            height: double.infinity,
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
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          height: 36,
                                          child: Text(
                                            productName,
                                            style: AppTextStyles.bodySmall,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          productPrice,
                                          style: AppTextStyles.bodyMedium.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.star,
                                              color: AppColors.warning,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              (deal['rating'] as num? ?? 0.0).toStringAsFixed(1),
                                              style: AppTextStyles.caption,
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
                      },
                    ),
                  ),
      ],
    );
  }

  void _navigateToCategory(Map<String, dynamic> category) {
    // Navigate to category search screen with filters
    // If "All", show all products (categoryId is null)
    // Otherwise, filter by category ID
    if (category['type'] == 'all') {
      // For "All", navigate to a screen that shows all products with filters
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CategorySearchScreen(
            categoryId: null,
            categoryName: 'All',
            categoryType: 'all',
          ),
        ),
      );
    } else {
      // For specific categories, navigate with category ID
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CategorySearchScreen(
            categoryId: category['id'] as String?,
            categoryName: category['name'] as String,
            categoryType: category['type'] as String,
          ),
        ),
      );
    }
  }

  Widget _buildRecentlyAddedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recently Added',
              style: AppTextStyles.heading3,
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AllProductsScreen(
                      title: 'Recently Added',
                      filterType: 'recently_added',
                    ),
                  ),
                );
              },
              child: Text(
                'See All',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _isLoadingRecentlyAdded
            ? SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              )
            : _recentlyAdded.isEmpty
                ? SizedBox(
                    height: 200,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 48,
                            color: AppColors.textLight,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No products available',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _recentlyAdded.length,
                      itemBuilder: (context, index) {
                        final product = _recentlyAdded[index];
                        final productImage = product['image'] as String?;
                        final productName = product['name'] as String;
                        final productPrice = product['price'] as String;
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
                            width: 140,
                            margin: const EdgeInsets.only(right: 16),
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
                                  height: 95,
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
                                            height: double.infinity,
                                            placeholder: (context, url) => Container(
                                              width: double.infinity,
                                              height: double.infinity,
                                              color: AppColors.background,
                                              child: const Center(
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              ),
                                            ),
                                            errorWidget: (context, url, error) => Container(
                                              width: double.infinity,
                                              height: double.infinity,
                                              color: AppColors.background,
                                              child: const Icon(
                                                Icons.image_not_supported,
                                                color: AppColors.textLight,
                                              ),
                                            ),
                                          )
                                        : Container(
                                            width: double.infinity,
                                            height: double.infinity,
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
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          height: 36,
                                          child: Text(
                                            productName,
                                            style: AppTextStyles.bodySmall,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          productPrice,
                                          style: AppTextStyles.bodyMedium.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.star,
                                              color: AppColors.warning,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              (product['rating'] as num? ?? 0.0).toStringAsFixed(1),
                                              style: AppTextStyles.caption,
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
                      },
                    ),
                  ),
      ],
    );
  }

}
