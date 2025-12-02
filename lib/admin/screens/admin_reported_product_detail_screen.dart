import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/full_screen_image_viewer.dart';

class AdminReportedProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const AdminReportedProductDetailScreen({
    super.key,
    required this.product,
  });

  @override
  State<AdminReportedProductDetailScreen> createState() => _AdminReportedProductDetailScreenState();
}

class _AdminReportedProductDetailScreenState extends State<AdminReportedProductDetailScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  int _currentImageIndex = 0;
  bool _isLoading = true;
  bool _isLoadingReviews = false;
  
  // Product data from database
  Map<String, dynamic>? _productData;
  List<String> _productImages = [];
  List<Map<String, dynamic>> _reviews = [];
  double? _averageRating;

  @override
  void initState() {
    super.initState();
    _loadProductDetails();
    _loadReviews();
  }

  Future<void> _loadProductDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final productId = widget.product['productId'] as String?;
      if (productId == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Fetch full product details
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
            sellers(
              user_id,
              whatsapp,
              users(
                id,
                name,
                email,
                mobile,
                profile_picture_url
              )
            )
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

      setState(() {
        _productData = productResponse;
        _productImages = images;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load product details: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _loadReviews() async {
    final productId = widget.product['productId'] as String?;
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
      double totalRating = 0.0;
      
      for (var rating in ratingsResponse) {
        final customerData = rating['customers'] as Map<String, dynamic>?;
        final userData = customerData?['users'] as Map<String, dynamic>?;
        
        final userName = userData?['name'] as String? ?? 'Anonymous';
        final profilePictureUrl = userData?['profile_picture_url'] as String?;
        final ratingValue = rating['rating'] as int? ?? 0;
        final comment = rating['comment'] as String? ?? '';
        final createdAt = rating['created_at'] as String?;

        totalRating += ratingValue;

        reviews.add({
          'userName': userName,
          'rating': ratingValue,
          'comment': comment,
          'avatar': profilePictureUrl,
          'createdAt': createdAt,
        });
      }

      double? averageRating;
      if (reviews.isNotEmpty) {
        averageRating = totalRating / reviews.length;
      }

      setState(() {
        _reviews = reviews;
        _averageRating = averageRating;
        _isLoadingReviews = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingReviews = false;
      });
    }
  }

  // Get seller data
  Map<String, dynamic>? get _sellerData {
    if (_productData != null) {
      final seller = _productData!['sellers'] as Map<String, dynamic>?;
      final sellerUser = seller?['users'] as Map<String, dynamic>?;
      
      if (sellerUser != null) {
        return {
          'name': sellerUser['name'] as String?,
          'email': sellerUser['email'] as String?,
          'phone': sellerUser['mobile'] as String?,
          'whatsapp': seller?['whatsapp'] as String?,
          'avatar': sellerUser['profile_picture_url'] as String?,
        };
      }
    }
    
    // Fallback to product data from widget
    return widget.product['seller'] as Map<String, dynamic>?;
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
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.adminPrimary),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Product Image Carousel
                          _buildImageCarousel(),
                          
                          const SizedBox(height: 20),
                          
                          // Product Details
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Product Title & Description
                                _buildProductInfo(),
                                
                                const SizedBox(height: 20),
                                
                                // Tags
                                _buildTags(),
                                
                                const SizedBox(height: 20),
                                
                                // Price Section
                                _buildPriceSection(),
                                
                                const SizedBox(height: 12),

                                // WhatsApp Contact (below price)
                                _buildWhatsappSection(),
                                
                                const SizedBox(height: 20),
                                
                                // Seller Details
                                _buildSellerSection(),
                                
                                const SizedBox(height: 20),
                                
                                // Rating and Reviews (only show if there are ratings)
                                if (_averageRating != null && _averageRating! > 0)
                                  _buildRatingAndReviews(),
                                
                                const SizedBox(height: 20),
                                
                                // Report Information
                                _buildReportInfo(),

                                // Bottom spacing
                                const SizedBox(height: 40),
                              ],
                            ),
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
                'Reported Product',
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

  Widget _buildImageCarousel() {
    if (_productImages.isEmpty) {
      return Container(
        height: 300,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Icon(
            Icons.image,
            color: Colors.grey,
            size: 80,
          ),
        ),
      );
    }

    return Container(
      height: 300,
      width: double.infinity,
      child: Stack(
        children: [
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: _productImages[index],
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.adminPrimary),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.image,
                          color: Colors.grey,
                          size: 80,
                        ),
                      ),
                    ),
                  ),
                );
              },
              options: FlutterCarouselOptions(
                height: 300,
                viewportFraction: 1.0,
                enableInfiniteScroll: _productImages.length > 1,
                autoPlay: _productImages.length > 1,
                autoPlayInterval: const Duration(seconds: 3),
                onPageChanged: (index, reason) {
                  setState(() {
                    _currentImageIndex = index;
                  });
                },
              ),
            ),
          ),
          
          // Image Dots Indicator
          if (_productImages.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_productImages.length, (index) {
                  return Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: index == _currentImageIndex ? AppColors.adminPrimary : Colors.white,
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductInfo() {
    final productName = _productData?['name'] as String? ?? widget.product['productName'] as String? ?? 'Unknown Product';
    final description = _productData?['description'] as String?;
    final usage = _productData?['usage'] as String?;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Product Title
        Text(
          productName,
          style: AppTextStyles.heading2.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Product Description
        if (description != null && description.isNotEmpty)
          Text(
            description,
            style: AppTextStyles.bodyMedium.copyWith(
              height: 1.5,
              color: AppColors.textLight,
            ),
          ),
        
        // Usage information
        if (usage != null && usage.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Usage: $usage',
            style: AppTextStyles.bodyMedium.copyWith(
              height: 1.5,
              color: AppColors.textLight,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTags() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green[100],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green),
          ),
          child: Text(
            'Used',
            style: AppTextStyles.bodySmall.copyWith(
              color: Colors.green[800],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange),
          ),
          child: Text(
            'Local',
            style: AppTextStyles.bodySmall.copyWith(
              color: Colors.orange,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceSection() {
    String priceText = widget.product['price'] as String? ?? 'N/A';
    
    // If we have product data, format price from it
    if (_productData != null) {
      final price = _productData!['price'] as num? ?? 0.0;
      final priceType = _productData!['price_types'] as Map<String, dynamic>?;
      final currency = priceType?['name'] as String? ?? 'PKR';
      final priceString = price.toStringAsFixed(0);
      final formattedPriceValue = priceString.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
      priceText = '$currency $formattedPriceValue';
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Price
        Text(
          priceText,
          style: AppTextStyles.heading2.copyWith(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.adminPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildWhatsappSection() {
    final seller = _sellerData;
    final String number = (seller != null 
        ? (seller['whatsapp'] ?? seller['phone'] ?? '')
        : (widget.product['whatsapp'] ?? widget.product['sellerWhatsapp'] ?? widget.product['seller_whatsapp'] ?? '091 23456789')).toString();
    final bool hasNumber = number.isNotEmpty;

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset(
              'assets/images/whatsapp.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            hasNumber ? number : '091 23456789',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (hasNumber)
          TextButton(
            onPressed: () => _openWhatsapp(number),
            style: TextButton.styleFrom(
              foregroundColor: Colors.green[800],
            ),
            child: const Text('Chat'),
          ),
      ],
    );
  }

  Widget _buildSellerSection() {
    final seller = _sellerData;
    
    if (seller == null) {
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
          border: Border.all(
            color: Colors.grey.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.store,
                  color: Colors.grey[600],
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Seller Details',
                  style: AppTextStyles.heading3.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Seller information not available',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textLight,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }
    
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
        border: Border.all(
          color: AppColors.adminPrimary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.adminPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.store,
                  color: AppColors.adminPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seller Information',
                      style: AppTextStyles.heading3.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.adminPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Product seller details',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Seller Info Section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Seller Avatar
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(35),
                  border: Border.all(
                    color: AppColors.adminPrimary,
                    width: 2,
                  ),
                ),
                child: seller['avatar'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(35),
                        child: Image.network(
                          seller['avatar'] as String,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.person,
                              color: Colors.grey,
                              size: 35,
                            );
                          },
                        ),
                      )
                    : const Icon(
                        Icons.person,
                        color: Colors.grey,
                        size: 35,
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
                      seller['name'] ?? 'N/A',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    
                    // Phone
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.adminPrimary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.phone,
                              color: AppColors.adminPrimary,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Phone',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textLight,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  seller['phone'] ?? 'N/A',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Address
                    if (seller['address'] != null) ...[
                      const Divider(height: 1),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.adminPrimary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: AppColors.adminPrimary,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Address',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textLight,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    seller['address'] as String,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    // WhatsApp
                    if (seller['whatsapp'] != null || seller['phone'] != null) ...[
                      const Divider(height: 1),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Image.asset(
                                  'assets/images/whatsapp.png',
                                  width: 12,
                                  height: 12,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'WhatsApp',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textLight,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    seller['whatsapp'] ?? seller['phone'] ?? 'N/A',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openWhatsapp(String rawNumber) async {
    final number = rawNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    
    // Create default message indicating admin is contacting from Shoba Bazar app
    String defaultMessage = 'Hello! I am contacting you regarding a reported product on Shoba Bazar app.';
    
    // Add product name if available
    if (_productData != null) {
      final productName = _productData!['name'] as String?;
      if (productName != null && productName.isNotEmpty) {
        defaultMessage = 'Hello! I am contacting you regarding the reported product "$productName" on Shoba Bazar app.';
      }
    }
    
    // URL encode the message
    final encodedMessage = Uri.encodeComponent(defaultMessage);
    final uri = Uri.parse('https://wa.me/$number?text=$encodedMessage');
    
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // ignore failure silently in admin view
    }
  }

  Widget _buildRatingAndReviews() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Rating and reviews',
              style: AppTextStyles.heading3.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_averageRating != null) ...[
              const SizedBox(width: 12),
              Row(
                children: [
                  ...List.generate(5, (index) {
                    return Icon(
                      index < _averageRating!.round() ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 20,
                    );
                  }),
                  const SizedBox(width: 8),
                  Text(
                    _averageRating!.toStringAsFixed(1),
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    ' (${_reviews.length} ${_reviews.length == 1 ? 'review' : 'reviews'})',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ],
          ],
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
          ..._reviews.map((review) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Reviewer Avatar
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: review['avatar'] != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: CachedNetworkImage(
                              imageUrl: review['avatar'] as String,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => const Icon(
                                Icons.person,
                                color: Colors.grey,
                                size: 20,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            color: Colors.grey,
                            size: 20,
                          ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Review Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Reviewer Name
                        Text(
                          review['userName'] as String? ?? 'Anonymous',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        
                        const SizedBox(height: 4),
                        
                        // Rating Stars
                        Row(
                          children: List.generate(5, (index) {
                            final rating = review['rating'] as int? ?? 0;
                            return Icon(
                              index < rating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 16,
                            );
                          }),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Review Text
                        if (review['comment'] != null && (review['comment'] as String).isNotEmpty)
                          Text(
                            review['comment'] as String,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textLight,
                              height: 1.4,
                            ),
                          ),
                        
                        // Review Date
                        if (review['createdAt'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(review['createdAt'] as String),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
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

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildReportInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red[200]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.report_problem,
                color: Colors.red[600],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Report Information',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.red[800],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Reporter Details
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.person,
                  color: Colors.grey,
                  size: 20,
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reported by: ${widget.product['reporter']['name']}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Date: ${widget.product['reporter']['reportDate']}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Report Reason
          Text(
            'Reason:',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.product['reporter']['reason'],
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.red[700],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
