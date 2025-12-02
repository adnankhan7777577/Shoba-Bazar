import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../controller/add_product/cubit.dart';
import 'brand_search_screen.dart';

class AllBrandsScreen extends StatefulWidget {
  const AllBrandsScreen({super.key});

  @override
  State<AllBrandsScreen> createState() => _AllBrandsScreenState();
}

class _AllBrandsScreenState extends State<AllBrandsScreen> {
  // Auto parts make data - will be loaded from database
  List<Map<String, dynamic>> _autoPartsMake = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBrands();
  }

  Future<void> _loadBrands() async {
    setState(() {
      _isLoading = true;
    });

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
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading brands: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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

  void _navigateToBrand(Map<String, dynamic> brand) {
    final brandName = brand['name'] as String;
    final brandImage = brand['image'] as String?;
    final brandId = brand['id'] as String;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BrandSearchScreen(
          brandId: brandId,
          brandName: brandName,
          brandImage: brandImage,
        ),
      ),
    );
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
            
            // Brands Grid
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : _autoPartsMake.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.directions_car_outlined,
                                size: 64,
                                color: AppColors.textLight,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No brands available',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textLight,
                                ),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 16),
                              Text(
                                'All Auto Parts Brands',
                                style: AppTextStyles.heading3,
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
                                itemCount: _autoPartsMake.length,
                                itemBuilder: (context, index) {
                                  final maker = _autoPartsMake[index];
                                  final makerName = maker['name'] as String;
                                  final makerImage = maker['image'] as String?;
                                  return GestureDetector(
                                    onTap: () {
                                      _navigateToBrand(maker);
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
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
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Title
          Expanded(
            child: Text(
              'All Auto Parts Brands',
              style: AppTextStyles.heading2.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

