import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../widgets/admin_drawer.dart';
import '../../controller/admin_sellers/cubit.dart';
import '../../controller/admin_sellers/state.dart';
import 'admin_seller_detail_screen.dart';

class AdminSellerListScreen extends StatefulWidget {
  const AdminSellerListScreen({super.key});

  @override
  State<AdminSellerListScreen> createState() => _AdminSellerListScreenState();
}

class _AdminSellerListScreenState extends State<AdminSellerListScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final SupabaseClient _supabase = Supabase.instance.client;
  String _selectedFilter = 'Approved'; // 'Approved' or 'Blocked'
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<AdminSellersCubit>().fetchSellers();
  }

  List<Map<String, dynamic>> _getFilteredSellers(List<Map<String, dynamic>> allSellers) {
    List<Map<String, dynamic>> sellers = allSellers;
    
    // Apply status filter
    if (_selectedFilter == 'Approved') {
      // Approved: approval_status = 'approved'
      sellers = sellers.where((seller) {
        final approvalStatus = seller['approval_status'] as String? ?? 'pending';
        return approvalStatus == 'approved';
      }).toList();
    } else if (_selectedFilter == 'Blocked') {
      // Blocked: is_active = false
      sellers = sellers.where((seller) => (seller['isBlocked'] as bool? ?? false) == true).toList();
    }
    
    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      sellers = sellers.where((seller) =>
          (seller['name'] as String? ?? '').toLowerCase().contains(query) ||
          (seller['email'] as String? ?? '').toLowerCase().contains(query) ||
          (seller['phone'] as String? ?? '').toLowerCase().contains(query)
      ).toList();
    }
    
    return sellers;
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
                  context.read<AdminSellersCubit>().fetchSellers();
                },
                color: AppColors.adminPrimary,
                child: BlocBuilder<AdminSellersCubit, AdminSellersState>(
                  builder: (context, state) {
                    if (state is AdminSellersLoading) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.adminPrimary),
                          ),
                        ),
                      );
                    }
                    
                    if (state is AdminSellersError) {
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
                                context.read<AdminSellersCubit>().fetchSellers();
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    if (state is AdminSellersLoaded) {
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Sellers Section
                            _buildSellersSection(),
                            
                            const SizedBox(height: 20),
                            
                            // Seller List
                            _buildSellerList(state.sellers),
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
      drawer: const AdminDrawer(currentScreen: 'admin_seller_list'),
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

  Widget _buildSellersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          'Sellers',
          style: AppTextStyles.heading2.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Filter Buttons
        Row(
          children: [
            _buildFilterButton('Approved', _selectedFilter == 'Approved'),
            const SizedBox(width: 12),
            _buildFilterButton('Blocked', _selectedFilter == 'Blocked'),
          ],
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
              hintText: 'Search sellers',
              hintStyle: AppTextStyles.textFieldHint,
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
                        setState(() {});
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

  Widget _buildFilterButton(String title, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = title;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.adminPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.adminPrimary,
            width: 1.5,
          ),
        ),
        child: Text(
          title,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isSelected ? AppColors.white : AppColors.adminPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSellerList(List<Map<String, dynamic>> allSellers) {
    final sellers = _getFilteredSellers(allSellers);
    
    if (sellers.isEmpty) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 50),
            Icon(
              _searchController.text.isNotEmpty ? Icons.search_off : Icons.person_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No sellers found for "${_searchController.text}"'
                  : 'No sellers found',
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
      itemCount: sellers.length,
      itemBuilder: (context, index) {
        return _buildSellerCard(sellers[index]);
      },
    );
  }

  Widget _buildSellerCard(Map<String, dynamic> seller) {
    final profileImageUrl = seller['profile_picture_url'] as String?;
    final name = seller['name'] as String? ?? 'Unknown Seller';
    final email = seller['email'] as String? ?? '';
    final phone = seller['phone'] as String? ?? '';
    final shopAddress = seller['shop_address'] as String? ?? 'Not provided';
    final homeAddress = seller['home_address'] as String? ?? 'Not provided';
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AdminSellerDetailScreen(seller: seller),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Seller Image/Avatar
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
                  child: profileImageUrl != null && profileImageUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(33),
                          child: Image.network(
                            profileImageUrl,
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
                
                const SizedBox(width: 12),
                
                    // Seller Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Seller Name with Status Badge
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: AppTextStyles.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildStatusBadge(seller),
                            ],
                          ),
                          
                          const SizedBox(height: 8),
                      
                      // Email
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.email,
                            color: AppColors.textLight,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              email.isNotEmpty ? email : 'Not provided',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 6),
                      
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
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 6),

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
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 6),
                      
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
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Action Button
            if (_selectedFilter == 'Blocked')
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {
                      _showUnblockConfirmation(seller);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.adminPrimary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Unblock',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Map<String, dynamic> seller) {
    final approvalStatus = seller['approval_status'] as String? ?? 'pending';
    final isActive = seller['is_active'] as bool? ?? true;
    
    String statusText;
    Color statusColor;
    
    if (!isActive) {
      statusText = 'Blocked';
      statusColor = Colors.red;
    } else if (approvalStatus == 'approved') {
      statusText = 'Approved';
      statusColor = Colors.green;
    } else if (approvalStatus == 'rejected') {
      statusText = 'Rejected';
      statusColor = Colors.orange;
    } else {
      statusText = 'Pending';
      statusColor = Colors.grey;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor,
          width: 1,
        ),
      ),
      child: Text(
        statusText,
        style: AppTextStyles.caption.copyWith(
          color: statusColor,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }

  void _showUnblockConfirmation(Map<String, dynamic> seller) {
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
                'Unblock Seller',
                style: AppTextStyles.heading3.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to unblock ${seller['name']}?',
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
                _unblockSeller(seller['id']);
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

  Future<void> _unblockSeller(String sellerId) async {
    try {
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

      // Refresh sellers list
      context.read<AdminSellersCubit>().fetchSellers();
      
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


  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
