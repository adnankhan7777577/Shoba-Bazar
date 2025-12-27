import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../widgets/custom_dropdown.dart';
import '../../widgets/product_card.dart';
import '../../controller/add_product/cubit.dart';
import '../../controller/products/cubit.dart';
import '../../controller/products/state.dart';
import '../../utils/responsive_utils.dart';
import '../../utils/debouncer.dart';

class CategorySearchScreen extends StatefulWidget {
  final String? categoryId;
  final String categoryName;
  final String categoryType; // 'tire_rim', 'battery', 'engine', etc.
  
  const CategorySearchScreen({
    super.key,
    this.categoryId,
    required this.categoryName,
    required this.categoryType,
  });

  @override
  State<CategorySearchScreen> createState() => _CategorySearchScreenState();
}

class _CategorySearchScreenState extends State<CategorySearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final Debouncer _debouncer = Debouncer(delay: const Duration(milliseconds: 300));
  
  // Filter states
  String? _selectedCategory;
  String? _selectedType;
  String? _selectedModel;
  String? _selectedBrandId;
  String _selectedBrand = 'All';
  
  // Data from database
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _types = [];
  List<Map<String, dynamic>> _models = [];
  List<Map<String, dynamic>> _brands = [];
  
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Initialize selected category to current category
    // If categoryName is "All" or categoryId is null, set to "All"
    if (widget.categoryName == 'All' || widget.categoryId == null) {
      _selectedCategory = 'All';
    } else {
      _selectedCategory = widget.categoryName;
    }
    // Load data from database first, then load products
    _loadFilterData().then((_) {
      if (mounted) {
        _loadProducts();
      }
    });
    // Auto-focus the search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }
  
  void _loadProducts() {
    String? categoryIdToUse;
    String? typeId;
    String? brandId;
    String? modelId;
    
    // Determine category ID
    bool userChangedCategory = _selectedCategory != widget.categoryName;
    
    if (userChangedCategory) {
      if (_selectedCategory == 'All') {
        categoryIdToUse = null;
      } else if (_selectedCategory != null && _categories.isNotEmpty) {
        final selectedCat = _categories.firstWhere(
          (cat) => cat['name'] == _selectedCategory,
          orElse: () => {},
        );
        if (selectedCat.isNotEmpty && selectedCat['id'] != null) {
          categoryIdToUse = selectedCat['id'] as String;
        }
      }
    } else {
      if (widget.categoryName == 'All' || widget.categoryId == null) {
        categoryIdToUse = null;
      } else {
        categoryIdToUse = widget.categoryId;
      }
    }
    
    // Determine type ID
    if (_selectedType != null) {
      final type = _types.firstWhere(
        (t) => t['name'] == _selectedType,
        orElse: () => {},
      );
      if (type['id'] != null) {
        typeId = type['id'] as String;
      }
    }
    
    // Determine brand ID
    if (_selectedBrandId != null) {
      brandId = _selectedBrandId;
    }
    
    // Determine model ID
    if (_selectedModel != null) {
      final model = _models.firstWhere(
        (m) => m['name'] == _selectedModel,
        orElse: () => {},
      );
      if (model['id'] != null) {
        modelId = model['id'] as String;
      }
    }
    
    context.read<ProductsCubit>().fetchProductsByCategory(
      categoryId: categoryIdToUse,
      typeId: typeId,
      brandId: brandId,
      modelId: modelId,
    );
  }
  
  List<Map<String, dynamic>> _getFilteredProducts(List<Map<String, dynamic>> products) {
    if (_searchQuery.isEmpty) {
      return products;
    }
    final searchLower = _searchQuery.toLowerCase();
    final searchWords = searchLower.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    
    return products.where((product) {
      final name = (product['name'] as String? ?? '').toLowerCase();
      final nameWords = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      
      // Check if search query is a substring of product name (original behavior)
      if (name.contains(searchLower)) {
        return true;
      }
      
      // Check if any search word matches any product name word (flexible matching)
      for (final searchWord in searchWords) {
        for (final nameWord in nameWords) {
          // Check if search word is substring of name word or vice versa
          if (nameWord.contains(searchWord) || searchWord.contains(nameWord)) {
            return true;
          }
        }
      }
      
      return false;
    }).toList();
  }

  Future<void> _loadFilterData() async {
    try {
      final addProductCubit = context.read<AddProductCubit>();
      
      // Load categories
      final categories = await addProductCubit.fetchCategories();
      setState(() {
        _categories = categories;
      });
      
      // Load types based on selected category
      await _loadTypesForCategory();
      
      // Load models
      final models = await addProductCubit.fetchModels();
      setState(() {
        _models = models;
      });
      
      // Load brands
      final brands = await addProductCubit.fetchBrands();
      setState(() {
        _brands = brands;
      });
    } catch (e) {
      print('Error loading filter data: $e');
    }
  }

  Future<void> _loadTypesForCategory() async {
    try {
      final addProductCubit = context.read<AddProductCubit>();
      
      // If "All" is selected, load all types
      if (_selectedCategory == 'All' || _selectedCategory == null) {
        final types = await addProductCubit.fetchTypes();
        setState(() {
          _types = types;
        });
      } else {
        // Find the category ID
        final selectedCat = _categories.firstWhere(
          (cat) => cat['name'] == _selectedCategory,
          orElse: () => {},
        );
        
        if (selectedCat.isNotEmpty && selectedCat['id'] != null) {
          final categoryId = selectedCat['id'] as String;
          final types = await addProductCubit.fetchTypes(categoryId: categoryId);
          setState(() {
            _types = types;
            // Clear selected type if it's not in the new list
            if (_selectedType != null) {
              final typeNames = types.map((t) => t['name'] as String).toList();
              if (!typeNames.contains(_selectedType)) {
                _selectedType = null;
              }
            }
          });
        }
      }
    } catch (e) {
      print('Error loading types for category: $e');
    }
  }


  @override
  void dispose() {
    _debouncer.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // Get category options - remove duplicates
  List<String> _getCategoryOptions() {
    final options = <String>['All'];
    final categoryNames = _categories
        .map((cat) => cat['name'] as String)
        .where((name) => name.isNotEmpty)
        .toSet() // Remove duplicates using Set
        .toList();
    options.addAll(categoryNames);
    return options;
  }

  // Get type options from database - filtered by selected category
  List<String> _getTypeOptions() {
    // If "All" is selected, show all types
    if (_selectedCategory == 'All' || _selectedCategory == null) {
      return _types
          .map((type) => type['name'] as String)
          .where((name) => name.isNotEmpty)
          .toSet() // Remove duplicates
          .toList();
    }
    
    // Filter types by selected category
    final selectedCat = _categories.firstWhere(
      (cat) => cat['name'] == _selectedCategory,
      orElse: () => {},
    );
    
    if (selectedCat.isEmpty || selectedCat['id'] == null) {
      return [];
    }
    
    final categoryId = selectedCat['id'] as String;
    return _types
        .where((type) => type['category_id'] == categoryId)
        .map((type) => type['name'] as String)
        .where((name) => name.isNotEmpty)
        .toSet() // Remove duplicates
        .toList();
  }

  // Get model options from database - remove duplicates
  List<String> _getModelOptions() {
    return _models
        .map((model) => model['name'] as String)
        .where((name) => name.isNotEmpty)
        .toSet() // Remove duplicates
        .toList();
  }

  // Get brand options from database
  List<Map<String, dynamic>> _getBrandOptions() {
    return _brands;
  }

  String _getSearchPlaceholder() {
    switch (widget.categoryType) {
      case 'tire_rim':
        return 'Search tire rims';
      case 'battery':
        return 'Search car batteries';
      case 'engine':
        return 'Search engine parts';
      default:
        return 'Search products';
    }
  }

  // Auto parts make icon methods - same as dashboard
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
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ),
      errorWidget: (context, url, error) {
        // Enhanced fallback with brand-specific styling
        Color brandColor = _getBrandColor(makerName);
        return Container(
          width: size,
          height: size,
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
                fontSize: size * 0.4,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header Section
              _buildHeader(),
              
              // Search and Filters
              _buildSearchAndFilters(),
              
              // Product Results
              _buildProductGrid(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
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
                border: Border.all(color: Colors.grey),
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
          
          // Dynamic Title
          Expanded(
            child: Text(
              widget.categoryName,
              style: AppTextStyles.heading1.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 28
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          const SizedBox(width: 56), // Balance the back button
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Search Bar
          _buildSearchBar(),
          
          const SizedBox(height: 20),
          
          // Category Filter
          _buildFilterRow('Category', _buildCategoryFilter()),
          const SizedBox(height: 16),
          
          // Type Filter
          if (_getTypeOptions().isNotEmpty) ...[
            _buildFilterRow('Type', _buildTypeFilter()),
            const SizedBox(height: 16),
          ],
          
          // Brand Filter
          _buildBrandFilter(),
          
          const SizedBox(height: 16),
          
          // Model Filter
          if (_getModelOptions().isNotEmpty) ...[
            _buildFilterRow('Model', _buildModelFilter()),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
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
        focusNode: _searchFocusNode,
        style: AppTextStyles.bodyMedium,
        decoration: InputDecoration(
          hintText: _getSearchPlaceholder(),
          hintStyle: AppTextStyles.textFieldHint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: AppColors.textPrimary,
            size: 20,
          ),
        ),
        onChanged: (value) {
          _debouncer.call(() {
            _performSearch(value);
          });
        },
        onSubmitted: (value) {
          _debouncer.dispose();
          _performSearch(value);
        },
      ),
    );
  }

  Widget _buildFilterRow(String label, Widget filterWidget) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        filterWidget,
      ],
    );
  }

  Widget _buildCategoryFilter() {
    final categoryOptions = _getCategoryOptions();
    // Ensure the selected value exists in the options, otherwise use null
    final validValue = categoryOptions.contains(_selectedCategory) 
        ? _selectedCategory 
        : null;
    
    return CustomDropdown(
      value: validValue,
      hintText: 'Select category',
      items: categoryOptions,
      onChanged: (value) async {
        setState(() {
          _selectedCategory = value;
        });
        // Reload types for the selected category
        await _loadTypesForCategory();
        // Reload products with new category filter (or no filter if "All")
        _loadProducts();
      },
    );
  }

  Widget _buildTypeFilter() {
    final typeOptions = _getTypeOptions();
    final validValue = typeOptions.contains(_selectedType) 
        ? _selectedType 
        : null;
    
    return CustomDropdown(
      value: validValue,
      hintText: 'Select type',
      items: typeOptions,
      onChanged: (value) {
        setState(() {
          _selectedType = value;
          // If value is null, clear the filter
          if (value == null) {
            _selectedType = null;
          }
        });
        _applyFilters();
      },
    );
  }

  Widget _buildModelFilter() {
    final modelOptions = _getModelOptions();
    final validValue = modelOptions.contains(_selectedModel) 
        ? _selectedModel 
        : null;
    
    return CustomDropdown(
      value: validValue,
      hintText: 'Select model',
      items: modelOptions,
      onChanged: (value) {
        setState(() {
          _selectedModel = value;
          // If value is null, clear the filter
          if (value == null) {
            _selectedModel = null;
          }
        });
        _applyFilters();
      },
    );
  }

  Widget _buildBrandFilter() {
    final brands = _getBrandOptions();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Brand',
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: brands.length + 1, // +1 for "All" option
            itemBuilder: (context, index) {
              if (index == 0) {
                // "All" option
                final isSelected = _selectedBrand == 'All';
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedBrand = 'All';
                      _selectedBrandId = null;
                    });
                    _applyFilters();
                  },
                  child: Container(
                    width: 60,
                    height: 60,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withOpacity(0.8) : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.primary.withOpacity(0.6) : AppColors.lightGrey,
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
                      Icons.grid_view,
                      color: isSelected ? AppColors.white : AppColors.textSecondary,
                      size: 24,
                    ),
                  ),
                );
              }
              
              final brand = brands[index - 1];
              final brandName = brand['name'] as String;
              final brandId = brand['id'] as String;
              final brandImage = brand['image'] as String?;
              final isSelected = brandId == _selectedBrandId;
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedBrand = brandName;
                    _selectedBrandId = brandId;
                  });
                  _applyFilters();
                },
                child: Container(
                  width: 60,
                  height: 60,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withOpacity(0.8) : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.primary.withOpacity(0.6) : AppColors.lightGrey,
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
                  child: Center(
                    child: brandImage != null && brandImage.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: brandImage,
                            width: 32,
                            height: 32,
                            fit: BoxFit.contain,
                            placeholder: (context, url) => _buildMakerLogoWithFallback(brandName, 32),
                            errorWidget: (context, url, error) => _buildMakerLogoWithFallback(brandName, 32),
                          )
                        : _buildMakerLogoWithFallback(brandName, 32),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductGrid() {
    return Column(
      children: [
        // Filtered results title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Filtered results',
              style: AppTextStyles.heading3.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        
        // Product grid
        BlocBuilder<ProductsCubit, ProductsState>(
          builder: (context, state) {
            if (state is ProductsLoading) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            
            if (state is ProductsError) {
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
                        _loadProducts();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            
            if (state is ProductsLoaded) {
              final filteredProducts = _getFilteredProducts(state.products);
              
              if (filteredProducts.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: AppColors.textLight,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No products found'
                              : 'No products match your search',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textLight,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: ResponsiveUtils.getScreenPadding(context),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: ResponsiveUtils.getProductGridCrossAxisCount(context),
                  crossAxisSpacing: ResponsiveUtils.getGridSpacing(context),
                  mainAxisSpacing: ResponsiveUtils.getGridSpacing(context),
                  childAspectRatio: ResponsiveUtils.getProductCardAspectRatio(context),
                ),
                itemCount: filteredProducts.length,
                itemBuilder: (context, index) {
                  final product = filteredProducts[index];
                  return _buildProductCard(product);
                },
              );
            }
            
            return const SizedBox.shrink();
          },
        ),
        
        const SizedBox(height: 20), // Extra padding at bottom
      ],
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final productImage = product['image'] as String?;
    final productName = product['name'] as String;
    final productPrice = product['price'] as String;
    final productRating = product['rating'] as num? ?? 0.0;
    final productData = product['product'] as Map<String, dynamic>;

    return ProductCard(
      productImage: productImage,
      productName: productName,
      productPrice: productPrice,
      productRating: productRating.toDouble(),
      productData: productData,
      useGridViewLayout: true,
      cardColor: AppColors.surface,
      titleStyle: AppTextStyles.bodySmall.copyWith(
        fontWeight: FontWeight.w600,
      ),
      priceStyle: AppTextStyles.bodyMedium.copyWith(
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
      horizontalPadding: 12,
    );
  }


  void _performSearch(String query) {
    setState(() {
      _searchQuery = query.trim().toLowerCase();
    });
  }

  void _applyFilters() {
    // Reload products with new filters
    _loadProducts();
  }

}
