import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../widgets/admin_drawer.dart';
import '../../controller/admin_reported_products/cubit.dart';
import '../../controller/admin_reported_products/state.dart';
import 'admin_reported_product_detail_screen.dart';

class AdminReportedProductsListScreen extends StatefulWidget {
  const AdminReportedProductsListScreen({super.key});

  @override
  State<AdminReportedProductsListScreen> createState() => _AdminReportedProductsListScreenState();
}

class _AdminReportedProductsListScreenState extends State<AdminReportedProductsListScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();

  final Set<String> _expandedCards = {};

  @override
  void initState() {
    super.initState();
    context.read<AdminReportedProductsCubit>().fetchReportedProducts();
  }

  List<Map<String, dynamic>> _getFilteredProducts(List<Map<String, dynamic>> products) {
    if (_searchController.text.isEmpty) {
      return products;
    }
    
    final searchLower = _searchController.text.toLowerCase();
    return products.where((product) {
      final productName = (product['productName'] as String? ?? '').toLowerCase();
      final reporterName = (product['reporter']?['name'] as String? ?? '').toLowerCase();
      final reason = (product['reporter']?['reason'] as String? ?? '').toLowerCase();
      
      return productName.contains(searchLower) ||
          reporterName.contains(searchLower) ||
          reason.contains(searchLower);
    }).toList();
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Reported Products Section
                    _buildReportedProductsSection(),
                    
                    const SizedBox(height: 20),
                    
                    // Product List
                    BlocBuilder<AdminReportedProductsCubit, AdminReportedProductsState>(
                      builder: (context, state) {
                        if (state is AdminReportedProductsLoading) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(50.0),
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.adminPrimary),
                              ),
                            ),
                          );
                        }
                        
                        if (state is AdminReportedProductsError) {
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
                                    context.read<AdminReportedProductsCubit>().fetchReportedProducts();
                                  },
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          );
                        }
                        
                        if (state is AdminReportedProductsLoaded) {
                          final filteredProducts = _getFilteredProducts(state.reportedProducts);
                          
                          if (filteredProducts.isEmpty) {
                            return _buildEmptyState();
                          }
                          
                          return _buildProductList(filteredProducts);
                        }
                        
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      drawer: const AdminDrawer(currentScreen: 'admin_reported_products_list'),
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

  Widget _buildReportedProductsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          'Reported Products',
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
              hintText: 'Search your product',
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 50),
          Icon(
            Icons.report_problem_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No reported products found',
            style: AppTextStyles.bodyLarge.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList(List<Map<String, dynamic>> products) {

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
    final productId = product['id'] as String? ?? '';
    final isExpanded = _expandedCards.contains(productId);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          // Main Product Card (Always Visible)
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdminReportedProductDetailScreen(product: product),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
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
                        child: product['image'] != null && (product['image'] as String).isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: product['image'] as String,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.adminPrimary),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => const Icon(
                                    Icons.image,
                                    color: Colors.grey,
                                    size: 40,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.image,
                                color: Colors.grey,
                                size: 40,
                              ),
                      ),
                      if (product['resolved'] == true)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Resolved',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
                        // Product Name
                        Text(
                          product['productName'],
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        const SizedBox(height: 4),
                        
                        // Price
                        Text(
                          product['price'],
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.adminPrimary,
                          ),
                        ),
                        
                        // Rating (only show if product has ratings)
                        if (product['rating'] != null && (product['rating'] as num) > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: List.generate(5, (starIndex) {
                              final rating = (product['rating'] as num).toDouble();
                              return Icon(
                                starIndex < rating.round() ? Icons.star : Icons.star_border,
                                color: Colors.amber,
                                size: 16,
                              );
                            }),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Expand/Collapse Icon
                  IconButton(
                    icon: Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.adminPrimary,
                    ),
                    onPressed: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedCards.remove(productId);
                        } else {
                          _expandedCards.add(productId);
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          
          // Expandable Seller and Reporter Information
          if (isExpanded)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Title
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: AppColors.adminPrimary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Seller & Reporter Information',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.adminPrimary,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Seller and Reporter in Row
                  Row(
                    children: [
                      // Seller Information
                      Expanded(
                        child: _buildInfoCard(
                          title: 'Seller',
                          icon: Icons.store,
                          iconColor: AppColors.adminPrimary,
                          backgroundColor: AppColors.adminPrimary.withOpacity(0.1),
                          borderColor: AppColors.adminPrimary.withOpacity(0.3),
                          name: product['seller']?['name'] ?? 'N/A',
                          phone: product['seller']?['phone'] ?? 'N/A',
                          email: product['seller']?['email'],
                          whatsapp: product['seller']?['whatsapp'],
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // Reporter Information
                      Expanded(
                        child: _buildInfoCard(
                          title: 'Reporter',
                          icon: Icons.person,
                          iconColor: Colors.red,
                          backgroundColor: Colors.red[50]!,
                          borderColor: Colors.red[200]!,
                          name: product['reporter']?['name'] ?? 'N/A',
                          phone: product['reporter']?['mobile'],
                          email: product['reporter']?['email'],
                          reportDate: product['reporter']?['reportDate'],
                          reportReason: product['reporter']?['reason'],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required Color borderColor,
    required String name,
    String? phone,
    String? email,
    String? whatsapp,
    String? reportDate,
    String? reportReason,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: borderColor,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Icon and Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Name
          _buildInfoRow(
            icon: Icons.person_outline,
            label: 'Name',
            value: name,
            iconColor: iconColor,
          ),
          
          // Phone
          if (phone != null && phone.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: phone,
              iconColor: iconColor,
            ),
          ],
          
          
          // WhatsApp
          if (whatsapp != null && whatsapp.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              icon: Icons.chat,
              label: 'WhatsApp',
              value: whatsapp,
              iconColor: Colors.green,
            ),
          ],
          
          // Report Date (for Reporter)
          if (reportDate != null && reportDate.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              icon: Icons.calendar_today,
              label: 'Report Date',
              value: reportDate,
              iconColor: iconColor,
            ),
          ],
          
          // Report Reason (for Reporter)
          if (reportReason != null && reportReason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.report_problem_outlined,
                  size: 14,
                  color: iconColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reason',
                        style: AppTextStyles.caption.copyWith(
                          color: iconColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        reportReason,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 11,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    bool isEmail = false,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: iconColor,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: iconColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.bodySmall.copyWith(
                  fontSize: 11,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: isEmail ? 2 : 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }


  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
